`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 05:07:16 AM
// Design Name: 
// Module Name: AES_main
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


module AES_main(
    input clk,
    input rst,
    input start,
    input [127:0] data_in,
    input [127:0] key,
    output reg [127:0] data_out,
    output reg done
);

    reg [127:0] state;
    reg [3:0] round_count;
    reg busy;
    
    wire [127:0] round_key;
    wire [127:0] round_res, last_round_res;

    aes_key_expand key_gen(
        .clk(clk),
        .rst(rst),
        .next_round(busy), 
        .master_key(key),
        .round_idx(round_count),
        .round_key(round_key)
    );

    round r_inst      (.data_in(state), .key_in(round_key), .data_out(round_res));
    last_round lr_inst(.data_in(state), .key_in(round_key), .data_out_last(last_round_res));

    always @(posedge clk) begin
        if (rst) begin
            round_count <= 0;
            done <= 0;
            busy <= 0;
            state <= 0;
            data_out <= 0; // FIX: Initialize data_out to 0 to prevent X at start
        end else if (start && !busy) begin
            state <= data_in ^ key;
            round_count <= 1;
            busy <= 1;
            done <= 0;
        end else if (busy) begin
            if (round_count < 10) begin
                state <= round_res;
                round_count <= round_count + 1;
            end else if (round_count == 10) begin
                data_out <= last_round_res;
                done <= 1;
                busy <= 0;
            end
        end
    end
endmodule