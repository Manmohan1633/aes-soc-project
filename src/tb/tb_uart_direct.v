`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/30/2026 02:03:12 PM
// Design Name: 
// Module Name: tb_uart_direct
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


module tb_uart_direct;
    localparam CLK_FREQ = 27_000_000;
    localparam BAUD     = 115200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD; // = 10

    reg clk = 0, rst_n;
    reg uart_rx_pin;
    wire uart_tx_pin;

    uart_aes_direct #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut (
        .clk(clk), .rst_n(rst_n),
        .uart_rx_pin(uart_rx_pin), .uart_tx_pin(uart_tx_pin)
    );

    always #18.5 clk = ~clk;

    integer i;
    reg [7:0] rxb;
    reg [31:0] readback;
    reg [31:0] c0, c1, c2, c3;

    task uart_send_byte(input [7:0] b);
        integer k;
        begin
            uart_rx_pin = 1'b0; // start bit
            repeat (CLKS_PER_BIT) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                uart_rx_pin = b[k]; // LSB first, standard UART framing
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            uart_rx_pin = 1'b1; // stop bit
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    task uart_recv_byte(output [7:0] b);
        integer k;
        begin
            wait (uart_tx_pin == 1'b0);           // start bit begins
            repeat (CLKS_PER_BIT + CLKS_PER_BIT/2) @(posedge clk); // land mid-bit0
            for (k = 0; k < 8; k = k + 1) begin
                b[k] = uart_tx_pin;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
        end
    endtask

    task uart_write(input [6:0] addr, input [31:0] data);
        begin
            uart_send_byte(8'h57); // 'W'
            uart_send_byte({1'b0, addr});
            uart_send_byte(data[31:24]);
            uart_send_byte(data[23:16]);
            uart_send_byte(data[15:8]);
            uart_send_byte(data[7:0]);
            uart_recv_byte(rxb); // ACK
            if (rxb !== 8'h41) $display("[WARN] expected ACK 0x41, got %h", rxb);
        end
    endtask

    task uart_read(input [6:0] addr, output [31:0] data);
        reg [7:0] b0, b1, b2, b3;
        begin
            uart_send_byte(8'h52); // 'R'
            uart_send_byte({1'b0, addr});
            uart_recv_byte(b0);
            uart_recv_byte(b1);
            uart_recv_byte(b2);
            uart_recv_byte(b3);
            data = {b0, b1, b2, b3};
        end
    endtask

    initial begin
        rst_n = 0; uart_rx_pin = 1'b1;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("Loading key over UART...");
        uart_write(7'h18, 32'h00010203);
        uart_write(7'h1C, 32'h04050607);
        uart_write(7'h20, 32'h08090a0b);
        uart_write(7'h24, 32'h0c0d0e0f);
        uart_write(7'h28, 32'h10111213);
        uart_write(7'h2C, 32'h14151617);
        uart_write(7'h30, 32'h18191a1b);
        uart_write(7'h34, 32'h1c1d1e1f);
        uart_write(7'h00, 32'h4); // CTRL: KEY_LOAD

        $display("Polling STATUS for key_ready over UART...");
        readback = 0;
        while (!readback[2]) uart_read(7'h04, readback);
        $display("Key ready.");

        $display("Loading plaintext over UART...");
        uart_write(7'h08, 32'h00112233);
        uart_write(7'h0C, 32'h44556677);
        uart_write(7'h10, 32'h8899aabb);
        uart_write(7'h14, 32'hccddeeff);
        uart_write(7'h00, 32'h1); // CTRL: START, MODE=0 (encrypt)

        $display("Polling STATUS for done over UART (encrypt)...");
        readback = 0;
        while (!readback[1]) uart_read(7'h04, readback);

        begin
            uart_read(7'h38, c0);
            uart_read(7'h3C, c1);
            uart_read(7'h40, c2);
            uart_read(7'h44, c3);
            $display("Ciphertext via UART: %h%h%h%h", c0, c1, c2, c3);
            $display("Expected           : 8ea2b7ca516745bfeafc49904b496089");
            if ({c0,c1,c2,c3} === 128'h8ea2b7ca516745bfeafc49904b496089)
                $display("[PASS] UART -> AES-256 direct path matches FIPS-197 Appendix C.3 (encrypt)");
            else
                $display("[FAIL] Encryption mismatch");
        end

        // --- Decrypt the ciphertext we just produced, round-trip check ---
        $display("Loading ciphertext back in for decrypt...");
        uart_write(7'h08, c0);
        uart_write(7'h0C, c1);
        uart_write(7'h10, c2);
        uart_write(7'h14, c3);
        uart_write(7'h00, 32'h3); // CTRL: START(bit0) | MODE(bit1)=decrypt

        $display("Polling STATUS for done over UART (decrypt)...");
        readback = 0;
        while (!readback[1]) uart_read(7'h04, readback);

        begin
            uart_read(7'h38, c0);
            uart_read(7'h3C, c1);
            uart_read(7'h40, c2);
            uart_read(7'h44, c3);
            $display("Plaintext via UART : %h%h%h%h", c0, c1, c2, c3);
            $display("Expected           : 00112233445566778899aabbccddeeff");
            if ({c0,c1,c2,c3} === 128'h00112233445566778899aabbccddeeff)
                $display("[PASS] UART -> AES-256 direct path round-trip decrypt successful");
            else
                $display("[FAIL] Decryption mismatch");
        end

        $finish;
    end

    initial begin
        #50_000_000; // Increased to 50ms to accommodate real 115200 baud speeds
        $display("WATCHDOG TIMEOUT");
        $finish;
    end
endmodule