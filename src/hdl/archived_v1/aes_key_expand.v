`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 05:07:46 AM
// Design Name: 
// Module Name: aes_key_expand
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


module aes_key_expand(
    input clk,
    input rst,
    input next_round,
    input [127:0] master_key,
    input [3:0] round_idx,
    output [127:0] round_key
);

    reg [31:0] w[3:0];
    wire [31:0] sub_word, rcon_word;
    wire [7:0]  rcon_val;
    wire [31:0] rot_word;
    wire [31:0] next_w0, next_w1, next_w2, next_w3;
    
    // NEW: Bypass wires to dynamically inject the master_key during Round 1 calculation
    wire [31:0] curr_w0, curr_w1, curr_w2, curr_w3;

    // FIPS-197 RCON mapping
    aes_rcon_iter rcon_inst(round_idx, rcon_val);
    assign rcon_word = {rcon_val, 24'b0};

    // When calculating Round 1, use the live master_key input instead of the internal registers
    assign curr_w0 = (round_idx == 4'd1) ? master_key[127:96] : w[0];
    assign curr_w1 = (round_idx == 4'd1) ? master_key[95:64]  : w[1];
    assign curr_w2 = (round_idx == 4'd1) ? master_key[63:32]  : w[2];
    assign curr_w3 = (round_idx == 4'd1) ? master_key[31:0]   : w[3];

    // Continuous assignment for combinatorial output
    assign round_key = {w[0], w[1], w[2], w[3]};

    // Key Expansion Core (now operates on the bypassed curr_w signals)
    assign rot_word = {curr_w3[23:0], curr_w3[31:24]};
    sbox s1(rot_word[31:24], sub_word[31:24]);
    sbox s2(rot_word[23:16], sub_word[23:16]);
    sbox s3(rot_word[15:8],  sub_word[15:8]);
    sbox s4(rot_word[7:0],   sub_word[7:0]);

    assign next_w0 = curr_w0 ^ sub_word ^ rcon_word;
    assign next_w1 = curr_w1 ^ next_w0;
    assign next_w2 = curr_w2 ^ next_w1;
    assign next_w3 = curr_w3 ^ next_w2;

    always @(posedge clk) begin
        if (rst) begin
            // Simply zero out registers on reset
            w[0] <= 32'd0; w[1] <= 32'd0; w[2] <= 32'd0; w[3] <= 32'd0;
        end else if (next_round) begin
            w[0] <= next_w0;
            w[1] <= next_w1;
            w[2] <= next_w2;
            w[3] <= next_w3;
        end
    end
endmodule