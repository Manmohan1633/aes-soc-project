`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2026 04:24:01 PM
// Design Name: 
// Module Name: uart_rx
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


module uart_rx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115200
)(
    input        clk,
    input        rst,
    input        rx,
    output reg [7:0] data,
    output reg   valid   // 1-cycle pulse when a byte has been received
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam CNT_W = $clog2(CLKS_PER_BIT + 1);

    localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg [1:0] state;
    reg [CNT_W-1:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] rx_shift;
    reg rx_d1, rx_d2; // 2-FF synchronizer for the async rx pin

    always @(posedge clk) begin
        rx_d1 <= rx;
        rx_d2 <= rx_d1;
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; valid <= 1'b0; clk_cnt <= 0; bit_idx <= 0; data <= 8'd0;
        end else begin
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (rx_d2 == 1'b0) begin // possible start bit
                        state   <= S_START;
                        clk_cnt <= 0;
                    end
                end
                S_START: begin
                    // sample at mid-bit to confirm it's a real start bit, not noise
                    if (clk_cnt == (CLKS_PER_BIT/2)) begin
                        if (rx_d2 == 1'b0) begin
                            clk_cnt <= 0;
                            bit_idx <= 0;
                            state   <= S_DATA;
                        end else begin
                            state <= S_IDLE; // glitch, not a real start bit
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        rx_shift[bit_idx] <= rx_d2;
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        data    <= rx_shift;
                        valid   <= 1'b1;
                        clk_cnt <= 0;
                        state   <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
