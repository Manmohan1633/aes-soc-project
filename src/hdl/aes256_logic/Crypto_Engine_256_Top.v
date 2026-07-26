`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 10:29:28 AM
// Design Name: 
// Module Name: Crypto_Engine_256_Top
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


odule Crypto_Engine_256_Top(
    input  clk,
    input  rst,
    input  load,            // Triggers key expansion
    input  [255:0] key,     // Master key
    input  start,           // Triggers encryption/decryption
    input  mode,            // 0 = Encrypt, 1 = Decrypt
    input  [127:0] data_in,
    output [127:0] data_out,
    output done,
    output key_ready
);
    
    wire [3:0] round_idx;
    wire [127:0] round_key;
    wire key_busy;

    // The Shared Key Schedule (Rev 2)
    aes256_key_schedule ks_inst (
        .clk(clk),
        .rst(rst),
        .load(load),
        .master_key(key),
        .busy(key_busy),
        .ready(key_ready),
        .round_idx(round_idx),
        .mode(mode),
        .round_key(round_key)
    );

    // The New Byte-Serial Shared Core
    AES256_serial_core core_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .key_ready(key_ready),
        .mode(mode),
        .data_in(data_in),
        .data_out(data_out),
        .done(done),
        .round_idx(round_idx),
        .round_key(round_key)
    );

endmodule
