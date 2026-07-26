`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:11:15 PM
// Design Name: 
// Module Name: aes_inv_key_expand
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


module aes_inv_key_expand(
    input clk,
    input rst,
    input next_round,
    input [127:0] round10_key, // The pre-computed Round 10 Key
    input [3:0] round_idx,     // Counts DOWN from 10 to 1
    output [127:0] round_key
);

    reg [31:0] w[3:0];
    wire [31:0] sub_word, rcon_word;
    wire [7:0]  rcon_val;
    wire [31:0] rot_word;
    wire [31:0] prev_w0, prev_w1, prev_w2, prev_w3;
    
    // Bypass wires for dynamic injection of the Round 10 key on start
    wire [31:0] curr_w0, curr_w1, curr_w2, curr_w3;

    // RCON mapping (Uses your existing aes_rcon_iter module)
    aes_rcon_iter rcon_inst(round_idx, rcon_val);
    assign rcon_word = {rcon_val, 24'b0};

    // Initialize with Round 10 key at the start of decryption
    assign curr_w0 = (round_idx == 4'd10) ? round10_key[127:96] : w[0];
    assign curr_w1 = (round_idx == 4'd10) ? round10_key[95:64]  : w[1];
    assign curr_w2 = (round_idx == 4'd10) ? round10_key[63:32]  : w[2];
    assign curr_w3 = (round_idx == 4'd10) ? round10_key[31:0]   : w[3];

    // Output the current round key
    assign round_key = {curr_w0, curr_w1, curr_w2, curr_w3};

    // --- REVERSE KEY MATH ---
    // 1. Calculate the upper words first
    assign prev_w3 = curr_w3 ^ curr_w2;
    assign prev_w2 = curr_w2 ^ curr_w1;
    assign prev_w1 = curr_w1 ^ curr_w0;

    // 2. Pass prev_w3 through RotWord and SubWord (Uses FORWARD sbox)
    assign rot_word = {prev_w3[23:0], prev_w3[31:24]};
    
    sbox s1(rot_word[31:24], sub_word[31:24]);
    sbox s2(rot_word[23:16], sub_word[23:16]);
    sbox s3(rot_word[15:8],  sub_word[15:8]);
    sbox s4(rot_word[7:0],   sub_word[7:0]);

    // 3. Calculate the lowest word using the RCON
    assign prev_w0 = curr_w0 ^ sub_word ^ rcon_word;

    always @(posedge clk) begin
        if (rst) begin
            w[0] <= 32'd0; w[1] <= 32'd0; w[2] <= 32'd0; w[3] <= 32'd0;
        end else if (next_round) begin
            w[0] <= prev_w0;
            w[1] <= prev_w1;
            w[2] <= prev_w2;
            w[3] <= prev_w3;
        end
    end
endmodule
