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
    input mode,                 // Selects operation: 0 for Encrypt, 1 for Decrypt
    input [127:0] data_in,      // Input data (Plaintext or Ciphertext)
    input [127:0] master_key,   // Used for Encryption
    input [127:0] round10_key,  // Used for Decryption (Provided by host processor)
    output reg [127:0] data_out,
    output reg done
);

    // --- Internal Wires ---
    wire [127:0] enc_data_out;
    wire enc_done;
    
    wire [127:0] dec_data_out;
    wire dec_done;

    // --- Signal Routing ---
    // Only trigger the requested core to save power and prevent collision
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
        .done(enc_done)
    );

    // --- Instantiate Decryption Core ---
    AES_inv_main dec_core (
        .clk(clk),
        .rst(rst),
        .start(start_dec),
        .data_in(data_in),
        .round10_key(round10_key),
        .data_out(dec_data_out),
        .done(dec_done)
    );

    // --- Output Multiplexer ---
    // Combinationally select the correct outputs based on the active mode
    always @(*) begin
        if (mode == 1'b0) begin
            data_out = enc_data_out;
            done = enc_done;
        end else begin
            data_out = dec_data_out;
            done = dec_done;
        end
    end

endmodule
