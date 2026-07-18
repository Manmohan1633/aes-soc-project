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
    output reg [127:0] round_key
);

    // Use internal registers to hold the current words
    reg [31:0] k0, k1, k2, k3;
    wire [31:0] sub_word, rcon_word;
    wire [7:0]  rcon_val;
    wire [31:0] rot_word;
    wire [31:0] next_w0, next_w1, next_w2, next_w3;

    // RotWord and SubWord logic
    assign rot_word = {k3[23:0], k3[31:24]};
    sbox s1(rot_word[31:24], sub_word[31:24]);
    sbox s2(rot_word[23:16], sub_word[23:16]);
    sbox s3(rot_word[15:8],  sub_word[15:8]);
    sbox s4(rot_word[7:0],   sub_word[7:0]);

    aes_rcon_iter rcon_inst(round_idx, rcon_val);
    assign rcon_word = {rcon_val, 24'b0};

    // Calculate next words
    assign next_w0 = k0 ^ sub_word ^ rcon_word;
    assign next_w1 = k1 ^ next_w0;
    assign next_w2 = k2 ^ next_w1;
    assign next_w3 = k3 ^ next_w2;

    always @(posedge clk) begin
        if (rst) begin
            k0 <= master_key[127:96];
            k1 <= master_key[95:64];
            k2 <= master_key[63:32];
            k3 <= master_key[31:0];
            round_key <= master_key;
        end else if (next_round) begin
            k0 <= next_w0;
            k1 <= next_w1;
            k2 <= next_w2;
            k3 <= next_w3;
            round_key <= {next_w0, next_w1, next_w2, next_w3};
        end
    end
endmodule