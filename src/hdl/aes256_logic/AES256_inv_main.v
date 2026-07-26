`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 08:42:06 AM
// Design Name: 
// Module Name: AES256_inv_main
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


module AES256_inv_main(
    input clk,
    input rst,
    input start,
    input key_ready,
    input  [127:0] data_in,      
    output reg [127:0] data_out, 
    output reg done,
    output [3:0] round_idx,
    input  [127:0] round_key
);
    reg [127:0] state;
    reg [3:0] round_count;
    reg busy;
    wire [127:0] round_res, last_round_res;
    
    assign round_idx = (start && key_ready && !busy) ? 4'd14 : round_count;
    
    inv_round      r_inst  (.data_in(state), .key_in(round_key), .data_out(round_res));
    inv_lastround  lr_inst (.data_in(state), .key_in(round_key), .data_out_last(last_round_res));
    
    always @(posedge clk) begin
        if (rst) begin
            round_count <= 0;
            done  <= 0;
            busy  <= 0;
            state <= 0;
            data_out <= 0;
        end else if (start && key_ready && !busy) begin
            state       <= data_in ^ round_key; 
            round_count <= 13;
            busy  <= 1;
            done  <= 0;
        end else if (busy) begin
            if (round_count >= 1) begin
                state       <= round_res;        
                round_count <= round_count - 1;
            end else begin 
                data_out <= last_round_res;      
                done <= 1;
                busy <= 0;
            end
        end
    end
endmodule
