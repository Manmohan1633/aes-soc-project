`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 05:09:26 AM
// Design Name: 
// Module Name: round
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


module round(
    input [127:0] data_in,
    input [127:0] key_in,
    output [127:0] data_out
);

    wire [127:0] sub_out, shift_out, mix_out;

    // Use these modules as purely combinatorial blocks
    subbytes  a1 (data_in, sub_out);
    shiftrows a2 (sub_out, shift_out);
    mixcolumn a3 (shift_out, mix_out);

    assign data_out = mix_out ^ key_in;

endmodule
