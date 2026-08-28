// ============================================================================
// Module: shift_rows_shared.v
// Description: Unified ShiftRows / InvShiftRows module with big-endian mapping.
// ============================================================================
`timescale 1ns/1ps

module shift_rows_shared (
    input  wire        enc_dec, // 0 = ShiftRows (Enc), 1 = InvShiftRows (Dec)
    input  wire [127:0] state_in,
    output reg  [127:0] state_out
);
    wire [7:0] b0  = state_in[127:120];
    wire [7:0] b1  = state_in[119:112];
    wire [7:0] b2  = state_in[111:104];
    wire [7:0] b3  = state_in[103:96];

    wire [7:0] b4  = state_in[95:88];
    wire [7:0] b5  = state_in[87:80];
    wire [7:0] b6  = state_in[79:72];
    wire [7:0] b7  = state_in[71:64];

    wire [7:0] b8  = state_in[63:56];
    wire [7:0] b9  = state_in[55:48];
    wire [7:0] b10 = state_in[47:40];
    wire [7:0] b11 = state_in[39:32];

    wire [7:0] b12 = state_in[31:24];
    wire [7:0] b13 = state_in[23:16];
    wire [7:0] b14 = state_in[15:8];
    wire [7:0] b15 = state_in[7:0];

    always @* begin
        if (!enc_dec) begin
            // Forward ShiftRows
            // Row 0
            state_out[127:120] = b0;
            state_out[95:88]   = b4;
            state_out[63:56]   = b8;
            state_out[31:24]   = b12;

            // Row 1 (shift left 1)
            state_out[119:112] = b5;
            state_out[87:80]   = b9;
            state_out[55:48]   = b13;
            state_out[23:16]   = b1;

            // Row 2 (shift left 2)
            state_out[111:104] = b10;
            state_out[79:72]   = b14;
            state_out[47:40]   = b2;
            state_out[15:8]    = b6;

            // Row 3 (shift left 3)
            state_out[103:96]  = b15;
            state_out[71:64]   = b3;
            state_out[39:32]   = b7;
            state_out[7:0]     = b11;
        end else begin
            // Inverse ShiftRows
            // Row 0
            state_out[127:120] = b0;
            state_out[95:88]   = b4;
            state_out[63:56]   = b8;
            state_out[31:24]   = b12;

            // Row 1 (shift right 1)
            state_out[119:112] = b13;
            state_out[87:80]   = b1;
            state_out[55:48]   = b5;
            state_out[23:16]   = b9;

            // Row 2 (shift right 2)
            state_out[111:104] = b10;
            state_out[79:72]   = b14;
            state_out[47:40]   = b2;
            state_out[15:8]    = b6;

            // Row 3 (shift right 3)
            state_out[103:96]  = b7;
            state_out[71:64]   = b11;
            state_out[39:32]   = b15;
            state_out[7:0]     = b3;
        end
    end
endmodule
