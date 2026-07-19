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

    reg clk;
    reg rst;
    reg start;
    reg mode;
    reg [127:0] data_in;
    reg [127:0] master_key;
    reg [127:0] round10_key;

    wire [127:0] data_out;
    wire done;

    reg [127:0] captured_ciphertext;

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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1;
        start = 0;
        mode = 0;
        data_in = 128'd0;
        master_key = 128'd0;
        round10_key = 128'd0;

        #100;
        rst = 0;
        #20;

        $display("--- STARTING ENCRYPTION ---");
        mode = 0; 
        
        data_in = 128'h00112233445566778899aabbccddeeff;
        master_key = 128'h000102030405060708090a0b0c0d0e0f;
        
        start = 1;
        #10;
        start = 0;

        wait(done == 1'b1);
        @(posedge clk); 
        
        captured_ciphertext = data_out;
        $display("Plaintext In : %h", data_in);
        $display("Ciphertext Out: %h", captured_ciphertext);
        
        if (captured_ciphertext == 128'h69c4e0d86a7b0430d8cdb78070b4c55a)
            $display("ENCRYPTION SUCCESS: Matches FIPS-197 Vector.");
        else
            $display("ENCRYPTION FAILED.");

        #50; 

        $display("--- STARTING DECRYPTION ---");
        mode = 1; 
        
        data_in = captured_ciphertext;
        round10_key = 128'h13111d7fe3944a17f307a78b4d2b30c5;
        
        start = 1;
        #10;
        start = 0;

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
