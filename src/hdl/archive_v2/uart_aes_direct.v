`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 01:49:40 PM
// Design Name: 
// Module Name: uart_aes_direct
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


module uart_aes_direct #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115200
)(
    input  clk,
    input  rst_n,
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

    // ---- AES core, driven directly: plain registers, no bus handshake ----
    reg  [31:0] data_in_regs [0:3];
    reg  [31:0] key_regs     [0:7];
    reg         mode_reg;
    reg         start_pulse, key_load_pulse;

    wire [127:0] data_in_bus    = {data_in_regs[0], data_in_regs[1], data_in_regs[2], data_in_regs[3]};
    wire [255:0] master_key_bus = {key_regs[0], key_regs[1], key_regs[2], key_regs[3],
                                    key_regs[4], key_regs[5], key_regs[6], key_regs[7]};
    wire [127:0] data_out_bus;
    wire         core_done, key_ready, key_busy;

    Crypto_Engine_256_Top core (
        .clk(clk), .rst(rst),
        .key_load(key_load_pulse), .master_key(master_key_bus),
        .key_ready(key_ready), .key_busy(key_busy),
        .start(start_pulse), .mode(mode_reg),
        .data_in(data_in_bus), .data_out(data_out_bus), .done(core_done)
    );

    reg op_busy;
    always @(posedge clk) begin
        if (rst) op_busy <= 1'b0;
        else if (start_pulse) op_busy <= 1'b1;
        else if (core_done)   op_busy <= 1'b0;
    end

    

    wire [31:0] status_word = {29'd0, key_ready, core_done, (op_busy | key_busy)};

    // ---- Bridge FSM ----
    localparam S_IDLE    = 4'd0,
               S_RX_ADDR = 4'd1,
               S_RX_D0   = 4'd2,
               S_RX_D1   = 4'd3,
               S_RX_D2   = 4'd4,
               S_RX_D3   = 4'd5,
               S_APPLY_W = 4'd6,
               S_TX_ACK  = 4'd7,
               S_APPLY_R = 4'd8,
               S_TX_BYTE = 4'd9;

    reg [3:0]  st;
    reg        is_write;
    reg [6:0]  addr_reg;
    reg [31:0] wdata_reg;
    reg [31:0] rdata_reg;
    reg [1:0]  tx_idx;

    always @(posedge clk) begin
        if (rst) begin
            st <= S_IDLE;
            start_pulse <= 1'b0; key_load_pulse <= 1'b0; tx_start <= 1'b0; mode_reg <= 1'b0;
        end else begin
            start_pulse    <= 1'b0;
            key_load_pulse <= 1'b0;
            tx_start       <= 1'b0;

            case (st)
                S_IDLE: begin
                    if (rx_valid) begin
                        if (rx_data == 8'h57) begin is_write <= 1'b1; st <= S_RX_ADDR; end
                        else if (rx_data == 8'h52) begin is_write <= 1'b0; st <= S_RX_ADDR; end
                    end
                end

                S_RX_ADDR: begin
                    if (rx_valid) begin
                        addr_reg <= rx_data[6:0];
                        st <= is_write ? S_RX_D0 : S_APPLY_R;
                    end
                end

                S_RX_D0: if (rx_valid) begin wdata_reg[31:24] <= rx_data; st <= S_RX_D1; end
                S_RX_D1: if (rx_valid) begin wdata_reg[23:16] <= rx_data; st <= S_RX_D2; end
                S_RX_D2: if (rx_valid) begin wdata_reg[15:8]  <= rx_data; st <= S_RX_D3; end
                S_RX_D3: if (rx_valid) begin wdata_reg[7:0]   <= rx_data; st <= S_APPLY_W; end

                S_APPLY_W: begin
                    case (addr_reg)
                        7'h00: begin
                            start_pulse    <= wdata_reg[0];
                            mode_reg       <= wdata_reg[1];
                            key_load_pulse <= wdata_reg[2];
                        end
                        7'h08: data_in_regs[0] <= wdata_reg;
                        7'h0C: data_in_regs[1] <= wdata_reg;
                        7'h10: data_in_regs[2] <= wdata_reg;
                        7'h14: data_in_regs[3] <= wdata_reg;
                        7'h18: key_regs[0] <= wdata_reg;
                        7'h1C: key_regs[1] <= wdata_reg;
                        7'h20: key_regs[2] <= wdata_reg;
                        7'h24: key_regs[3] <= wdata_reg;
                        7'h28: key_regs[4] <= wdata_reg;
                        7'h2C: key_regs[5] <= wdata_reg;
                        7'h30: key_regs[6] <= wdata_reg;
                        7'h34: key_regs[7] <= wdata_reg;
                        default: ;
                    endcase
                    st <= S_TX_ACK;
                end
                S_TX_ACK: begin
                    tx_data  <= 8'h41; // 'A'
                    tx_start <= 1'b1;
                    st <= S_IDLE;
                end

                S_APPLY_R: begin
                    case (addr_reg)
                        7'h04:   rdata_reg <= status_word;
                        7'h38:   rdata_reg <= data_out_bus[127:96];
                        7'h3C:   rdata_reg <= data_out_bus[95:64];
                        7'h40:   rdata_reg <= data_out_bus[63:32];
                        7'h44:   rdata_reg <= data_out_bus[31:0];
                        default: rdata_reg <= 32'd0;
                    endcase
                    tx_idx <= 2'd0;
                    st <= S_TX_BYTE;
                end
                S_TX_BYTE: begin
                    if (!tx_busy && !tx_start) begin
                        case (tx_idx)
                            2'd0: tx_data <= rdata_reg[31:24];
                            2'd1: tx_data <= rdata_reg[23:16];
                            2'd2: tx_data <= rdata_reg[15:8];
                            2'd3: tx_data <= rdata_reg[7:0];
                        endcase
                        tx_start <= 1'b1;
                        if (tx_idx == 2'd3) st <= S_IDLE;
                        else tx_idx <= tx_idx + 1'b1;
                    end
                end

                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
