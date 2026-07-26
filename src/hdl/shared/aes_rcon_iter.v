`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/19/2026 01:37:03 AM
// Design Name: 
// Module Name: aes_rcon_iter
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

module aes_rcon_iter(
    input [3:0] round_idx,
    output reg [7:0] rcon_val
);

    always @(*) begin
        case (round_idx)
            4'd1:  rcon_val = 8'h01;
            4'd2:  rcon_val = 8'h02;
            4'd3:  rcon_val = 8'h04;
            4'd4:  rcon_val = 8'h08;
            4'd5:  rcon_val = 8'h10;
            4'd6:  rcon_val = 8'h20;
            4'd7:  rcon_val = 8'h40;
            4'd8:  rcon_val = 8'h80;
            4'd9:  rcon_val = 8'h1b;
            4'd10: rcon_val = 8'h36;
            default: rcon_val = 8'h00; // Default case prevents latches
        endcase
    end

endmodule

