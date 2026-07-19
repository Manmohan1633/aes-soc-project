`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:23:41 PM
// Design Name: 
// Module Name: tb_crypto_top
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


module tb_crypto_top();

    // Inputs
    reg clk;
    reg rst;
    reg start;
    reg mode;
    reg [127:0] data_in;
    reg [127:0] master_key;
    reg [127:0] round10_key;

    // Outputs
    wire [127:0] data_out;
    wire done;

    // Internal variables for verification
    reg [127:0] captured_ciphertext;

    // Instantiate the Unit Under Test (UUT)
    Crypto_Engine_Top uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .mode(mode), 
        .data_in(data_in), 
        .master_key(master_key), 
        .round10_key(round10_key), 
        .data_out(data_out), 
        .done(done)
    );

    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        // 1. Initialize Inputs
        rst = 1;
        start = 0;
        mode = 0;
        data_in = 128'd0;
        master_key = 128'd0;
        round10_key = 128'd0;

        // Wait 100 ns for global reset
        #100;
        rst = 0;
        #20;

        // =========================================================
        // PHASE 1: ENCRYPTION
        // =========================================================
        $display("--- STARTING ENCRYPTION ---");
        mode = 0; // Set to Encrypt
        
        // FIPS-197 Test Vectors
        data_in = 128'h00112233445566778899aabbccddeeff;
        master_key = 128'h000102030405060708090a0b0c0d0e0f;
        
        // Trigger the core
        start = 1;
        #10;
        start = 0;

        // Wait for encryption to finish
        wait(done == 1'b1);
        @(posedge clk); // Align to clock edge
        
        // Capture the output
        captured_ciphertext = data_out;
        $display("Plaintext In : %h", data_in);
        $display("Ciphertext Out: %h", captured_ciphertext);
        
        if (captured_ciphertext == 128'h69c4e0d86a7b0430d8cdb78070b4c55a)
            $display("ENCRYPTION SUCCESS: Matches FIPS-197 Vector.");
        else
            $display("ENCRYPTION FAILED.");

        #50; // Pause between operations

        // =========================================================
        // PHASE 2: DECRYPTION
        // =========================================================
        $display("--- STARTING DECRYPTION ---");
        mode = 1; // Set to Decrypt
        
        // Feed the captured ciphertext back in
        data_in = captured_ciphertext;
        
        // Pre-calculated Round 10 key for the specific Master Key above
        round10_key = 128'h13111d7fe3944a17f307a78b4d2b30c5;
        
        // Trigger the core
        start = 1;
        #10;
        start = 0;

        // Wait for decryption to finish
        wait(done == 1'b1);
        @(posedge clk);
        
        $display("Ciphertext In: %h", data_in);
        $display("Plaintext Out: %h", data_out);
        
        if (data_out == 128'h00112233445566778899aabbccddeeff)
            $display("DECRYPTION SUCCESS: Recovered original Plaintext.");
        else
            $display("DECRYPTION FAILED.");

        #50;
        $finish;
    end
endmodule
