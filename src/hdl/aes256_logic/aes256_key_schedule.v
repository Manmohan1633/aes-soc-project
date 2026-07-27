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
    // Memory Arrays (Gowin will map these to SSRAM due to registered reads)
    // ------------------------------------------------------------------
    reg [127:0] key_ram [0:14];
    reg [127:0] dk_ram [1:13];

    // Synchronous Read Port for the Serial Core (1-cycle latency)
    always @(posedge clk) begin
        if (mode == 1'b0) begin
            round_key <= key_ram[round_idx];
        end else begin
            if (round_idx == 4'd0 || round_idx == 4'd14)
                round_key <= key_ram[round_idx];
            else
                round_key <= dk_ram[round_idx];
        end
    end

    // ------------------------------------------------------------------
    // Hardware Instantiations 
    // ------------------------------------------------------------------
    
    reg [3:0] exp_round;
    reg [127:0] prev_k1, prev_k2;

    // 4x Synchronous S-Boxes for Key Expansion
    // FIX: Driven combinationally so they are immediately available to the S-box
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

    // Combinational InvMixColumns for Phase 1 Precomputation
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
               ST_EXP_ADDR  = 3'd1,
               ST_EXP_WRITE = 3'd2,
               ST_PRE_READ  = 3'd3,
               ST_PRE_WRITE = 3'd4,
               ST_READY     = 3'd5;

    reg [2:0] state;
    reg [3:0] pre_idx;

    // Hardcoded RCON table to save LUTs and avoid external dependencies
    wire [7:0] rcon_val = (exp_round == 4'd2) ? 8'h01 :
                          (exp_round == 4'd4) ? 8'h02 :
                          (exp_round == 4'd6) ? 8'h04 :
                          (exp_round == 4'd8) ? 8'h08 :
                          (exp_round == 4'd10)? 8'h10 :
                          (exp_round == 4'd12)? 8'h20 :
                          (exp_round == 4'd14)? 8'h40 : 8'h00;

    // AES-256 Word XOR Logic
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
        end else begin
            case (state)
                ST_IDLE: begin
                    if (load) begin
                        busy  <= 1'b1;
                        ready <= 1'b0;
                        key_ram[0] <= master_key[255:128];
                        key_ram[1] <= master_key[127:0];
                        prev_k2    <= master_key[255:128];
                        prev_k1    <= master_key[127:0];
                        exp_round  <= 4'd2;
                        state      <= ST_EXP_ADDR;
                    end
                end

                ST_EXP_ADDR: begin
                    // Address is now driven combinationally by wires.
                    // Just wait 1 clock edge for S-boxes to register the output.
                    state <= ST_EXP_WRITE;
                end

                ST_EXP_WRITE: begin
                    // Capture S-Box output and store new Key
                    key_ram[exp_round] <= next_key;
                    prev_k2 <= prev_k1;
                    prev_k1 <= next_key;

                    if (exp_round == 4'd14) begin
                        pre_idx <= 4'd1;
                        state   <= ST_PRE_READ;
                    end else begin
                        exp_round <= exp_round + 4'd1;
                        state     <= ST_EXP_ADDR;
                    end
                end

                ST_PRE_READ: begin
                    // Read current key from RAM (1-cycle delay)
                    inv_mc_in <= key_ram[pre_idx];
                    state     <= ST_PRE_WRITE;
                end

                ST_PRE_WRITE: begin
                    // Capture InvMixCol output and store in DK RAM
                    dk_ram[pre_idx] <= inv_mc_out;
                    if (pre_idx == 4'd13) begin
                        state <= ST_READY;
                    end else begin
                        pre_idx <= pre_idx + 4'd1;
                        state   <= ST_PRE_READ;
                    end
                end

                ST_READY: begin
                    busy  <= 1'b0;
                    ready <= 1'b1;
                    if (load) begin
                        ready <= 1'b0;
                        busy  <= 1'b1;
                        key_ram[0] <= master_key[255:128];
                        key_ram[1] <= master_key[127:0];
                        prev_k2    <= master_key[255:128];
                        prev_k1    <= master_key[127:0];
                        exp_round  <= 4'd2;
                        state      <= ST_EXP_ADDR;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule