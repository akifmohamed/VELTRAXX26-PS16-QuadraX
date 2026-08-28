// ============================================================================
// Module: axi4_lite_slave.v
// Description: Standard 32-bit AMBA AXI4-Lite Slave Interface Controller.
//              Provides memory-mapped register addressing for Control, Status,
//              Key, Data In, and Data Out with non-blocking handshakes.
// ============================================================================
`timescale 1ns/1ps

module axi4_lite_slave (
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Write Address Channel
    input  wire [7:0]  s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    // AXI4-Lite Write Response Channel
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  wire [7:0]  s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    // AXI4-Lite Read Data Channel
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Core Interconnect Signals
    output wire [127:0] key_out,
    output wire [127:0] din_out,
    input  wire [127:0] dout_in,
    output wire         start_pulse,
    output wire         mode_enc_dec,
    output wire         soft_rst,
    output wire         fault_inject_cmd,
    input  wire         busy_in,
    input  wire         done_in,
    input  wire         fault_in,
    input  wire         irq_in
);

    // Register Offsets
    localparam ADDR_CTRL   = 8'h00; // [0]=Start, [1]=Mode (0=Enc, 1=Dec), [2]=SoftRst, [3]=FaultInject
    localparam ADDR_STATUS = 8'h04; // [0]=Busy, [1]=Done, [2]=Fault_Detected, [3]=Security_IRQ
    localparam ADDR_KEY0   = 8'h08; // Key[31:0]
    localparam ADDR_KEY1   = 8'h0C; // Key[63:32]
    localparam ADDR_KEY2   = 8'h10; // Key[95:64]
    localparam ADDR_KEY3   = 8'h14; // Key[127:96]
    localparam ADDR_DIN0   = 8'h18; // DIN[31:0]
    localparam ADDR_DIN1   = 8'h1C; // DIN[63:32]
    localparam ADDR_DIN2   = 8'h20; // DIN[95:64]
    localparam ADDR_DIN3   = 8'h24; // DIN[127:96]
    localparam ADDR_DOUT0  = 8'h28; // DOUT[31:0]
    localparam ADDR_DOUT1  = 8'h2C; // DOUT[63:32]
    localparam ADDR_DOUT2  = 8'h30; // DOUT[95:64]
    localparam ADDR_DOUT3  = 8'h34; // DOUT[127:96]

    // Internal Register Declarations
    reg [31:0] reg_ctrl;
    reg [31:0] reg_key0, reg_key1, reg_key2, reg_key3;
    reg [31:0] reg_din0, reg_din1, reg_din2, reg_din3;

    // Status Word
    wire [31:0] reg_status = {28'd0, irq_in, fault_in, done_in, busy_in};

    assign key_out          = {reg_key3, reg_key2, reg_key1, reg_key0};
    assign din_out          = {reg_din3, reg_din2, reg_din1, reg_din0};
    assign start_pulse      = reg_ctrl[0];
    assign mode_enc_dec     = reg_ctrl[1];
    assign soft_rst         = reg_ctrl[2];
    assign fault_inject_cmd = reg_ctrl[3];

    // ------------------------------------------------------------------------
    // AXI4-Lite Write Channels
    // ------------------------------------------------------------------------
    reg [7:0] awaddr_reg;
    reg       aw_done, w_done;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            awaddr_reg    <= 8'd0;
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
            reg_ctrl      <= 32'd0;
            reg_key0      <= 32'd0;
            reg_key1      <= 32'd0;
            reg_key2      <= 32'd0;
            reg_key3      <= 32'd0;
            reg_din0      <= 32'd0;
            reg_din1      <= 32'd0;
            reg_din2      <= 32'd0;
            reg_din3      <= 32'd0;
        end else begin
            // Pulse signals auto-clear
            reg_ctrl[0] <= 1'b0;
            reg_ctrl[3] <= 1'b0;

            // Security wipeout
            if (fault_in || irq_in) begin
                reg_key0 <= 32'd0;
                reg_key1 <= 32'd0;
                reg_key2 <= 32'd0;
                reg_key3 <= 32'd0;
            end

            // Latch write address
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_reg <= s_axi_awaddr;
                aw_done    <= 1'b1;
                s_axi_awready <= 1'b0;
            end

            // Latch write data
            if (s_axi_wvalid && s_axi_wready) begin
                w_done       <= 1'b1;
                s_axi_wready <= 1'b0;
                case (s_axi_awvalid ? s_axi_awaddr : awaddr_reg)
                    ADDR_CTRL: reg_ctrl <= s_axi_wdata;
                    ADDR_KEY0: reg_key0 <= s_axi_wdata;
                    ADDR_KEY1: reg_key1 <= s_axi_wdata;
                    ADDR_KEY2: reg_key2 <= s_axi_wdata;
                    ADDR_KEY3: reg_key3 <= s_axi_wdata;
                    ADDR_DIN0: reg_din0 <= s_axi_wdata;
                    ADDR_DIN1: reg_din1 <= s_axi_wdata;
                    ADDR_DIN2: reg_din2 <= s_axi_wdata;
                    ADDR_DIN3: reg_din3 <= s_axi_wdata;
                    default: ;
                endcase
            end

            // Generate BVALID when both AW and W are completed
            if ((aw_done || (s_axi_awvalid && s_axi_awready)) && 
                (w_done  || (s_axi_wvalid && s_axi_wready)) && !s_axi_bvalid) begin
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;
                aw_done       <= 1'b0;
                w_done        <= 1'b0;
            end

            // Clear BVALID on BREADY
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // AXI4-Lite Read Channels
    // ------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'd0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr[7:0])
                    ADDR_CTRL:   s_axi_rdata <= reg_ctrl;
                    ADDR_STATUS: s_axi_rdata <= reg_status;
                    ADDR_DIN0:   s_axi_rdata <= reg_din0;
                    ADDR_DIN1:   s_axi_rdata <= reg_din1;
                    ADDR_DIN2:   s_axi_rdata <= reg_din2;
                    ADDR_DIN3:   s_axi_rdata <= reg_din3;
                    ADDR_DOUT0:  s_axi_rdata <= dout_in[31:0];
                    ADDR_DOUT1:  s_axi_rdata <= dout_in[63:32];
                    ADDR_DOUT2:  s_axi_rdata <= dout_in[95:64];
                    ADDR_DOUT3:  s_axi_rdata <= dout_in[127:96];
                    default:     s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;
                s_axi_arready <= 1'b1;
            end
        end
    end

endmodule
