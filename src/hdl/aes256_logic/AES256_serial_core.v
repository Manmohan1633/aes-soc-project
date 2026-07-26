`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2026 02:19:39 AM
// Design Name: 
// Module Name: AES256_serial_core
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


module AES256_serial_core(
    input  clk,
    input  rst,
    input  start,
    input  key_ready,
    input  mode,                  // 0 = Encrypt, 1 = Decrypt
    input  [127:0] data_in,
    output reg [127:0] data_out,
    output reg done,

    // Interface to the shared key schedule (aes256_key_schedule.v rev2)
    output [3:0] round_idx,
    input  [127:0] round_key
);

    localparam ST_IDLE    = 3'd0,
               ST_INIT    = 3'd1,
               ST_SUBSHIFT= 3'd2,
               ST_SUBCOPY = 3'd3,
               ST_MIXCOL  = 3'd4,
               ST_MIXCOPY = 3'd5;

    reg [2:0]   stage;
    reg         busy;
    reg [127:0] state, state_next;
    reg [3:0]   round_num;  // 1..14, which of the 14 rounds we're on (mode-independent labeling)
    reg [3:0]   bi;         // byte index 0..15 during ST_SUBSHIFT
    reg [1:0]   col_idx;    // column index 0..3 during ST_MIXCOL

    wire is_final = (round_num == 4'd14);

    // Same rk_idx formula works for both the 13 loop rounds AND the final
    // round in both directions -- see the derivation notes in chat: for
    // mode=1, rk_idx = 14-round_num gives 13,12,...,1 then 0 (correct: K13
    // downto K1 for the loop, K0 for the final round); for mode=0,
    // rk_idx = round_num gives 1,2,...,13 then 14 directly.
    wire [3:0] rk_idx_loop = mode ? (4'd14 - round_num) : round_num;
    wire [3:0] init_rk_idx = mode ? 4'd14 : 4'd0;      // decrypt starts at K14, encrypt at K0

    assign round_idx = (stage == ST_INIT) ? init_rk_idx : rk_idx_loop;

    //------------------------------------------------------------------
    // ST_SUBSHIFT: SubBytes/InvSubBytes + ShiftRows/InvShiftRows folded
    // into the write-back address. For the final round, AddRoundKey is
    // also folded in here (no MixColumns that round).
    //------------------------------------------------------------------
    wire [7:0] src_byte = state[(15 - bi)*8 +: 8];

    wire [7:0] fwd_sub, inv_sub;
    sbox     sb_fwd(src_byte, fwd_sub);
    inv_sbox sb_inv(src_byte, inv_sub);
    wire [7:0] sub_byte = mode ? inv_sub : fwd_sub;

    wire [1:0] row = bi[1:0];
    wire [1:0] col = bi[3:2];
    // Forward ShiftRows shifts row r left by r; inverse shifts right by r.
    // 2-bit wires wrap mod 4 automatically on +/-, which is exactly what
    // the row/column arithmetic needs here.
    wire [1:0] dest_col = mode ? (col + row) : (col - row);
    wire [3:0] dest_bi  = {dest_col, row};

    wire [7:0] rk_byte_subshift = round_key[(15 - dest_bi)*8 +: 8];
    wire [7:0] subshift_wr_val  = is_final ? (sub_byte ^ rk_byte_subshift) : sub_byte;

    //------------------------------------------------------------------
    // ST_MIXCOL: MixColumns/InvMixColumns, one column per cycle, with
    // AddRoundKey folded into the write-back (every non-final round goes
    // through this stage, so this is where the round's key XOR happens).
    //------------------------------------------------------------------
    wire [7:0] c_a0 = state[(15 - {col_idx, 2'd0})*8 +: 8];
    wire [7:0] c_a1 = state[(15 - {col_idx, 2'd1})*8 +: 8];
    wire [7:0] c_a2 = state[(15 - {col_idx, 2'd2})*8 +: 8];
    wire [7:0] c_a3 = state[(15 - {col_idx, 2'd3})*8 +: 8];

    wire [7:0] mb0, mb1, mb2, mb3;
    gf_mixcol_shared mixcol (
        .mode(mode),
        .a0(c_a0), .a1(c_a1), .a2(c_a2), .a3(c_a3),
        .b0(mb0), .b1(mb1), .b2(mb2), .b3(mb3)
    );

    wire [7:0] rk0 = round_key[(15 - {col_idx, 2'd0})*8 +: 8];
    wire [7:0] rk1 = round_key[(15 - {col_idx, 2'd1})*8 +: 8];
    wire [7:0] rk2 = round_key[(15 - {col_idx, 2'd2})*8 +: 8];
    wire [7:0] rk3 = round_key[(15 - {col_idx, 2'd3})*8 +: 8];

    //------------------------------------------------------------------
    // FSM
    //------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            stage      <= ST_IDLE;
            busy       <= 1'b0;
            done       <= 1'b0;
            data_out   <= 128'd0;
            state      <= 128'd0;
            state_next <= 128'd0;
            round_num  <= 4'd0;
            bi         <= 4'd0;
            col_idx    <= 2'd0;
        end else begin
            case (stage)
                ST_IDLE: begin
                    done <= 1'b0;
                    if (start && key_ready && !busy) begin
                        busy      <= 1'b1;
                        round_num <= 4'd1;
                        stage     <= ST_INIT;
                    end
                end

                ST_INIT: begin
                    state <= data_in ^ round_key; // round_key = K0 (enc) or K14 (dec) here
                    bi    <= 4'd0;
                    stage <= ST_SUBSHIFT;
                end

                ST_SUBSHIFT: begin
                    state_next[(15 - dest_bi)*8 +: 8] <= subshift_wr_val;
                    if (bi == 4'd15) begin
                        stage <= ST_SUBCOPY;
                    end else begin
                        bi <= bi + 4'd1;
                    end
                end

                ST_SUBCOPY: begin
                    state <= state_next;
                    if (is_final) begin
                        data_out <= state_next; // AddRoundKey already folded in above
                        done     <= 1'b1;
                        busy     <= 1'b0;
                        stage    <= ST_IDLE;
                    end else begin
                        col_idx <= 2'd0;
                        stage   <= ST_MIXCOL;
                    end
                end

                ST_MIXCOL: begin
                    state_next[(15 - {col_idx, 2'd3})*8 +: 32] <=
                        {mb0 ^ rk0, mb1 ^ rk1, mb2 ^ rk2, mb3 ^ rk3};
                    if (col_idx == 2'd3) begin
                        stage <= ST_MIXCOPY;
                    end else begin
                        col_idx <= col_idx + 2'd1;
                    end
                end

                ST_MIXCOPY: begin
                    state <= state_next;
                    round_num <= round_num + 4'd1; // 13 -> 14 lands on the final round
                    bi    <= 4'd0;
                    stage <= ST_SUBSHIFT;
                end

                default: stage <= ST_IDLE;
            endcase
        end
    end
endmodule
