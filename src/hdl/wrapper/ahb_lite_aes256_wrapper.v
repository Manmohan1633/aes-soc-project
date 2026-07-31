`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 08:35:23 PM
// Design Name: 
// Module Name: ahb_lite_aes256_wrapper
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


module ahb_lite_aes256_wrapper(
    input  wire        hclk,
    input  wire        hresetn,
    input  wire        hsel,
    input  wire [31:0] haddr,
    input  wire [1:0]  htrans,
    input  wire        hwrite,
    input  wire [31:0] hwdata,
    input  wire        hready,
    output wire        hreadyout,
    output wire [1:0]  hresp,
    output reg  [31:0] hrdata
);
    localparam HTRANS_NONSEQ = 2'b10, HTRANS_SEQ = 2'b11;
    assign hreadyout = 1'b1;
    assign hresp     = 2'b00;

    reg [6:0] r_haddr;
    reg       r_hwrite, r_hsel;
    always @(posedge hclk) begin
        if (!hresetn) begin r_haddr<=0; r_hwrite<=0; r_hsel<=0; end
        else if (hready) begin
            r_hsel   <= hsel && (htrans==HTRANS_NONSEQ || htrans==HTRANS_SEQ);
            r_haddr  <= haddr[6:0];
            r_hwrite <= hwrite;
        end
    end

    reg  [31:0] data_in_regs [0:3];
    reg  [31:0] key_regs     [0:7];
    reg         mode_reg, start_pulse, key_load_pulse;
    wire [127:0] data_in_bus    = {data_in_regs[0],data_in_regs[1],data_in_regs[2],data_in_regs[3]};
    wire [255:0] master_key_bus = {key_regs[0],key_regs[1],key_regs[2],key_regs[3],
                                    key_regs[4],key_regs[5],key_regs[6],key_regs[7]};
    wire [127:0] data_out_bus;
    wire         core_done, key_ready, key_busy;

    Crypto_Engine_256_Top core (
        .clk(hclk), .rst(~hresetn),
        .key_load(key_load_pulse), .master_key(master_key_bus),
        .key_ready(key_ready), .key_busy(key_busy),
        .start(start_pulse), .mode(mode_reg),
        .data_in(data_in_bus), .data_out(data_out_bus), .done(core_done)
    );

    reg op_busy;
    always @(posedge hclk) begin
        if (!hresetn) op_busy <= 0;
        else if (start_pulse) op_busy <= 1;
        else if (core_done)   op_busy <= 0;
    end
    wire [31:0] status_word = {29'd0, key_ready, core_done, (op_busy|key_busy)};

    always @(posedge hclk) begin
        start_pulse <= 0; key_load_pulse <= 0;
        if (!hresetn) begin mode_reg <= 0; end
        else if (r_hsel && r_hwrite) begin
            case (r_haddr)
                7'h00: begin start_pulse<=hwdata[0]; mode_reg<=hwdata[1]; key_load_pulse<=hwdata[2]; end
                7'h08: data_in_regs[0] <= hwdata;
                7'h0C: data_in_regs[1] <= hwdata;
                7'h10: data_in_regs[2] <= hwdata;
                7'h14: data_in_regs[3] <= hwdata;
                7'h18: key_regs[0] <= hwdata;
                7'h1C: key_regs[1] <= hwdata;
                7'h20: key_regs[2] <= hwdata;
                7'h24: key_regs[3] <= hwdata;
                7'h28: key_regs[4] <= hwdata;
                7'h2C: key_regs[5] <= hwdata;
                7'h30: key_regs[6] <= hwdata;
                7'h34: key_regs[7] <= hwdata;
                default: ;
            endcase
        end
    end

    always @(*) begin
        hrdata = 32'h0;
        if (r_hsel && !r_hwrite) begin
            case (r_haddr)
                7'h04: hrdata = status_word;
                7'h38: hrdata = data_out_bus[127:96];
                7'h3C: hrdata = data_out_bus[95:64];
                7'h40: hrdata = data_out_bus[63:32];
                7'h44: hrdata = data_out_bus[31:0];
                default: hrdata = 32'h0;
            endcase
        end
    end
endmodule
