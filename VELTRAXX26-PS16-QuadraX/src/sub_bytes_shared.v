// ============================================================================
// Module: sub_bytes_shared.v
// Description: 16 Parallel Unified S-Boxes (Big-Endian byte mapping).
// ============================================================================
`timescale 1ns/1ps

module sub_bytes_shared (
    input  wire        enc_dec, // 0 = Encrypt, 1 = Decrypt
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_sbox
            aes_sbox_shared u_sbox (
                .enc_dec(enc_dec),
                .in_byte(state_in[(15-i)*8 +: 8]),
                .out_byte(state_out[(15-i)*8 +: 8])
            );
        end
    endgenerate
endmodule
