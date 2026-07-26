`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 10:31:08 AM
// Design Name: 
// Module Name: axi_lite_aes256_wrapper
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


module axi_lite_aes256_wrapper #(
    parameter ADDR_WIDTH = 7   
)(
    input                       s_axi_aclk,
    input                       s_axi_aresetn,
    // Write address channel
    input  [ADDR_WIDTH-1:0]     s_axi_awaddr,
    input                       s_axi_awvalid,
    output reg                  s_axi_awready,
    // Write data channel
    input  [31:0]                s_axi_wdata,
    input  [3:0]                 s_axi_wstrb,
    input                        s_axi_wvalid,
    output reg                   s_axi_wready,
    // Write response channel
    output reg [1:0]             s_axi_bresp,
    output reg                   s_axi_bvalid,
    input                        s_axi_bready,
    // Read address channel
    input  [ADDR_WIDTH-1:0]      s_axi_araddr,
    input                        s_axi_arvalid,
    output reg                   s_axi_arready,
    // Read data channel
    output reg [31:0]            s_axi_rdata,
    output reg [1:0]             s_axi_rresp,
    output reg                   s_axi_rvalid,
    input                        s_axi_rready
);
    localparam RESP_OKAY = 2'b00;
    wire clk = s_axi_aclk;
    wire rst = ~s_axi_aresetn;
    
    // ---- Register file ----
    reg  [31:0] data_in_regs [0:3];
    reg  [31:0] key_regs     [0:7];
    reg  [31:0] status_reg;
    reg         mode_reg;
    
    wire [127:0] data_in_bus  = {data_in_regs[0], data_in_regs[1], data_in_regs[2], data_in_regs[3]};
    wire [255:0] master_key_bus = {key_regs[0], key_regs[1], key_regs[2], key_regs[3],
                                    key_regs[4], key_regs[5], key_regs[6], key_regs[7]};
    wire [127:0] data_out_bus;
    
    wire         core_done, core_busy_unused;
    wire         key_busy, key_ready;
    reg start_pulse, key_load_pulse;
    
    Crypto_Engine_256_Top core (
        .clk(clk), .rst(rst),
        .key_load(key_load_pulse), .master_key(master_key_bus),
        .key_busy(key_busy), .key_ready(key_ready),
        .start(start_pulse), .mode(mode_reg),
        .data_in(data_in_bus), .data_out(data_out_bus), .done(core_done)
    );
    
    reg op_busy;
    always @(posedge clk) begin
        if (rst) op_busy <= 1'b0;
        else if (start_pulse) op_busy <= 1'b1;
        else if (core_done) op_busy <= 1'b0;
    end
    assign core_busy_unused = 1'b0;
    
    always @(posedge clk) begin
        status_reg <= {29'd0, key_ready, core_done, (op_busy | key_busy)};
    end
    
    reg [127:0] data_out_latched;
    always @(posedge clk) begin
        if (rst) data_out_latched <= 128'd0;
        else if (core_done) data_out_latched <= data_out_bus;
    end

    // AXI4-Lite Write Channel
    wire write_en = s_axi_awvalid & s_axi_wvalid & ~s_axi_awready;
    always @(posedge clk) begin
        if (rst) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
        end else begin
            s_axi_awready <= write_en;
            s_axi_wready  <= write_en;
        end
    end
    
    always @(posedge clk) begin
        start_pulse    <= 1'b0;
        key_load_pulse <= 1'b0;
        if (rst) begin
            mode_reg <= 1'b0;
        end else if (write_en) begin
            case (s_axi_awaddr[6:2])
                5'h00: begin // CTRL
                    if (s_axi_wstrb[0]) begin
                        start_pulse    <= s_axi_wdata[0];
                        mode_reg       <= s_axi_wdata[1];
                        key_load_pulse <= s_axi_wdata[2];
                    end
                end
                5'h02: if (s_axi_wstrb[0]) data_in_regs[0] <= s_axi_wdata; // 0x08
                5'h03: if (s_axi_wstrb[0]) data_in_regs[1] <= s_axi_wdata; // 0x0C
                5'h04: if (s_axi_wstrb[0]) data_in_regs[2] <= s_axi_wdata; // 0x10
                5'h05: if (s_axi_wstrb[0]) data_in_regs[3] <= s_axi_wdata; // 0x14
                5'h06: if (s_axi_wstrb[0]) key_regs[0] <= s_axi_wdata;     // 0x18
                5'h07: if (s_axi_wstrb[0]) key_regs[1] <= s_axi_wdata;     // 0x1C
                5'h08: if (s_axi_wstrb[0]) key_regs[2] <= s_axi_wdata;     // 0x20
                5'h09: if (s_axi_wstrb[0]) key_regs[3] <= s_axi_wdata;     // 0x24
                5'h0A: if (s_axi_wstrb[0]) key_regs[4] <= s_axi_wdata;     // 0x28
                5'h0B: if (s_axi_wstrb[0]) key_regs[5] <= s_axi_wdata;     // 0x2C
                5'h0C: if (s_axi_wstrb[0]) key_regs[6] <= s_axi_wdata;     // 0x30
                5'h0D: if (s_axi_wstrb[0]) key_regs[7] <= s_axi_wdata;     // 0x34
                default: ; 
            endcase
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= RESP_OKAY;
        end else if (write_en) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= RESP_OKAY;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end

    // AXI4-Lite Read Channel
    reg [31:0] rdata_next;
    always @(*) begin
        case (s_axi_araddr[6:2])
            5'h00: rdata_next = {29'd0, mode_reg, 1'b0, 1'b0}; 
            5'h01: rdata_next = status_reg;                     
            5'h02: rdata_next = data_in_regs[0];
            5'h03: rdata_next = data_in_regs[1];
            5'h04: rdata_next = data_in_regs[2];
            5'h05: rdata_next = data_in_regs[3];
            5'h06: rdata_next = key_regs[0];
            5'h07: rdata_next = key_regs[1];
            5'h08: rdata_next = key_regs[2];
            5'h09: rdata_next = key_regs[3];
            5'h0A: rdata_next = key_regs[4];
            5'h0B: rdata_next = key_regs[5];
            5'h0C: rdata_next = key_regs[6];
            5'h0D: rdata_next = key_regs[7];
            5'h0E: rdata_next = data_out_latched[127:96]; 
            5'h0F: rdata_next = data_out_latched[95:64];  
            5'h10: rdata_next = data_out_latched[63:32];  
            5'h11: rdata_next = data_out_latched[31:0];   
            default: rdata_next = 32'd0;
        endcase
    end
    
    always @(posedge clk) begin
        if (rst) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= RESP_OKAY;
        end else begin
            s_axi_arready <= s_axi_arvalid & ~s_axi_arready & ~s_axi_rvalid;
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata  <= rdata_next;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= RESP_OKAY;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end
endmodule
