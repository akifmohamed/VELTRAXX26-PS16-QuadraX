// ============================================================================
// Module: aes_soc_top.v
// Description: Top-Level SoC IP Core integrating the 32-bit AMBA AXI4-Lite
//              Slave Interface with the Unified Bidirectional AES-128
//              Cryptographic Core, Parity Monitor, and Security IRQ Controller.
// ============================================================================
`timescale 1ns/1ps

module aes_soc_top (
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Slave Interface
    input  wire [7:0]  s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [7:0]  s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Unmaskable Hardware Security Interrupt
    output wire        security_irq,

    // Hardware Board Status LEDs
    output wire        led_busy,
    output wire        led_done,
    output wire        led_fault,
    output wire [7:0]  led_data
);

    // Interconnect wires
    wire [127:0] key_bus;
    wire [127:0] din_bus;
    wire [127:0] dout_bus;
    wire         start_cmd;
    wire         mode_enc_dec;
    wire         soft_rst_cmd;
    wire         fault_inject_cmd;
    wire         core_busy;
    wire         core_done;
    wire         core_fault;
    wire         core_irq;

    wire rst_n_combined = aresetn && (!soft_rst_cmd);

    // 1. AXI4-Lite Slave Interface
    axi4_lite_slave u_axi_slave (
        .aclk(aclk),
        .aresetn(rst_n_combined),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .key_out(key_bus),
        .din_out(din_bus),
        .dout_in(dout_bus),
        .start_pulse(start_cmd),
        .mode_enc_dec(mode_enc_dec),
        .soft_rst(soft_rst_cmd),
        .fault_inject_cmd(fault_inject_cmd),
        .busy_in(core_busy),
        .done_in(core_done),
        .fault_in(core_fault),
        .irq_in(core_irq)
    );

    // 2. Bidirectional AES-128 Core with Unified S-Boxes & Active Fault Security
    aes_core_bidirectional u_aes_core (
        .clk(aclk),
        .rst_n(rst_n_combined),
        .start(start_cmd),
        .enc_dec(mode_enc_dec),
        .master_key(key_bus),
        .data_in(din_bus),
        .fault_inject(fault_inject_cmd),
        .data_out(dout_bus),
        .done(core_done),
        .busy(core_busy),
        .fault_detected(core_fault),
        .security_irq(core_irq)
    );

    // External Connections
    assign security_irq = core_irq;
    assign led_busy     = core_busy;
    assign led_done     = core_done;
    assign led_fault    = core_fault;
    assign led_data     = dout_bus[7:0]; // Displays last byte on Basys3 LEDs

endmodule
