`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:04:36 PM
// Design Name: 
// Module Name: inv_lastround
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


module inv_lastround(
    input [127:0] data_in,
    input [127:0] key_in,
    output [127:0] data_out_last
);

    wire [127:0] shift_out, sub_out;

    // 1. Inverse Shift Rows
    InvShiftrows s1 (data_in, shift_out);
    
    // 2. Inverse Sub Bytes
    InvSubs s2 (shift_out, sub_out);

    // 3. Add Round Key
    assign data_out_last = sub_out ^ key_in;

endmodule
