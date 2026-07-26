`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2026 01:54:50 AM
// Design Name: 
// Module Name: gf_mixcol_shared
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


module gf_mixcol_shared(
    input        mode,   // 0 = forward (MixColumns), 1 = inverse (InvMixColumns)
    input  [7:0] a0, a1, a2, a3,
    output [7:0] b0, b1, b2, b3
);
    function [7:0] xtime;
        input [7:0] x;
        xtime = {x[6:0], 1'b0} ^ (8'h1b & {8{x[7]}});
    endfunction

    genvar i;
    wire [7:0] a   [0:3];
    wire [7:0] x2  [0:3];
    wire [7:0] x4  [0:3];
    wire [7:0] x8  [0:3];
    wire [7:0] m02 [0:3]; // *2  (forward)
    wire [7:0] m03 [0:3]; // *3  (forward)
    wire [7:0] m09 [0:3]; // *9  (inverse)
    wire [7:0] m0b [0:3]; // *11 (inverse)
    wire [7:0] m0d [0:3]; // *13 (inverse)
    wire [7:0] m0e [0:3]; // *14 (inverse)

    assign a[0] = a0; assign a[1] = a1; assign a[2] = a2; assign a[3] = a3;

    generate
        for (i = 0; i < 4; i = i + 1) begin : gf_terms
            assign x2[i]  = xtime(a[i]);
            assign x4[i]  = xtime(x2[i]);
            assign x8[i]  = xtime(x4[i]);
            assign m02[i] = x2[i];
            assign m03[i] = x2[i] ^ a[i];
            assign m09[i] = x8[i] ^ a[i];
            assign m0b[i] = x8[i] ^ x2[i] ^ a[i];
            assign m0d[i] = x8[i] ^ x4[i] ^ a[i];
            assign m0e[i] = x8[i] ^ x4[i] ^ x2[i];
        end
    endgenerate

    // Forward MixColumns (matrix: 2 3 1 1 / 1 2 3 1 / 1 1 2 3 / 3 1 1 2)
    wire [7:0] fwd_b0 = m02[0] ^ m03[1] ^ a[2]   ^ a[3];
    wire [7:0] fwd_b1 = a[0]   ^ m02[1] ^ m03[2] ^ a[3];
    wire [7:0] fwd_b2 = a[0]   ^ a[1]   ^ m02[2] ^ m03[3];
    wire [7:0] fwd_b3 = m03[0] ^ a[1]   ^ a[2]   ^ m02[3];

    // Inverse MixColumns (matrix: 14 11 13 9 / 9 14 11 13 / 13 9 14 11 / 11 13 9 14)
    wire [7:0] inv_b0 = m0e[0] ^ m0b[1] ^ m0d[2] ^ m09[3];
    wire [7:0] inv_b1 = m09[0] ^ m0e[1] ^ m0b[2] ^ m0d[3];
    wire [7:0] inv_b2 = m0d[0] ^ m09[1] ^ m0e[2] ^ m0b[3];
    wire [7:0] inv_b3 = m0b[0] ^ m0d[1] ^ m09[2] ^ m0e[3];

    assign b0 = mode ? inv_b0 : fwd_b0;
    assign b1 = mode ? inv_b1 : fwd_b1;
    assign b2 = mode ? inv_b2 : fwd_b2;
    assign b3 = mode ? inv_b3 : fwd_b3;

endmodule
