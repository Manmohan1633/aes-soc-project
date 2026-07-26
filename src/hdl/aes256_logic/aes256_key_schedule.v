`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2026 08:40:18 AM
// Design Name: 
// Module Name: aes256_key_schedule
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


module aes256_key_schedule(
    input  clk,
    input  rst,
    input  load,                 // pulse: latch master_key and begin expansion
    input  [255:0] master_key,
    output reg busy,             // expansion in progress
    output reg ready,            // all 15 round keys valid
    input  [3:0] round_idx,      // 0..14
    output reg [127:0] round_key // key_ram[round_idx], combinational read
);
    reg [127:0] key_ram [0:14];
    reg [3:0] r;                 // round currently being computed (2..14)
    
    // Words from the two previous round keys needed for this step
    wire [31:0] a2 = key_ram[r-2][127:96];
    wire [31:0] b2 = key_ram[r-2][95:64];
    wire [31:0] c2 = key_ram[r-2][63:32];
    wire [31:0] d2 = key_ram[r-2][31:0];
    wire [31:0] d1 = key_ram[r-1][31:0];
    
    // RotWord(d1) then SubWord -- used when r is even
    wire [31:0] rot_d1 = {d1[23:0], d1[31:24]};
    wire [31:0] sub_rot_d1;
    sbox rs0(rot_d1[31:24], sub_rot_d1[31:24]);
    sbox rs1(rot_d1[23:16], sub_rot_d1[23:16]);
    sbox rs2(rot_d1[15:8],  sub_rot_d1[15:8]);
    sbox rs3(rot_d1[7:0],   sub_rot_d1[7:0]);
    
    // SubWord(d1) only (no rotate) -- used when r is odd (the Nk=8 extra step)
    wire [31:0] sub_d1;
    sbox ss0(d1[31:24], sub_d1[31:24]);
    sbox ss1(d1[23:16], sub_d1[23:16]);
    sbox ss2(d1[15:8],  sub_d1[15:8]);
    sbox ss3(d1[7:0],   sub_d1[7:0]);
    
    // Rcon[r/2] -- only consumed on the even-r branch
    wire [7:0] rcon_val;
    aes_rcon_iter rcon_inst({1'b0, r[3:1]}, rcon_val); // r>>1 == r/2
    wire [31:0] temp0 = r[0] ? sub_d1 : (sub_rot_d1 ^ {rcon_val, 24'b0});
    
    wire [31:0] w0 = a2 ^ temp0;
    wire [31:0] w1 = b2 ^ w0;
    wire [31:0] w2 = c2 ^ w1;
    wire [31:0] w3 = d2 ^ w2;
    
    always @(*) round_key = key_ram[round_idx];
    
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            busy  <= 1'b0;
            ready <= 1'b0;
            r     <= 4'd0;
            for (i = 0; i < 15; i = i + 1) key_ram[i] <= 128'd0;
        end else if (load) begin
            key_ram[0] <= master_key[255:128];
            key_ram[1] <= master_key[127:0];
            r     <= 4'd2;
            busy  <= 1'b1;
            ready <= 1'b0;
        end else if (busy) begin
            key_ram[r] <= {w0, w1, w2, w3};
            if (r == 4'd14) begin
                busy  <= 1'b0;
                ready <= 1'b1;
            end else begin
                r <= r + 4'd1;
            end
        end
    end
endmodule
