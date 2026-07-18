`timescale 1ns / 1ps

module tb_aes_main;

    // Inputs
    reg clk;
    reg rst;
    reg start;
    reg [127:0] data_in;
    reg [127:0] key;

    // Outputs
    wire [127:0] data_out;
    wire done;

    // Instantiate the Unit Under Test (DUT)
    AES_main uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .data_in(data_in),
        .key(key),
        .data_out(data_out),
        .done(done)
    );

    // Clock generation (100MHz -> 10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Task for running a test vector
    task run_vector;
        input [127:0] plaintext;
        input [127:0] k;
        input [127:0] expected;
        input [63:0] vec_num;
        
        reg [31:0] timeout_counter;
        begin
            $display("--- Vector %0d ---", vec_num);
            
            // 1. Reset sequence
            rst = 1; 
            start = 0;
            data_in = 0; 
            key = 0;
            #20 rst = 0;
            
            // 2. Cooldown: Wait for reset to fully stabilize
            #10; 
            
            // 3. Set inputs
            data_in = plaintext;
            key = k;
            
            // 4. Pulse start
            #10 start = 1;
            #10 start = 0;
            
            // 5. Wait for done signal with a timeout
            timeout_counter = 0;
            while (done !== 1 && timeout_counter < 1000) begin
                #10;
                timeout_counter = timeout_counter + 10;
            end
            
            // 6. Check results
            if (done !== 1) begin
                $display("[FAIL] Timeout: 'done' signal never went high.");
            end else if (data_out === expected) begin
                $display("[PASS] Got: %h", data_out);
            end else begin
                $display("[FAIL] Expected: %h", expected);
                $display("       Got:      %h", data_out);
            end
            
            #20;
        end
    endtask

    initial begin
        // Initialize inputs to prevent X
        clk = 0;
        rst = 0;
        start = 0;
        data_in = 0;
        key = 0;

        $display("Starting AES-128 Iterative Testbench...");
        
        // Test Vector 1
        run_vector(
            128'h00112233445566778899aabbccddeeff,
            128'h000102030405060708090a0b0c0d0e0f,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a,
            1
        );

        $display("Tests complete.");
        $finish;
    end

endmodule