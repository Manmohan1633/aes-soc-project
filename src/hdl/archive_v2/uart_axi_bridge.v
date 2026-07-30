`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2026 04:37:07 PM
// Design Name: 
// Module Name: uart_axi_bridge
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


module uart_axi_bridge #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115200
)(
    input  clk,
    input  rst_n,      // board reset button, active-low (Tang Nano convention)
    input  uart_rx_pin,
    output uart_tx_pin
);
    wire rst = ~rst_n;

    // ---- UART ----
    wire [7:0] rx_data;
    wire       rx_valid;
    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rst(rst), .rx(uart_rx_pin), .data(rx_data), .valid(rx_valid)
    );

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst(rst), .data(tx_data), .start(tx_start), .tx(uart_tx_pin), .busy(tx_busy)
    );

    // ---- AXI4-Lite signals to the existing wrapper (internal only, no pins) ----
    reg  [6:0]  awaddr, araddr;
    reg         awvalid, wvalid, arvalid, bready, rready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;

    axi_lite_aes256_wrapper axi (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    // ---- Bridge FSM ----
    localparam S_IDLE     = 4'd0,
               S_GOT_CMD  = 4'd1,
               S_RX_ADDR  = 4'd2,
               S_RX_D0    = 4'd3,
               S_RX_D1    = 4'd4,
               S_RX_D2    = 4'd5,
               S_RX_D3    = 4'd6,
               S_WSTART   = 4'd7,
               S_WWAIT    = 4'd8,
               S_WCLR     = 4'd9,
               S_TX_ACK   = 4'd10,
               S_RSTART   = 4'd11,
               S_RWAIT    = 4'd12,
               S_RCLR     = 4'd13,
               S_TX_BYTE  = 4'd14;

    reg [3:0]  st;
    reg        is_write;
    reg [6:0]  addr_reg;
    reg [31:0] wdata_reg;
    reg [31:0] rdata_reg;
    reg [1:0]  tx_byte_idx; // which of the 4 read-data bytes we're sending

    always @(posedge clk) begin
        if (rst) begin
            st <= S_IDLE;
            awvalid <= 0; wvalid <= 0; bready <= 0;
            arvalid <= 0; rready <= 0;
            tx_start <= 0; wstrb <= 4'hF;
        end else begin
            tx_start <= 1'b0; // default; pulsed explicitly below

            case (st)
                S_IDLE: begin
                    if (rx_valid) begin
                        if (rx_data == 8'h57) begin // 'W'
                            is_write <= 1'b1;
                            st <= S_RX_ADDR;
                        end else if (rx_data == 8'h52) begin // 'R'
                            is_write <= 1'b0;
                            st <= S_RX_ADDR;
                        end
                        // any other byte: ignored, stay in S_IDLE (simple resync)
                    end
                end

                S_RX_ADDR: begin
                    if (rx_valid) begin
                        addr_reg <= rx_data[6:0];
                        st <= is_write ? S_RX_D0 : S_RSTART;
                    end
                end

                S_RX_D0: if (rx_valid) begin wdata_reg[31:24] <= rx_data; st <= S_RX_D1; end
                S_RX_D1: if (rx_valid) begin wdata_reg[23:16] <= rx_data; st <= S_RX_D2; end
                S_RX_D2: if (rx_valid) begin wdata_reg[15:8]  <= rx_data; st <= S_RX_D3; end
                S_RX_D3: if (rx_valid) begin wdata_reg[7:0]   <= rx_data; st <= S_WSTART; end

                // ---- AXI write ----
                S_WSTART: begin
                    awaddr  <= addr_reg;
                    wdata   <= wdata_reg;
                    awvalid <= 1'b1;
                    wvalid  <= 1'b1;
                    bready  <= 1'b1;
                    st <= S_WWAIT;
                end
                S_WWAIT: begin
                    if (bvalid) begin
                        awvalid <= 1'b0;
                        wvalid  <= 1'b0;
                        st <= S_WCLR;
                    end
                end
                S_WCLR: begin
                    bready <= 1'b0; // held high for this one extra cycle so the wrapper's clear fires
                    st <= S_TX_ACK;
                end
                S_TX_ACK: begin
                    tx_data  <= 8'h41; // 'A'
                    tx_start <= 1'b1;
                    st <= S_IDLE;
                end

                // ---- AXI read ----
                S_RSTART: begin
                    araddr  <= addr_reg;
                    arvalid <= 1'b1;
                    rready  <= 1'b1;
                    st <= S_RWAIT;
                end
                S_RWAIT: begin
                    if (rvalid) begin
                        rdata_reg <= rdata;
                        arvalid   <= 1'b0;
                        st <= S_RCLR;
                    end
                end
                S_RCLR: begin
                    rready <= 1'b0; // held high one extra cycle, same reasoning as S_WCLR
                    tx_byte_idx <= 2'd0;
                    st <= S_TX_BYTE;
                end
                S_TX_BYTE: begin
                    if (!tx_busy && !tx_start) begin
                        case (tx_byte_idx)
                            2'd0: tx_data <= rdata_reg[31:24];
                            2'd1: tx_data <= rdata_reg[23:16];
                            2'd2: tx_data <= rdata_reg[15:8];
                            2'd3: tx_data <= rdata_reg[7:0];
                        endcase
                        tx_start <= 1'b1;
                        if (tx_byte_idx == 2'd3) begin
                            st <= S_IDLE;
                        end else begin
                            tx_byte_idx <= tx_byte_idx + 1'b1;
                        end
                    end
                end

                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
