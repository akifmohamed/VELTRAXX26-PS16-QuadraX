// ============================================================================
// Module: mix_columns_shared.v
// Description: Unified MixColumns / InvMixColumns module with Galois Field
//              multiplier resource sharing (Big-Endian format).
// ============================================================================
`timescale 1ns/1ps

module mix_columns_shared (
    input  wire        enc_dec, // 0 = MixColumns (Enc), 1 = InvMixColumns (Dec)
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    mix_single_column_shared col_0 (.enc_dec(enc_dec), .col_in(state_in[127:96]), .col_out(state_out[127:96]));
    mix_single_column_shared col_1 (.enc_dec(enc_dec), .col_in(state_in[95:64]),  .col_out(state_out[95:64]));
    mix_single_column_shared col_2 (.enc_dec(enc_dec), .col_in(state_in[63:32]),  .col_out(state_out[63:32]));
    mix_single_column_shared col_3 (.enc_dec(enc_dec), .col_in(state_in[31:0]),   .col_out(state_out[31:0]));
endmodule

module mix_single_column_shared (
    input  wire        enc_dec,
    input  wire [31:0] col_in,
    output reg  [31:0] col_out
);
    wire [7:0] s0 = col_in[31:24];
    wire [7:0] s1 = col_in[23:16];
    wire [7:0] s2 = col_in[15:8];
    wire [7:0] s3 = col_in[7:0];

    function [7:0] xtime(input [7:0] b);
        xtime = b[7] ? ((b << 1) ^ 8'h1B) : (b << 1);
    endfunction

    function [7:0] mul2(input [7:0] b);
        mul2 = xtime(b);
    endfunction

    function [7:0] mul3(input [7:0] b);
        mul3 = xtime(b) ^ b;
    endfunction

    function [7:0] mul9(input [7:0] b);
        mul9 = xtime(xtime(xtime(b))) ^ b;
    endfunction

    function [7:0] mul11(input [7:0] b);
        mul11 = xtime(xtime(xtime(b)) ^ b) ^ b;
    endfunction

    function [7:0] mul13(input [7:0] b);
        mul13 = xtime(xtime(xtime(b) ^ b)) ^ b;
    endfunction

    function [7:0] mul14(input [7:0] b);
        mul14 = xtime(xtime(xtime(b) ^ b) ^ b);
    endfunction

    // Forward MixColumns
    wire [7:0] fwd_0 = mul2(s0) ^ mul3(s1) ^ s2 ^ s3;
    wire [7:0] fwd_1 = s0 ^ mul2(s1) ^ mul3(s2) ^ s3;
    wire [7:0] fwd_2 = s0 ^ s1 ^ mul2(s2) ^ mul3(s3);
    wire [7:0] fwd_3 = mul3(s0) ^ s1 ^ s2 ^ mul2(s3);

    // Inverse MixColumns
    wire [7:0] inv_0 = mul14(s0) ^ mul11(s1) ^ mul13(s2) ^ mul9(s3);
    wire [7:0] inv_1 = mul9(s0) ^ mul14(s1) ^ mul11(s2) ^ mul13(s3);
    wire [7:0] inv_2 = mul13(s0) ^ mul9(s1) ^ mul14(s2) ^ mul11(s3);
    wire [7:0] inv_3 = mul11(s0) ^ mul13(s1) ^ mul9(s2) ^ mul14(s3);

    always @* begin
        if (!enc_dec) begin
            col_out = {fwd_0, fwd_1, fwd_2, fwd_3};
        end else begin
            col_out = {inv_0, inv_1, inv_2, inv_3};
        end
    end
endmodule
