`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:33:47 PM
// Design Name: 
// Module Name: InvMixColumns
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


module InvMixColumns(
    input [127:0] data_in,
    output [127:0] data_out
);
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : col_loop
            inv_column_mix c_mix (
                .col_in(data_in[i*32 + 31 : i*32]),
                .col_out(data_out[i*32 + 31 : i*32])
            );
        end
    endgenerate
endmodule

module inv_column_mix(input [31:0] col_in, output [31:0] col_out);
    wire [7:0] a = col_in[31:24];
    wire [7:0] b = col_in[23:16];
    wire [7:0] c = col_in[15:8];
    wire [7:0] d = col_in[7:0];
    
    wire [7:0] m0e_a, m0b_a, m0d_a, m09_a;
    wire [7:0] m0e_b, m0b_b, m0d_b, m09_b;
    wire [7:0] m0e_c, m0b_c, m0d_c, m09_c;
    wire [7:0] m0e_d, m0b_d, m0d_d, m09_d;
    
    // Instantiate area-optimized multipliers
    gf_mul m_a(a, m0e_a, m0b_a, m0d_a, m09_a);
    gf_mul m_b(b, m0e_b, m0b_b, m0d_b, m09_b);
    gf_mul m_c(c, m0e_c, m0b_c, m0d_c, m09_c);
    gf_mul m_d(d, m0e_d, m0b_d, m0d_d, m09_d);
    
    assign col_out[31:24] = m0e_a ^ m0b_b ^ m0d_c ^ m09_d;
    assign col_out[23:16] = m09_a ^ m0e_b ^ m0b_c ^ m0d_d;
    assign col_out[15:8]  = m0d_a ^ m09_b ^ m0e_c ^ m0b_d;
    assign col_out[7:0]   = m0b_a ^ m0d_b ^ m09_c ^ m0e_d;
endmodule

// Helper module that calculates *9, *11, *13, *14 while sharing logic paths
module gf_mul(
    input [7:0] x,
    output [7:0] out_0e, // x * 14
    output [7:0] out_0b, // x * 11
    output [7:0] out_0d, // x * 13
    output [7:0] out_09  // x * 9
);
    wire [7:0] x2, x4, x8;
    
    // Multiply by 2, 4, 8 using Galois Field logic
    assign x2 = {x[6:0], 1'b0} ^ (8'h1b & {8{x[7]}});
    assign x4 = {x2[6:0], 1'b0} ^ (8'h1b & {8{x2[7]}});
    assign x8 = {x4[6:0], 1'b0} ^ (8'h1b & {8{x4[7]}});
    
    // Construct final values
    assign out_09 = x8 ^ x;             // 9 = 8 + 1
    assign out_0b = x8 ^ x2 ^ x;        // 11 = 8 + 2 + 1
    assign out_0d = x8 ^ x4 ^ x;        // 13 = 8 + 4 + 1
    assign out_0e = x8 ^ x4 ^ x2;       // 14 = 8 + 4 + 2
endmodule
