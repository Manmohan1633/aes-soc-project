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

    // Interface to the shared key schedule (aes256_key_schedule.v rev3)
    output [3:0] round_idx,
    input  [127:0] round_key
);

    localparam ST_IDLE     = 4'd0,
               ST_INIT_ADDR= 4'd1,
               ST_INIT_XOR = 4'd2,
               ST_SUB_ADDR = 4'd3,
               ST_SUB_WRITE= 4'd4,
               ST_SUBCOPY  = 4'd5,
               ST_MIXCOL   = 4'd6,
               ST_MIXCOPY  = 4'd7;

    reg [3:0]   stage;
    reg         busy;
    reg [127:0] state, state_next;
    reg [3:0]   round_num;  // 1..14, which of the 14 rounds we're on (mode-independent labeling)
    reg [3:0]   bi;         // byte index 0..15 during ST_SUB_ADDR/ST_SUB_WRITE
    reg [1:0]   col_idx;    // column index 0..3 during ST_MIXCOL

    wire is_final = (round_num == 4'd14);

    wire [3:0] rk_idx_loop = mode ? (4'd14 - round_num) : round_num;
    wire [3:0] init_rk_idx = mode ? 4'd14 : 4'd0;

    assign round_idx = (stage == ST_INIT_ADDR || stage == ST_INIT_XOR) ? init_rk_idx : rk_idx_loop;

    //------------------------------------------------------------------
    // SubBytes/InvSubBytes + ShiftRows/InvShiftRows (folded into address).
    // src_byte is presented during ST_SUB_ADDR; sub_byte is valid during
    // the following ST_SUB_WRITE cycle (sbox/inv_sbox 1-cycle latency).
    // 'bi' does not change between these two states, so dest_bi/row/col
    // below are still correct during ST_SUB_WRITE.
    //------------------------------------------------------------------
    wire [7:0] src_byte = state[(15 - bi)*8 +: 8];

    wire [7:0] fwd_sub, inv_sub;
    sbox     sb_fwd(.clk(clk), .data(src_byte), .dout(fwd_sub));
    inv_sbox sb_inv(.clk(clk), .data(src_byte), .dout(inv_sub));
    wire [7:0] sub_byte = mode ? inv_sub : fwd_sub;

    wire [1:0] row = bi[1:0];
    wire [1:0] col = bi[3:2];
    wire [1:0] dest_col = mode ? (col + row) : (col - row);
    wire [3:0] dest_bi  = {dest_col, row};

    wire [7:0] rk_byte_subshift = round_key[(15 - dest_bi)*8 +: 8];
    wire [7:0] subshift_wr_val  = is_final ? (sub_byte ^ rk_byte_subshift) : sub_byte;

    //------------------------------------------------------------------
    // MixColumns/InvMixColumns -- unchanged from rev1. gf_mixcol_shared has
    // no memory, so it's still single-cycle; round_key has been stable
    // since well before ST_MIXCOL is reached.
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
                    if (start && key_ready && !busy) begin
                        busy      <= 1'b1;
                        done      <= 1'b0;
                        round_num <= 4'd1;
                        stage     <= ST_INIT_ADDR;
                    end
                end

                ST_INIT_ADDR: begin
                    stage <= ST_INIT_XOR; // round_idx=init_rk_idx presented this cycle
                end
                ST_INIT_XOR: begin
                    state <= data_in ^ round_key; // now valid: K0 (enc) or K14 (dec)
                    bi    <= 4'd0;
                    stage <= ST_SUB_ADDR;
                end

                ST_SUB_ADDR: begin
                    stage <= ST_SUB_WRITE; // src_byte presented this cycle
                end
                ST_SUB_WRITE: begin
                    state_next[(15 - dest_bi)*8 +: 8] <= subshift_wr_val;
                    if (bi == 4'd15) begin
                        stage <= ST_SUBCOPY;
                    end else begin
                        bi    <= bi + 4'd1;
                        stage <= ST_SUB_ADDR;
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
                    stage <= ST_SUB_ADDR;
                end

                default: stage <= ST_IDLE;
            endcase
        end
    end
endmodule
