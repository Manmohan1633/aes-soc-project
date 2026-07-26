`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:19:25 PM
// Design Name: 
// Module Name: Crypto_Engine_Top
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


module Crypto_Engine_Top(
    input clk,
    input rst,
    input start,
    input mode,                 // 0: Encrypt, 1: Decrypt
    input [127:0] data_in,      // Input data
    input [127:0] master_key,   // Used for Encryption
    output [127:0] data_out,    // Combined output
    output done                 // Combined done signal
);

    // --- Internal Wires ---
    wire [127:0] enc_data_out;
    wire enc_done;
    wire [127:0] dec_data_out;
    wire dec_done;
    
    // Bridge wire to carry the key from Encryption to Decryption
    wire [127:0] captured_r10_key; 

    // --- Signal Routing ---
    wire start_enc = start & ~mode; 
    wire start_dec = start & mode;  

    // --- Instantiate Encryption Core ---
    AES_main enc_core (
        .clk(clk),
        .rst(rst),
        .start(start_enc),
        .data_in(data_in),
        .key(master_key),
        .data_out(enc_data_out),
        .done(enc_done),
        .final_round_key(captured_r10_key) // Correctly mapped
    );

    // --- Instantiate Decryption Core ---
    AES_inv_main dec_core (
        .clk(clk),
        .rst(rst),
        .start(start_dec),
        .data_in(data_in),
        .round10_key(captured_r10_key),    // Bridged here
        .data_out(dec_data_out),
        .done(dec_done)
    );

    // --- Output Multiplexer ---
    assign data_out = (mode == 1'b0) ? enc_data_out : dec_data_out;
    assign done     = (mode == 1'b0) ? enc_done     : dec_done;

endmodule
