`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 09:31:30 PM
// Design Name: 
// Module Name: InvSubs
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


module InvSubs(
    input [127:0] data,
    output [127:0] s_data_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : inv_sbox_gen
            inv_sbox u_inv_sbox (
                .data(data[i*8 +: 8]), 
                .dout(s_data_out[i*8 +: 8])
            );
        end
    endgenerate
endmodule
