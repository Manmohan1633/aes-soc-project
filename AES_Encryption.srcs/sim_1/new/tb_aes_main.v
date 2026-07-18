`timescale 1ns / 1ps

module tb_aes_main;

reg clk;
reg [127:0] data_in;
reg [127:0] key;

wire [127:0] data_out;

integer pass_count = 0;
integer fail_count = 0;


// DUT
aes_main uut (

    .clk(clk),
    .data_in(data_in),
    .key(key),
    .data_out(data_out)

);


// Clock generation
initial clk = 0;

always #5 clk = ~clk;



// ================= TASK =================
task run_vector;

    input [127:0] plaintext;
    input [127:0] k;
    input [127:0] expected;
    input [63:0] vec_num;

    begin

        data_in = plaintext;
        key     = k;

        // wait for AES pipeline
        repeat(120)
            @(posedge clk);

        $display("=================================");

        $display("VECTOR %0d", vec_num);

        $display("EXPECTED = %h", expected);

        $display("GOT      = %h", data_out);

        if (data_out === expected) begin

            $display("[PASS]");

            pass_count = pass_count + 1;

        end

        else begin

            $display("[FAIL]");

            fail_count = fail_count + 1;

        end

    end

endtask
// ========================================



initial begin

    $display("=================================");
    $display(" AES-128 TESTBENCH ");
    $display("=================================");


    // Vector 1
    run_vector(

        128'h00112233445566778899aabbccddeeff,
        128'h000102030405060708090a0b0c0d0e0f,
        128'h69c4e0d86a7b0430d8cdb78070b4c55a,
        1

    );


    #100;

    $display("=================================");
    $display("PASS = %0d", pass_count);
    $display("FAIL = %0d", fail_count);
    $display("=================================");

    $finish;

end

endmodule