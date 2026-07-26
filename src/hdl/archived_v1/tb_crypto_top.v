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
    reg clk, rst, start, mode;
    reg [127:0] data_in, master_key, round10_key;
    wire [127:0] data_out;
    wire done;

    // Internal hook to capture the key
    wire [127:0] enc_final_key; 

    // We modify the instantiation to access the internal encryption key
    Crypto_Engine_Top uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mode(mode), 
        .data_in(data_in),
        .master_key(master_key),
        .data_out(data_out),
        .done(done)
    );

    // Clock gen
    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        rst = 1; start = 0; mode = 0;
        #100; rst = 0; #20;

        // 1. ENCRYPTION
        $display("--- Starting Encryption ---");
        mode = 0;
        data_in = 128'h00112233445566778899aabbccddeeff;
        master_key = 128'h000102030405060708090a0b0c0d0e0f;
        start = 1; #10; start = 0;
        
        wait(done == 1'b1);
        @(posedge clk);
        
        // AUTOMATICALLY CAPTURE: Access the internal register of the core
        round10_key = uut.enc_core.key_gen.round_key;
        $display("Captured Round 10 Key: %h", round10_key);
        
        #45;

        // 2. DECRYPTION
        $display("--- Starting Decryption ---");
        mode = 1;
        data_in = data_out; // Use ciphertext from last run
        
        start = 1; #10; start = 0;
        wait(done == 1'b1);
        @(posedge clk);
        
        $display("Plaintext Out: %h", data_out);
        if (data_out == 128'h00112233445566778899aabbccddeeff)
            $display("SUCCESS: Plaintext recovered!");
        else
            $display("FAILED: Math mismatch.");

        $finish;
    end
endmodule
