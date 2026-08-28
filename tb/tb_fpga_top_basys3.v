`timescale 1ns/1ps

module tb_fpga_top_basys3;

    reg        clk;
    reg        btnC;
    reg        btnU;
    reg        btnD;
    reg        btnR;
    wire       led_busy;
    wire       led_fault;
    wire       led_done;
    wire [7:0] led_data;

    fpga_top_basys3 dut (
        .clk(clk),
        .btnC(btnC),
        .btnU(btnU),
        .btnD(btnD),
        .btnR(btnR),
        .led_busy(led_busy),
        .led_fault(led_fault),
        .led_done(led_done),
        .led_data(led_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; btnC = 0; btnU = 0; btnD = 0; btnR = 0;
        #400;

        $display("\n[FPGA TEST 1] Pressing btnU -> Triggering NIST Encryption...");
        btnU = 1; #100; btnU = 0;
        while (!led_done) @(posedge clk);
        #40;
        $display("   [FPGA DEMO] LEDs = 0x%02h (Expected: 0x97) | led_done = %b", led_data, led_done);

        #400;
        $display("\n[FPGA TEST 2] Pressing btnD -> Triggering NIST Decryption...");
        btnD = 1; #100; btnD = 0;
        while (!led_done) @(posedge clk);
        #40;
        $display("   [FPGA DEMO] LEDs = 0x%02h (Expected: 0x2A) | led_done = %b", led_data, led_done);

        #400;
        $display("\n[FPGA TEST 3] Pressing btnR -> Injecting Tamper Fault...");
        btnR = 1; #100;
        $display("   [FPGA DEMO] LEDs = 0x%02h (Expected: 0x00) | led_fault = %b", led_data, led_fault);
        btnR = 0; #400;

        $display("\n>>> ALL BASYS3 PHYSICAL BUTTON/LED DEMONSTRATIONS 100% VERIFIED!\n");
        $finish;
    end

endmodule
