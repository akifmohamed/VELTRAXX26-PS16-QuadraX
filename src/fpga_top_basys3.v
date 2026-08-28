`timescale 1ns/1ps

module fpga_top_basys3 (
    input  wire        clk,        // 100 MHz Oscillator (W5)
    input  wire        btnC,       // Center Button (U18) -> System Reset
    input  wire        btnU,       // Up Button (T18)     -> Trigger NIST Encryption (0x97)
    input  wire        btnD,       // Down Button (U17)   -> Trigger NIST Decryption (0x2A)
    input  wire        btnR,       // Right Button (T17)  -> Trigger Active Tamper / Key Wipeout
    output wire        led_busy,   // LD13 (N3)           -> Busy Indicator (Yellow)
    output wire        led_fault,  // LD14 (P1)           -> Security Fault / Tamper (Red)
    output wire        led_done,   // LD15 (L1)           -> Operation Complete (Green)
    output wire [7:0]  led_data    // LD0..LD7            -> 8-bit Output Data (0x97 / 0x2A / 0x00)
);

    reg clk50 = 1'b0;
    always @(posedge clk) clk50 <= ~clk50;

    reg [3:0] por_cnt = 4'd0;
    always @(posedge clk50) if (!por_cnt[3]) por_cnt <= por_cnt + 1'b1;

    reg [2:0] btnC_sync, btnU_sync, btnD_sync, btnR_sync;
    always @(posedge clk50) begin
        btnC_sync <= {btnC_sync[1:0], btnC};
        btnU_sync <= {btnU_sync[1:0], btnU};
        btnD_sync <= {btnD_sync[1:0], btnD};
        btnR_sync <= {btnR_sync[1:0], btnR};
    end

    wire rst_n = por_cnt[3] && (!btnC_sync[2]);
    wire trig_enc   = btnU_sync[1] && (!btnU_sync[2]);
    wire trig_dec   = btnD_sync[1] && (!btnD_sync[2]);
    wire trig_fault = btnR_sync[2];

    reg [7:0]  s_axi_awaddr;
    reg        s_axi_awvalid;
    wire       s_axi_awready;
    reg [31:0] s_axi_wdata;
    reg        s_axi_wvalid;
    wire       s_axi_wready;
    wire       s_axi_bvalid;
    reg        s_axi_bready;
    reg [7:0]  s_axi_araddr;
    reg        s_axi_arvalid;
    wire       s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire       s_axi_rvalid;
    reg        s_axi_rready;
    wire       security_irq;
    wire       soc_busy, soc_done, soc_fault;
    wire [7:0] soc_data;

    aes_soc_top u_soc_top (
        .aclk(clk50), .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(4'b1111),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .security_irq(security_irq), .led_busy(soc_busy),
        .led_done(soc_done), .led_fault(soc_fault), .led_data(soc_data)
    );

    reg [4:0] fsm_state;
    reg [7:0] latched_leds;
    reg       latched_done, latched_fault, is_dec_op;

    localparam S_IDLE=5'd0, S_WR_KEY0=5'd1, S_WR_KEY1=5'd2, S_WR_KEY2=5'd3, S_WR_KEY3=5'd4;
    localparam S_WR_DIN0=5'd5, S_WR_DIN1=5'd6, S_WR_DIN2=5'd7, S_WR_DIN3=5'd8, S_WR_CTRL=5'd9;
    localparam S_WAIT_CORE=5'd10, S_RD_DOUT0=5'd11, S_DISPLAY=5'd12;

    always @(posedge clk50 or negedge rst_n) begin
        if (!rst_n) begin
            fsm_state <= S_IDLE;
            s_axi_awvalid <= 1'b0; s_axi_wvalid <= 1'b0; s_axi_bready <= 1'b0;
            s_axi_arvalid <= 1'b0; s_axi_rready <= 1'b0;
            latched_leds <= 8'h00; latched_done <= 1'b0; latched_fault <= 1'b0;
            is_dec_op <= 1'b0;
        end else if (trig_fault) begin
            latched_leds <= 8'h00; latched_done <= 1'b0; latched_fault <= 1'b1;
            fsm_state <= S_IDLE;
        end else begin
            case (fsm_state)
                S_IDLE: begin
                    if (trig_enc || trig_dec) begin
                        is_dec_op <= trig_dec; latched_done <= 1'b0; latched_fault <= 1'b0;
                        s_axi_awaddr <= 8'h08; s_axi_wdata <= 32'h09CF4F3C;
                        s_axi_awvalid <= 1'b1; s_axi_wvalid <= 1'b1; s_axi_bready <= 1'b1;
                        fsm_state <= S_WR_KEY0;
                    end
                end
                S_WR_KEY0: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h0C; s_axi_wdata <= 32'hABF71588; fsm_state <= S_WR_KEY1; end
                S_WR_KEY1: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h10; s_axi_wdata <= 32'h28AED2A6; fsm_state <= S_WR_KEY2; end
                S_WR_KEY2: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h14; s_axi_wdata <= 32'h2B7E1516; fsm_state <= S_WR_KEY3; end
                S_WR_KEY3: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h18; s_axi_wdata <= is_dec_op ? 32'h2466EF97 : 32'h7393172A; fsm_state <= S_WR_DIN0; end
                S_WR_DIN0: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h1C; s_axi_wdata <= is_dec_op ? 32'hA89ECAF3 : 32'hE93D7E11; fsm_state <= S_WR_DIN1; end
                S_WR_DIN1: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h20; s_axi_wdata <= is_dec_op ? 32'h0D7A3660 : 32'h2E409F96; fsm_state <= S_WR_DIN2; end
                S_WR_DIN2: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h24; s_axi_wdata <= is_dec_op ? 32'h3AD77BB4 : 32'h6BC1BEE2; fsm_state <= S_WR_DIN3; end
                S_WR_DIN3: if (s_axi_bvalid) begin s_axi_awaddr <= 8'h00; s_axi_wdata <= is_dec_op ? 32'h00000003 : 32'h00000001; fsm_state <= S_WR_CTRL; end
                S_WR_CTRL: if (s_axi_bvalid) begin s_axi_awvalid <= 1'b0; s_axi_wvalid <= 1'b0; s_axi_bready <= 1'b0; fsm_state <= S_WAIT_CORE; end
                S_WAIT_CORE: if (soc_done) begin s_axi_araddr <= 8'h28; s_axi_arvalid <= 1'b1; s_axi_rready <= 1'b1; fsm_state <= S_RD_DOUT0; end
                S_RD_DOUT0: if (s_axi_rvalid) begin s_axi_arvalid <= 1'b0; s_axi_rready <= 1'b0; latched_leds <= s_axi_rdata[7:0]; latched_done <= 1'b1; fsm_state <= S_DISPLAY; end
                S_DISPLAY: if (trig_enc || trig_dec) fsm_state <= S_IDLE;
                default: fsm_state <= S_IDLE;
            endcase
        end
    end

    assign led_busy  = soc_busy;
    assign led_done  = latched_done || soc_done;
    assign led_fault = latched_fault || soc_fault || security_irq;
    assign led_data  = latched_leds;

endmodule
