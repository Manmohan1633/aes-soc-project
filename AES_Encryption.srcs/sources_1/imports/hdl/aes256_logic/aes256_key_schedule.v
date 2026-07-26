`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 08:40:18 AM
// Design Name: 
// Module Name: aes256_key_schedule
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module aes256_key_schedule(
    input  clk,
    input  rst,
    input  load,                 // pulse: latch master_key and begin expansion
    input  [255:0] master_key,
    output reg busy,             // expansion or dk-transform in progress
    output reg ready,            // key_ram AND dk_ram both valid
    input  [3:0] round_idx,      // 0..14
    input  mode,                 // 0 = Encrypt (read key_ram), 1 = Decrypt (read dk_ram for 1..13)
    output reg [127:0] round_key
);
    reg [127:0] key_ram [0:14];
    reg [127:0] dk_ram  [1:13];

    reg        phase;   // 0 = expanding key_ram, 1 = building dk_ram
    reg [3:0]  r;        // round currently being computed (2..14) during phase 0
    reg [3:0]  dkr;       // key index (1..13) currently being transformed, phase 1
    reg [1:0]  sc;         // column (0..3) within dkr, phase 1

    //------------------------------------------------------------------
    // Phase 0 math: forward key expansion (identical to rev 1)
    //------------------------------------------------------------------
    wire [31:0] a2 = key_ram[r-2][127:96];
    wire [31:0] b2 = key_ram[r-2][95:64];
    wire [31:0] c2 = key_ram[r-2][63:32];
    wire [31:0] d2 = key_ram[r-2][31:0];
    wire [31:0] d1 = key_ram[r-1][31:0];

    wire [31:0] rot_d1 = {d1[23:0], d1[31:24]};
    wire [31:0] sub_rot_d1;
    sbox rs0(rot_d1[31:24], sub_rot_d1[31:24]);
    sbox rs1(rot_d1[23:16], sub_rot_d1[23:16]);
    sbox rs2(rot_d1[15:8],  sub_rot_d1[15:8]);
    sbox rs3(rot_d1[7:0],   sub_rot_d1[7:0]);

    wire [31:0] sub_d1;
    sbox ss0(d1[31:24], sub_d1[31:24]);
    sbox ss1(d1[23:16], sub_d1[23:16]);
    sbox ss2(d1[15:8],  sub_d1[15:8]);
    sbox ss3(d1[7:0],   sub_d1[7:0]);

    wire [7:0] rcon_val;
    aes_rcon_iter rcon_inst({1'b0, r[3:1]}, rcon_val); // r>>1 == r/2

    wire [31:0] temp0 = r[0] ? sub_d1 : (sub_rot_d1 ^ {rcon_val, 24'b0});
    wire [31:0] w0 = a2 ^ temp0;
    wire [31:0] w1 = b2 ^ w0;
    wire [31:0] w2 = c2 ^ w1;
    wire [31:0] w3 = d2 ^ w2;

    //------------------------------------------------------------------
    // Phase 1 math: dk_i = InvMixColumns(K_i), one column at a time,
    // via the shared multiplier verified in gf_mixcol_shared.
    //------------------------------------------------------------------
    wire [127:0] cur_key = key_ram[dkr];
    wire [31:0]  cur_col = (sc == 2'd0) ? cur_key[127:96] :
                            (sc == 2'd1) ? cur_key[95:64]  :
                            (sc == 2'd2) ? cur_key[63:32]  :
                                           cur_key[31:0];

    wire [7:0] dk_b0, dk_b1, dk_b2, dk_b3;
    gf_mixcol_shared dk_mix (
        .mode(1'b1), // always inverse -- this instance only ever builds dk_ram
        .a0(cur_col[31:24]), .a1(cur_col[23:16]), .a2(cur_col[15:8]), .a3(cur_col[7:0]),
        .b0(dk_b0), .b1(dk_b1), .b2(dk_b2), .b3(dk_b3)
    );
    wire [31:0] dk_col = {dk_b0, dk_b1, dk_b2, dk_b3};

    //------------------------------------------------------------------
    // round_key read mux
    //------------------------------------------------------------------
    always @(*) begin
        if (mode == 1'b0) begin
            round_key = key_ram[round_idx];
        end else begin
            if (round_idx == 4'd0 || round_idx == 4'd14)
                round_key = key_ram[round_idx];   // K0 / K14: no InvMixColumns applied, ever
            else
                round_key = dk_ram[round_idx];    // K1..K13: transformed
        end
    end

    //------------------------------------------------------------------
    // FSM
    //------------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            busy  <= 1'b0;
            ready <= 1'b0;
            phase <= 1'b0;
            r     <= 4'd0;
            dkr   <= 4'd1;
            sc    <= 2'd0;
            for (i = 0; i < 15; i = i + 1) key_ram[i] <= 128'd0;
            for (i = 1; i < 14; i = i + 1) dk_ram[i]  <= 128'd0;
        end else if (load) begin
            key_ram[0] <= master_key[255:128];
            key_ram[1] <= master_key[127:0];
            r     <= 4'd2;
            phase <= 1'b0;
            dkr   <= 4'd1;
            sc    <= 2'd0;
            busy  <= 1'b1;
            ready <= 1'b0;
        end else if (busy && !phase) begin
            // Phase 0: forward expansion, same as rev 1
            key_ram[r] <= {w0, w1, w2, w3};
            if (r == 4'd14) begin
                phase <= 1'b1;   // move on to the dk-transform phase
            end else begin
                r <= r + 4'd1;
            end
        end else if (busy && phase) begin
            // Phase 1: build dk_ram, one column per cycle
            case (sc)
                2'd0: dk_ram[dkr][127:96] <= dk_col;
                2'd1: dk_ram[dkr][95:64]  <= dk_col;
                2'd2: dk_ram[dkr][63:32]  <= dk_col;
                2'd3: dk_ram[dkr][31:0]   <= dk_col;
            endcase
            if (sc == 2'd3) begin
                sc <= 2'd0;
                if (dkr == 4'd13) begin
                    busy  <= 1'b0;
                    ready <= 1'b1;
                end else begin
                    dkr <= dkr + 4'd1;
                end
            end else begin
                sc <= sc + 2'd1;
            end
        end
    end
endmodule
