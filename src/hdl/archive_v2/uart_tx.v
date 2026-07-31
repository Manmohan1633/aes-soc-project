`timescale 1ns / 1ps
module uart_tx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115200
)(
    input        clk,
    input        rst,
    input  [7:0] data,
    input        start,   // pulse to begin sending 'data'
    output reg   tx,
    output reg   busy
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam CNT_W = $clog2(CLKS_PER_BIT + 1);

    localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg [1:0] state;
    reg [CNT_W-1:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] tx_shift;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; tx <= 1'b1; busy <= 1'b0; clk_cnt <= 0; bit_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    if (start) begin
                        tx_shift <= data;
                        busy     <= 1'b1;
                        clk_cnt  <= 0;
                        state    <= S_START;
                    end else begin
                        busy <= 1'b0;
                    end
                end
                S_START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0; bit_idx <= 0; state <= S_DATA;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                S_DATA: begin
                    tx <= tx_shift[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                S_STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0; busy <= 1'b0; state <= S_IDLE;
                    end else clk_cnt <= clk_cnt + 1'b1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule