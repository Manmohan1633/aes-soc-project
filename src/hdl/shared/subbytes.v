`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Manmohan Singh
// 
// Create Date: 05/30/2026 10:15:12 AM
// Design Name: 
// Module Name: subbytes
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


module subbytes(
    input [127:0] data,
    output [127:0] s_data_out
);

    // Using continuous assignments (assign) for combinatorial logic
    // is cleaner and more efficient than using a clock-based register.
    
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sbox_gen
            sbox u_sbox (
                .data(data[i*8 +: 8]), 
                .dout(s_data_out[i*8 +: 8])
            );
        end
    endgenerate

endmodule
