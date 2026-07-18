`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 05:08:22 AM
// Design Name: 
// Module Name: lastround
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


module last_round(
    input [127:0] data_in,
    input [127:0] key_in,
    output [127:0] data_out_last
);

    wire [127:0] sub_out, shift_out;

    // Same modules as standard round, but we skip the mixcolumn call
    subbytes  s1 (data_in, sub_out);
    shiftrows s2 (sub_out, shift_out);

    assign data_out_last = shift_out ^ key_in;

endmodule