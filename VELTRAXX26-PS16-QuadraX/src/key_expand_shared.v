// ============================================================================
// Module: key_expand_shared.v
// Description: AES-128 Key Expansion Engine supporting Forward & Reverse
//              round key selection with 1-Cycle Atomic Zeroization under fault.
// ============================================================================
`timescale 1ns/1ps

module key_expand_shared (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         load_key,
    input  wire [127:0] master_key,
    input  wire [3:0]   round_num,
    input  wire         enc_dec,       // 0 = Encrypt, 1 = Decrypt
    input  wire         zeroize_all,   // Atomic 1-cycle key wipeout trigger
    output wire [127:0] current_round_key
);

    reg [127:0] rk0, rk1, rk2, rk3, rk4, rk5, rk6, rk7, rk8, rk9, rk10;

    wire [127:0] next_k1, next_k2, next_k3, next_k4, next_k5, next_k6, next_k7, next_k8, next_k9, next_k10;

    key_expand_step u_step1  (.prev_key(master_key), .rcon_val(8'h01), .next_key(next_k1));
    key_expand_step u_step2  (.prev_key(next_k1),    .rcon_val(8'h02), .next_key(next_k2));
    key_expand_step u_step3  (.prev_key(next_k2),    .rcon_val(8'h04), .next_key(next_k3));
    key_expand_step u_step4  (.prev_key(next_k3),    .rcon_val(8'h08), .next_key(next_k4));
    key_expand_step u_step5  (.prev_key(next_k4),    .rcon_val(8'h10), .next_key(next_k5));
    key_expand_step u_step6  (.prev_key(next_k5),    .rcon_val(8'h20), .next_key(next_k6));
    key_expand_step u_step7  (.prev_key(next_k6),    .rcon_val(8'h40), .next_key(next_k7));
    key_expand_step u_step8  (.prev_key(next_k7),    .rcon_val(8'h80), .next_key(next_k8));
    key_expand_step u_step9  (.prev_key(next_k8),    .rcon_val(8'h1B), .next_key(next_k9));
    key_expand_step u_step10 (.prev_key(next_k9),    .rcon_val(8'h36), .next_key(next_k10));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rk0  <= 128'd0; rk1  <= 128'd0; rk2  <= 128'd0; rk3  <= 128'd0;
            rk4  <= 128'd0; rk5  <= 128'd0; rk6  <= 128'd0; rk7  <= 128'd0;
            rk8  <= 128'd0; rk9  <= 128'd0; rk10 <= 128'd0;
        end else if (zeroize_all) begin
            rk0  <= 128'd0; rk1  <= 128'd0; rk2  <= 128'd0; rk3  <= 128'd0;
            rk4  <= 128'd0; rk5  <= 128'd0; rk6  <= 128'd0; rk7  <= 128'd0;
            rk8  <= 128'd0; rk9  <= 128'd0; rk10 <= 128'd0;
        end else if (load_key) begin
            rk0  <= master_key;
            rk1  <= next_k1;
            rk2  <= next_k2;
            rk3  <= next_k3;
            rk4  <= next_k4;
            rk5  <= next_k5;
            rk6  <= next_k6;
            rk7  <= next_k7;
            rk8  <= next_k8;
            rk9  <= next_k9;
            rk10 <= next_k10;
        end
    end

    wire [3:0] key_idx = enc_dec ? (4'd10 - round_num) : round_num;

    // Use combinational next_k values directly or latched rk values
    reg [127:0] sel_rk;
    always @* begin
        case (key_idx)
            4'd0:  sel_rk = master_key;
            4'd1:  sel_rk = next_k1;
            4'd2:  sel_rk = next_k2;
            4'd3:  sel_rk = next_k3;
            4'd4:  sel_rk = next_k4;
            4'd5:  sel_rk = next_k5;
            4'd6:  sel_rk = next_k6;
            4'd7:  sel_rk = next_k7;
            4'd8:  sel_rk = next_k8;
            4'd9:  sel_rk = next_k9;
            4'd10: sel_rk = next_k10;
            default: sel_rk = 128'd0;
        endcase
    end

    assign current_round_key = zeroize_all ? 128'd0 : sel_rk;

endmodule

// Helper 1-round key expansion step
module key_expand_step (
    input  wire [127:0] prev_key,
    input  wire [7:0]   rcon_val,
    output wire [127:0] next_key
);
    wire [31:0] w0 = prev_key[127:96];
    wire [31:0] w1 = prev_key[95:64];
    wire [31:0] w2 = prev_key[63:32];
    wire [31:0] w3 = prev_key[31:0];

    // RotWord: [B3, B2, B1, B0] -> [B2, B1, B0, B3]
    wire [31:0] sub_w;
    aes_sbox_shared sb0 (.enc_dec(1'b0), .in_byte(w3[23:16]), .out_byte(sub_w[31:24]));
    aes_sbox_shared sb1 (.enc_dec(1'b0), .in_byte(w3[15:8]),  .out_byte(sub_w[23:16]));
    aes_sbox_shared sb2 (.enc_dec(1'b0), .in_byte(w3[7:0]),   .out_byte(sub_w[15:8]));
    aes_sbox_shared sb3 (.enc_dec(1'b0), .in_byte(w3[31:24]), .out_byte(sub_w[7:0]));

    wire [31:0] w4 = w0 ^ sub_w ^ {rcon_val, 24'h000000};
    wire [31:0] w5 = w1 ^ w4;
    wire [31:0] w6 = w2 ^ w5;
    wire [31:0] w7 = w3 ^ w6;

    assign next_key = {w4, w5, w6, w7};
endmodule
