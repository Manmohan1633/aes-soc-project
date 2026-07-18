`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 05:08:51 AM
// Design Name: 
// Module Name: mixcolumn
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


module mixcolumn(
    input [127:0] data_in,
    output [127:0] data_out
);

    // Generate 4 columns (each 32 bits)
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : col_loop
            column_mix c_mix (
                .col_in(data_in[i*32 + 31 : i*32]),
                .col_out(data_out[i*32 + 31 : i*32])
            );
        end
    endgenerate
endmodule

module column_mix(input [31:0] col_in, output [31:0] col_out);
    wire [7:0] a = col_in[31:24];
    wire [7:0] b = col_in[23:16];
    wire [7:0] c = col_in[15:8];
    wire [7:0] d = col_in[7:0];
    
    wire [7:0] m2a, m3b, m2b, m3c, m2c, m3d, m2d, m3a;
    
    // Instantiate multipliers
    mul_2 m2_a(a, m2a); mul_3 m3_a(a, m3a);
    mul_2 m2_b(b, m2b); mul_3 m3_b(b, m3b);
    mul_2 m2_c(c, m2c); mul_3 m3_c(c, m3c);
    mul_2 m2_d(d, m2d); mul_3 m3_d(d, m3d);
    
    // Matrix multiplication logic
    assign col_out[31:24] = m2a ^ m3b ^ c ^ d;
    assign col_out[23:16] = a ^ m2b ^ m3c ^ d;
    assign col_out[15:8]  = a ^ b ^ m2c ^ m3d;
    assign col_out[7:0]   = m3a ^ b ^ c ^ m2d;
endmodule

// --- DEFINITIONS FOR MUL_2 AND MUL_3 ---
// These were missing from your file, causing the Vivado error.

module mul_2(input [7:0] data_in, output [7:0] data_out);
    assign data_out = {data_in[6:0], 1'b0} ^ (8'h1b & {8{data_in[7]}});
endmodule

module mul_3(input [7:0] data_in, output [7:0] data_out);
    wire [7:0] tmp;
    mul_2 m1(data_in, tmp);
    assign data_out = tmp ^ data_in;
endmodule