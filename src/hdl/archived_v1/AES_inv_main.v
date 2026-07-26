`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:13:26 PM
// Design Name: 
// Module Name: AES_inv_main
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


module AES_inv_main(
    input clk,
    input rst,
    input start,
    input [127:0] data_in,      // Ciphertext
    input [127:0] round10_key,  // The 128-bit key for Round 10
    output reg [127:0] data_out,// Plaintext
    output reg done
);

    reg [127:0] state;
    reg [3:0] round_count;
    reg busy;
    
    wire [127:0] round_key;
    wire [127:0] round_res, last_round_res;

    // Trigger key generation on 'start' and while 'busy'
    wire compute_next_key = start | (busy && (round_count > 1));
    
    // Look-ahead for the reverse key expansion (counting DOWN)
    wire [3:0] next_key_idx = start ? 4'd10 : (round_count - 1);

    aes_inv_key_expand inv_key_gen(
        .clk(clk),
        .rst(rst),
        .next_round(compute_next_key), 
        .round10_key(round10_key),
        .round_idx(next_key_idx),
        .round_key(round_key)
    );

    // Standard Inverse Round (InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns)
    inv_round r_inst (
        .data_in(state), 
        .key_in(round_key), 
        .data_out(round_res)
    );
    
    // Last Inverse Round (Skips InvMixColumns)
    inv_lastround lr_inst (
        .data_in(state), 
        .key_in(round_key), 
        .data_out_last(last_round_res)
    );

    always @(posedge clk) begin
        if (rst) begin
            round_count <= 0;
            done <= 0;
            busy <= 0;
            state <= 0;
            data_out <= 0;
        end else if (start && !busy) begin
            // Decryption begins with AddRoundKey using the Round 10 key
            state <= data_in ^ round10_key;
            round_count <= 10;
            busy <= 1;
            done <= 0;
        end else if (busy) begin
            if (round_count > 1) begin
                state <= round_res;
                round_count <= round_count - 1;
            end else if (round_count == 1) begin
                // At round 1, we use the inv_lastround module
                data_out <= last_round_res;
                done <= 1;
                busy <= 0;
            end
        end
    end
endmodule
