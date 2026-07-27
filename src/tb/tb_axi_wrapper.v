`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2026 10:51:02 AM
// Design Name: 
// Module Name: tb_axi_wrapper
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


module tb_axi_wrapper;

    // AXI4-Lite Interface Signals
    reg         s_axi_aclk;
    reg         s_axi_aresetn;
    
    reg [6:0]   s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    
    reg [31:0]  s_axi_wdata;
    reg [3:0]   s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;
    
    reg [6:0]   s_axi_araddr;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // Instantiate the Wrapper (UUT)
    axi_lite_aes256_wrapper #(
        .ADDR_WIDTH(7)
    ) uut (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // Clock generation (100MHz)
    initial s_axi_aclk = 0;
    always #5 s_axi_aclk = ~s_axi_aclk;

    // -----------------------------------------------------------
    // AXI Write Task (Delta-Cycle Safe)
    // -----------------------------------------------------------
    task axi_write(input [6:0] addr, input [31:0] data);
        begin
            // Setup signals on clock edge using non-blocking assignments
            @(posedge s_axi_aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;
            
            // Wait for wrapper to assert ready (clock-synchronized polling)
            while (s_axi_awready == 1'b0) begin
                @(posedge s_axi_aclk);
            end
            
            // Drop valid signals immediately after handshake
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;
            
            // Wait for the write response (bvalid)
            while (s_axi_bvalid == 1'b0) begin
                @(posedge s_axi_aclk);
            end
            
            // Clear ready signal
            s_axi_bready  <= 1'b0;
        end
    endtask

    // -----------------------------------------------------------
    // AXI Read Task (Delta-Cycle Safe)
    // -----------------------------------------------------------
    task axi_read(input [6:0] addr, output [31:0] data);
        begin
            // Setup address on clock edge using non-blocking assignments
            @(posedge s_axi_aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;
            
            // Wait for wrapper to accept address
            while (s_axi_arready == 1'b0) begin
                @(posedge s_axi_aclk);
            end
            
            // Drop address valid
            s_axi_arvalid <= 1'b0;
            
            // Wait for wrapper to provide data
            while (s_axi_rvalid == 1'b0) begin
                @(posedge s_axi_aclk);
            end
            
            // Capture data (blocking is fine here because we are assigning to a task output variable)
            data = s_axi_rdata; 
            
            // End transaction
            s_axi_rready <= 1'b0;
        end
    endtask

    // Variables for reading back data
    reg [31:0] read_val;
    reg [127:0] cipher_result;
    reg [127:0] plain_result;

    initial begin
        // Initialize inputs
        s_axi_aresetn = 0;
        s_axi_awaddr = 0; s_axi_awvalid = 0;
        s_axi_wdata = 0;  s_axi_wstrb = 0; s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0; s_axi_arvalid = 0;
        s_axi_rready = 0;

        #100;
        @(posedge s_axi_aclk);
        s_axi_aresetn = 1; // Release reset (active low)
        #50;

        $display("============================================");
        $display("Starting AXI4-Lite AES-256 Full System Test");
        $display("============================================\n");

        // -----------------------------------------------------------
        // Step 1: Load Master Key (FIPS-197 vector)
        // Key: 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
        // -----------------------------------------------------------
        $display("Loading 256-bit Master Key via AXI...");
        axi_write(7'h18, 32'h00010203); // key_regs[0]
        axi_write(7'h1C, 32'h04050607); // key_regs[1]
        axi_write(7'h20, 32'h08090a0b); // key_regs[2]
        axi_write(7'h24, 32'h0c0d0e0f); // key_regs[3]
        axi_write(7'h28, 32'h10111213); // key_regs[4]
        axi_write(7'h2C, 32'h14151617); // key_regs[5]
        axi_write(7'h30, 32'h18191a1b); // key_regs[6]
        axi_write(7'h34, 32'h1c1d1e1f); // key_regs[7]

        // Trigger Key Load (CTRL Register 0x00, bit 2 = key_load_pulse)
        axi_write(7'h00, 32'h00000004); 
        
        $display("Waiting for Key Schedule to finish...");
        read_val = 0;
        while ((read_val & 32'h00000004) == 0) begin // Check bit 2 (key_ready)
            axi_read(7'h04, read_val);               // STATUS register
        end
        $display("Key Schedule Ready!\n");

        // -----------------------------------------------------------
        // Step 2: Encryption
        // PT: 00112233445566778899aabbccddeeff
        // Expected CT: 8ea2b7ca516745bfeafc49904b496089
        // -----------------------------------------------------------
        $display("Loading Plaintext...");
        axi_write(7'h08, 32'h00112233); // data_in_regs[0]
        axi_write(7'h0C, 32'h44556677); // data_in_regs[1]
        axi_write(7'h10, 32'h8899aabb); // data_in_regs[2]
        axi_write(7'h14, 32'hccddeeff); // data_in_regs[3]

        // Trigger Start (CTRL Register 0x00, bit 0 = start_pulse, bit 1 = mode 0)
        axi_write(7'h00, 32'h00000001); 

        $display("Encrypting...");
        read_val = 0;
        while ((read_val & 32'h00000002) == 0) begin // Check bit 1 (core_done)
            axi_read(7'h04, read_val);
        end
        
        // Read out Ciphertext
        axi_read(7'h38, read_val); cipher_result[127:96] = read_val;
        axi_read(7'h3C, read_val); cipher_result[95:64]  = read_val;
        axi_read(7'h40, read_val); cipher_result[63:32]  = read_val;
        axi_read(7'h44, read_val); cipher_result[31:0]   = read_val;
        
        $display("Ciphertext Generated: %h", cipher_result);
        if (cipher_result == 128'h8ea2b7ca516745bfeafc49904b496089)
            $display("[PASS] Encryption matched FIPS-197 standard.\n");
        else
            $display("[FAIL] Encryption incorrect.\n");

        // -----------------------------------------------------------
        // Step 3: Decryption
        // CT: 8ea2b7ca516745bfeafc49904b496089
        // Expected PT: 00112233445566778899aabbccddeeff
        // -----------------------------------------------------------
        $display("Loading Ciphertext back in...");
        axi_write(7'h08, cipher_result[127:96]); 
        axi_write(7'h0C, cipher_result[95:64]);  
        axi_write(7'h10, cipher_result[63:32]);  
        axi_write(7'h14, cipher_result[31:0]);   

        // Trigger Start (CTRL Register 0x00, bit 0 = start_pulse, bit 1 = mode 1 [decrypt])
        axi_write(7'h00, 32'h00000003); // 3'b011

        $display("Decrypting...");
        read_val = 0;
        while ((read_val & 32'h00000002) == 0) begin // Check bit 1 (core_done)
            axi_read(7'h04, read_val);
        end
        
        // Read out Plaintext
        axi_read(7'h38, read_val); plain_result[127:96] = read_val;
        axi_read(7'h3C, read_val); plain_result[95:64]  = read_val;
        axi_read(7'h40, read_val); plain_result[63:32]  = read_val;
        axi_read(7'h44, read_val); plain_result[31:0]   = read_val;
        
        $display("Plaintext Recovered:  %h", plain_result);
        if (plain_result == 128'h00112233445566778899aabbccddeeff)
            $display("[PASS] Decryption matched FIPS-197 standard.\n");
        else
            $display("[FAIL] Decryption incorrect.\n");

        $display("============================================");
        $display("Testbench Finished.");
        $finish;
    end
endmodule