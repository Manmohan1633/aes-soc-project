`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:02:38 PM
// Design Name: 
// Module Name: inv_round
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


module inv_round(
    input [127:0] data_in,
    input [127:0] key_in,
    output [127:0] data_out
);

    wire [127:0] shift_out, sub_out, add_key_out;

    // 1. Inverse Shift Rows
    InvShiftrows a1 (data_in, shift_out);
    
    // 2. Inverse Sub Bytes (Uses 16 Inverse S-Boxes)
    InvSubs a2 (shift_out, sub_out);
    
    // 3. Add Round Key
    assign add_key_out = sub_out ^ key_in;
    
    // 4. Inverse Mix Columns
    InvMixColumns a3 (add_key_out, data_out);

endmodule
