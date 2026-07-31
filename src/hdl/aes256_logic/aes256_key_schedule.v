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


module aes256_key_schedule (
    input  wire clk,
    input  wire rst,
    input  wire load,
    input  wire [255:0] master_key,
    output reg  busy,
    output reg  ready,
    input  wire [3:0] round_idx,
    input  wire mode,
    output reg  [127:0] round_key
);

    // ------------------------------------------------------------------
    // Memory Array (unified: forward keys at 0-14, decrypt-side keys at 16-30)
    // ------------------------------------------------------------------
   
   // The pragma forces Gowin to map this to physical BSRAM blocks
    reg [127:0] unified_key_ram [0:31] /* synthesis syn_ramstyle = "block_ram" */;

    reg [4:0]   kram_waddr;
    reg [127:0] kram_wdata;
    reg         kram_we;

    wire [4:0] read_addr = mode ? (5'd16 + {1'b0, round_idx}) : {1'b0, round_idx};

    // Port A: Dedicated Synchronous Write
    always @(posedge clk) begin
        if (kram_we) begin
            unified_key_ram[kram_waddr] <= kram_wdata;
        end
    end

    // Port B: Dedicated Synchronous Read
    always @(posedge clk) begin
        round_key <= unified_key_ram[read_addr];
    end

    // Synchronous Read Port for the Serial Core (1-cycle latency).
    // mode=0: read forward table directly at round_idx (0-14).
    // mode=1: read the decrypt-side region at 16+round_idx (16-30) -- this
    // already contains the right value whether round_idx is 0, 14, or 1-13,
    // no special-casing needed here anymore.
    wire [4:0] read_addr = mode ? (5'd16 + {1'b0, round_idx}) : {1'b0, round_idx};
    always @(posedge clk) begin
        round_key <= unified_key_ram[read_addr];
    end

    // ------------------------------------------------------------------
    // Hardware Instantiations 
    // ------------------------------------------------------------------
    reg [3:0] exp_round;
    reg [127:0] prev_k1, prev_k2;

    wire [7:0] sbox_in [0:3];
    assign sbox_in[0] = (exp_round[0] == 1'b0) ? prev_k1[23:16] : prev_k1[31:24];
    assign sbox_in[1] = (exp_round[0] == 1'b0) ? prev_k1[15:8]  : prev_k1[23:16];
    assign sbox_in[2] = (exp_round[0] == 1'b0) ? prev_k1[7:0]   : prev_k1[15:8];
    assign sbox_in[3] = (exp_round[0] == 1'b0) ? prev_k1[31:24] : prev_k1[7:0];

    wire [7:0] sbox_out [0:3];
    sbox sb0(.clk(clk), .data(sbox_in[0]), .dout(sbox_out[0]));
    sbox sb1(.clk(clk), .data(sbox_in[1]), .dout(sbox_out[1]));
    sbox sb2(.clk(clk), .data(sbox_in[2]), .dout(sbox_out[2]));
    sbox sb3(.clk(clk), .data(sbox_in[3]), .dout(sbox_out[3]));

    reg  [127:0] inv_mc_in;
    wire [127:0] inv_mc_out;
    InvMixColumns imc_inst(
        .data_in(inv_mc_in),
        .data_out(inv_mc_out)
    );

    // ------------------------------------------------------------------
    // FSM and Expansion Math
    // ------------------------------------------------------------------
    localparam ST_IDLE      = 3'd0,
               ST_LOAD_0    = 3'd1,
               ST_LOAD_1    = 3'd2,
               ST_EXP_ADDR  = 3'd3,
               ST_EXP_WRITE = 3'd4,
               ST_PRE_READ  = 3'd5,
               ST_PRE_WRITE = 3'd6,
               ST_READY     = 3'd7;

    reg [2:0] state;
    reg [3:0] pre_idx;

    wire [7:0] rcon_val = (exp_round == 4'd2) ? 8'h01 :
                          (exp_round == 4'd4) ? 8'h02 :
                          (exp_round == 4'd6) ? 8'h04 :
                          (exp_round == 4'd8) ? 8'h08 :
                          (exp_round == 4'd10)? 8'h10 :
                          (exp_round == 4'd12)? 8'h20 :
                          (exp_round == 4'd14)? 8'h40 : 8'h00;

    wire [31:0] sub_word_out = {sbox_out[0], sbox_out[1], sbox_out[2], sbox_out[3]};
    wire [31:0] temp_xor     = sub_word_out ^ {rcon_val, 24'h000000};
    wire [31:0] w0 = prev_k2[127:96] ^ ((exp_round[0] == 1'b0) ? temp_xor : sub_word_out);
    wire [31:0] w1 = prev_k2[95:64]  ^ w0;
    wire [31:0] w2 = prev_k2[63:32]  ^ w1;
    wire [31:0] w3 = prev_k2[31:0]   ^ w2;
    wire [127:0] next_key = {w0, w1, w2, w3};

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            busy  <= 1'b0;
            ready <= 1'b0;
            kram_we <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    kram_we <= 1'b0;
                    if (load) begin
                        busy  <= 1'b1;
                        ready <= 1'b0;
                        prev_k2    <= master_key[255:128];
                        prev_k1    <= master_key[127:0];
                        exp_round  <= 4'd2;
                        
                        kram_waddr <= 5'd0;
                        kram_wdata <= master_key[255:128];
                        kram_we    <= 1'b1;
                        state      <= ST_LOAD_0;
                    end
                end

                ST_LOAD_0: begin
                    kram_waddr <= 5'd1;
                    kram_wdata <= master_key[127:0];
                    kram_we    <= 1'b1;
                    state      <= ST_LOAD_1;
                end

                ST_LOAD_1: begin
                    kram_we <= 1'b0;
                    state   <= ST_EXP_ADDR;
                end

                ST_EXP_ADDR: begin
                    kram_we <= 1'b0;
                    state   <= ST_EXP_WRITE;
                end

                ST_EXP_WRITE: begin
                    kram_waddr <= {1'b0, exp_round};
                    kram_wdata <= next_key;
                    kram_we    <= 1'b1;
                    
                    prev_k2 <= prev_k1;
                    prev_k1 <= next_key;

                    if (exp_round == 4'd14) begin
                        pre_idx <= 4'd0; // now starts at 0, not 1 -- covers K0 and K14 too
                        state   <= ST_PRE_READ;
                    end else begin
                        exp_round <= exp_round + 4'd1;
                        state     <= ST_EXP_ADDR;
                    end
                end

                // pre_idx sweeps 0..14 over the just-completed forward table
                // (addresses 0-14) and stages each one for ST_PRE_WRITE.
                ST_PRE_READ: begin
                    kram_we   <= 1'b0;
                    inv_mc_in <= unified_key_ram[pre_idx];
                    state     <= ST_PRE_WRITE;
                end

                // K0 and K14 (pre_idx 0 and 14) are copied through unchanged
                // -- AES never applies InvMixColumns to those two. Everything
                // else (pre_idx 1-13) gets the transform. Destination is
                // always 16+pre_idx, landing in the 16-30 region.
                ST_PRE_WRITE: begin
                    kram_waddr <= 5'd16 + {1'b0, pre_idx};
                    kram_wdata <= (pre_idx == 4'd0 || pre_idx == 4'd14) ? inv_mc_in : inv_mc_out;
                    kram_we    <= 1'b1;
                    if (pre_idx == 4'd14) begin
                        state <= ST_READY;
                    end else begin
                        pre_idx <= pre_idx + 4'd1;
                        state   <= ST_PRE_READ;
                    end
                end

                ST_READY: begin
                    busy  <= 1'b0;
                    ready <= 1'b1;
                    kram_we <= 1'b0;
                    if (load) begin
                        ready <= 1'b0;
                        busy  <= 1'b1;
                        prev_k2    <= master_key[255:128];
                        prev_k1    <= master_key[127:0];
                        exp_round  <= 4'd2;
                        
                        kram_waddr <= 5'd0;
                        kram_wdata <= master_key[255:128];
                        kram_we    <= 1'b1;
                        state      <= ST_LOAD_0;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule