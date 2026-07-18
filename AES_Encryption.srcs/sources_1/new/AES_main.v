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

    // --- CORRECTION BEGINS HERE ---
    // Create look-ahead signals to synchronize key expansion with the data path
    
    // Trigger key generation on 'start' (to prepare Round 1 key) 
    // and while 'busy' (to prepare keys for rounds 2 through 10)
    wire compute_next_key = start | (busy && (round_count < 10));
    
    // Tell the key expander exactly which key index it needs to generate next
    wire [3:0] next_key_idx = start ? 4'd1 : (round_count + 1);

    aes_key_expand key_gen(
        .clk(clk),
        .rst(rst),
        .next_round(compute_next_key), 
        .master_key(key),
        .round_idx(next_key_idx),
        .round_key(round_key)
    );
    // --- CORRECTION ENDS HERE ---

    round r_inst      (.data_in(state), .key_in(round_key), .data_out(round_res));
    last_round lr_inst(.data_in(state), .key_in(round_key), .data_out_last(last_round_res));

    always @(posedge clk) begin
        if (rst) begin
            round_count <= 0;
            done <= 0;
            busy <= 0;
            state <= 0;
            data_out <= 0;
        end else if (start && !busy) begin
            // Apply initial key before round 1 (AddRoundKey)
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