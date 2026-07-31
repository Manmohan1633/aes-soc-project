`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 08:36:50 PM
// Design Name: 
// Module Name: soc_top
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



module soc_top (
    input  wire clk,         // Tang Nano 4K pin 45
    input  wire rst_n,       // Tang Nano 4K pin 15
    input  wire uart_rx_pin, // Tang Nano 4K pin 30
    output wire uart_tx_pin  // Tang Nano 4K pin 31
);

    // Internal AHB-Lite bus wires
    wire [31:0] ahb_haddr;
    wire [1:0]  ahb_htrans;
    wire        ahb_hwrite;
    wire [31:0] ahb_hwdata;
    wire        ahb_hsel;
    wire [31:0] ahb_hrdata;
    wire        ahb_hreadyout; 
    wire [1:0]  ahb_hresp;

    // 1. The Hard-Core MCU (EMPU)
    Gowin_EMPU_Top mcu_inst (
        .sys_clk(clk),
        .reset_n(rst_n),
        .uart0_rxd(uart_rx_pin),
        .uart0_txd(uart_tx_pin),
        
        // AHB Master Ports (matching your generated template)
        .master_hsel(ahb_hsel),
        .master_haddr(ahb_haddr),
        .master_htrans(ahb_htrans),
        .master_hwrite(ahb_hwrite),
        .master_hwdata(ahb_hwdata),
        .master_hrdata(ahb_hrdata),
        .master_hreadyout(ahb_hreadyout), 
        .master_hresp(ahb_hresp),
        
        // Tie off unused inputs required by the EMPU Master port
        .master_hexresp(1'b0),
        .master_hruser(3'b000)
    );

    // 2. The Custom Hardware Accelerator
    ahb_lite_aes256_wrapper aes_hw (
        .hclk(clk),
        .hresetn(rst_n),
        .hsel(ahb_hsel),
        .haddr(ahb_haddr),
        .htrans(ahb_htrans),
        .hwrite(ahb_hwrite),
        .hwdata(ahb_hwdata),
        .hready(1'b1),               // Hardcoded ready for simple peripheral
        .hreadyout(ahb_hreadyout),
        .hresp(ahb_hresp),
        .hrdata(ahb_hrdata)
    );

endmodule
