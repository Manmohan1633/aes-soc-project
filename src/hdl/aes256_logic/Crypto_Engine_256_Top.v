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


module Crypto_Engine_256_Top(
    input clk,
    input rst,
    input  key_load,
    input  [255:0] master_key,
    output key_busy,
    output key_ready,
    input  start,
    input  mode,                
    input  [127:0] data_in,
    output [127:0] data_out,
    output done
);
    wire [3:0] round_idx_enc, round_idx_dec;
    wire [127:0] round_key_enc, round_key_dec;
    wire [3:0] round_idx_sel = mode ? round_idx_dec : round_idx_enc;
    wire [127:0] round_key_shared;
    
    aes256_key_schedule ks (
        .clk(clk), .rst(rst),
        .load(key_load), .master_key(master_key),
        .busy(key_busy), .ready(key_ready),
        .round_idx(round_idx_sel), .round_key(round_key_shared)
    );
    
    assign round_key_enc = round_key_shared;
    assign round_key_dec = round_key_shared;
    
    wire start_enc = start & ~mode;
    wire start_dec = start &  mode;
    
    wire [127:0] enc_data_out; wire enc_done;
    wire [127:0] dec_data_out; wire dec_done;
    
    AES256_main enc_core (
        .clk(clk), .rst(rst),
        .start(start_enc), .key_ready(key_ready),
        .data_in(data_in),
        .data_out(enc_data_out), .done(enc_done),
        .round_idx(round_idx_enc), .round_key(round_key_enc)
    );
    
    AES256_inv_main dec_core (
        .clk(clk), .rst(rst),
        .start(start_dec), .key_ready(key_ready),
        .data_in(data_in),
        .data_out(dec_data_out), .done(dec_done),
        .round_idx(round_idx_dec), .round_key(round_key_dec)
    );
    
    assign data_out = mode ? dec_data_out : enc_data_out;
    assign done     = mode ? dec_done     : enc_done;
endmodule
