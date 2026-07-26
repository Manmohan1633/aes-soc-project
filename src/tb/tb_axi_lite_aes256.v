`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 10:35:00 AM
// Design Name: 
// Module Name: tb_axi_lite_aes256
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


module tb_axi_lite_aes256;
    reg clk = 0, aresetn;
    reg  [6:0]  awaddr, araddr;
    reg         awvalid, wvalid, arvalid, bready, rready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;

    // Instantiate the Top-Level AXI Wrapper
    axi_lite_aes256_wrapper dut (
        .s_axi_aclk(clk), .s_axi_aresetn(aresetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    // 100MHz Clock Generation
    always #5 clk = ~clk;

    // --- AXI-Lite Master Read/Write Tasks ---
    // These tasks handle the complex AXI handshaking protocol safely
    task axi_write(input [6:0] addr, input [31:0] data);
        begin
            @(posedge clk); #1;
            awaddr = addr; wdata = data; wstrb = 4'hF;
            awvalid = 1; wvalid = 1; bready = 1;
            while (!bvalid) begin @(posedge clk); #1; end
            awvalid = 0; wvalid = 0;
            @(posedge clk); #1;   // hold bready one more cycle so DUT's clear fires
            bready = 0;
        end
    endtask

    task axi_read(input [6:0] addr, output [31:0] data);
        begin
            @(posedge clk); #1;
            araddr = addr; arvalid = 1; rready = 1;
            while (!rvalid) begin @(posedge clk); #1; end
            data = rdata;
            arvalid = 0;
            @(posedge clk); #1;   // hold rready one more cycle so DUT's clear fires
            rready = 0;
        end
    endtask

    reg [31:0] rd;
    reg [31:0] key_words [0:7];
    reg [31:0] pt_words  [0:3];
    reg [127:0] ct;
    integer i;

    // Simulation Watchdog to prevent infinite loops
    initial begin
        #200000;
        $display("WATCHDOG TIMEOUT - simulation hung");
        $finish;
    end

    // --- Main Test Sequence ---
    initial begin
        // Initialize inputs
        awvalid=0; wvalid=0; arvalid=0; bready=0; rready=0;
        awaddr=0; araddr=0; wdata=0; wstrb=0;
        aresetn = 0;
        
        // Reset Sequence
        repeat (3) @(negedge clk);
        aresetn = 1;
        @(negedge clk);

        // 1. Write the 256-bit Key to the Key Registers (0x18 to 0x34)
        key_words[0]=32'h00010203; key_words[1]=32'h04050607;
        key_words[2]=32'h08090a0b; key_words[3]=32'h0c0d0e0f;
        key_words[4]=32'h10111213; key_words[5]=32'h14151617;
        key_words[6]=32'h18191a1b; key_words[7]=32'h1c1d1e1f;
        
        for (i = 0; i < 8; i = i + 1)
            axi_write(7'h18 + i*4, key_words[i]);
            
        $display("AXI: Key words written to registers.");

        // 2. Trigger Key Expansion via CTRL Register (bit 2)
        axi_write(7'h00, 32'h4);
        
        // Poll STATUS Register until KEY_READY (bit 2) goes high
        rd = 0;
        while (!rd[2]) axi_read(7'h04, rd);
        $display("AXI: key_ready observed via STATUS register.");

        // 3. Write Plaintext to DATA_IN Registers (0x08 to 0x14)
        pt_words[0]=32'h00112233; pt_words[1]=32'h44556677;
        pt_words[2]=32'h8899aabb; pt_words[3]=32'hccddeeff;
        
        for (i = 0; i < 4; i = i + 1)
            axi_write(7'h08 + i*4, pt_words[i]);

        // 4. Start Encryption: CTRL Register START=1 (bit 0), MODE=0 (bit 1)
        axi_write(7'h00, 32'h1);

        // Poll STATUS Register until DONE (bit 1) goes high
        rd = 0;
        while (!rd[1]) axi_read(7'h04, rd);

        // 5. Read Ciphertext from DATA_OUT Registers (0x38 to 0x44)
        axi_read(7'h38, rd); ct[127:96] = rd;
        axi_read(7'h3C, rd); ct[95:64]  = rd;
        axi_read(7'h40, rd); ct[63:32]  = rd;
        axi_read(7'h44, rd); ct[31:0]   = rd;
        
        $display("AXI ciphertext: %h", ct);
        $display("Expected      : 8ea2b7ca516745bfeafc49904b496089");
        
        if (ct === 128'h8ea2b7ca516745bfeafc49904b496089)
            $display("[PASS] AXI4-Lite register path reproduces FIPS-197 C.3 encryption");
        else
            $display("[FAIL] AXI4-Lite path mismatch");

        // -------------------------------------------------------------
        // DECRYPTION TEST
        // -------------------------------------------------------------
        
        // Write the ciphertext we just generated back into the DATA_IN registers
        axi_write(7'h08, ct[127:96]);
        axi_write(7'h0C, ct[95:64]);
        axi_write(7'h10, ct[63:32]);
        axi_write(7'h14, ct[31:0]);

        // Start Decryption: CTRL Register START=1 (bit 0) | MODE=1 (bit 1) -> 32'h3
        axi_write(7'h00, 32'h3);

        // Poll STATUS until DONE
        rd = 0;
        while (!rd[1]) axi_read(7'h04, rd);

        // Read Plaintext back out
        axi_read(7'h38, rd); ct[127:96] = rd;
        axi_read(7'h3C, rd); ct[95:64]  = rd;
        axi_read(7'h40, rd); ct[63:32]  = rd;
        axi_read(7'h44, rd); ct[31:0]   = rd;
        
        $display("AXI plaintext : %h", ct);
        $display("Expected      : 00112233445566778899aabbccddeeff");
        
        if (ct === 128'h00112233445566778899aabbccddeeff)
            $display("[PASS] AXI4-Lite register path reproduces round-trip decryption");
        else
            $display("[FAIL] AXI4-Lite decrypt path mismatch");

        $finish;
    end
endmodule
