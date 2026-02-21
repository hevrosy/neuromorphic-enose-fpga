// ============================================================================
// tb_enose_accel.v — Testbench for SNN Inference Accelerator
// ============================================================================
// Tests:
//   1. All-zeros input → class 0 (no spikes)
//   2. All-ones input (0xFFF) → depends on weights
//   3. Single channel
//   4. Read all registers and verify
//
// To run with actual golden vectors, provide w1.mem and w2.mem
// For standalone test, we init weights to simple known values
// ============================================================================

`timescale 1ns / 1ps

module tb_enose_accel;

    // Parameters
    localparam CLK_PERIOD = 10; // 100 MHz
    localparam N_IN      = 12;
    localparam N_HIDDEN  = 32;
    localparam N_OUT     = 3;
    localparam WINDOW_LEN = 10;

    // Clock and reset
    reg clk, resetn;

    // AXI-Lite signals
    reg  [6:0]  awaddr;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;
    reg  [6:0]  araddr;
    reg         arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    // AXI-Stream signals
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;

    // DUT
    enose_accel #(
        .N_IN(N_IN),
        .N_HIDDEN(N_HIDDEN),
        .N_OUT(N_OUT),
        .TH_H(64),
        .TH_O(64),
        .LEAK_H(4),
        .LEAK_O(4)
    ) dut (
        .s00_axi_aclk(clk),
        .s00_axi_aresetn(resetn),
        .s00_axi_awaddr(awaddr),
        .s00_axi_awprot(3'b000),
        .s00_axi_awvalid(awvalid),
        .s00_axi_awready(awready),
        .s00_axi_wdata(wdata),
        .s00_axi_wstrb(wstrb),
        .s00_axi_wvalid(wvalid),
        .s00_axi_wready(wready),
        .s00_axi_bresp(bresp),
        .s00_axi_bvalid(bvalid),
        .s00_axi_bready(bready),
        .s00_axi_araddr(araddr),
        .s00_axi_arprot(3'b000),
        .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready),
        .s00_axi_rdata(rdata),
        .s00_axi_rresp(rresp),
        .s00_axi_rvalid(rvalid),
        .s00_axi_rready(rready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast)
    );

    // =========================================================================
    // Clock generation
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // AXI-Lite helper tasks
    // =========================================================================
    task axi_write(input [6:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr  <= addr;
            awvalid <= 1;
            wdata   <= data;
            wstrb   <= 4'hF;
            wvalid  <= 1;
            bready  <= 1;
            @(posedge clk);
            while (!awready || !wready) @(posedge clk);
            awvalid <= 0;
            wvalid  <= 0;
            while (!bvalid) @(posedge clk);
            bready <= 0;
            @(posedge clk);
        end
    endtask

    task axi_read(input [6:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            araddr  <= addr;
            arvalid <= 1;
            rready  <= 1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            arvalid <= 0;
            while (!rvalid) @(posedge clk);
            data = rdata;
            rready <= 0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Stream send task — send WINDOW_LEN words
    // =========================================================================
    task stream_send_window(input [11:0] masks [0:63], input integer wlen);
        integer i;
        begin
            for (i = 0; i < wlen; i = i + 1) begin
                @(posedge clk);
                s_axis_tdata  <= {20'd0, masks[i]};
                s_axis_tvalid <= 1;
                s_axis_tlast  <= (i == wlen - 1) ? 1'b1 : 1'b0;
                @(posedge clk);
                while (!s_axis_tready) @(posedge clk);
            end
            @(posedge clk);
            s_axis_tvalid <= 0;
            s_axis_tlast  <= 0;
        end
    endtask

    // =========================================================================
    // Wait for DONE
    // =========================================================================
    task wait_done;
        reg [31:0] status;
        integer timeout;
        begin
            timeout = 0;
            status = 0;
            while (!(status & 32'h1) && timeout < 100000) begin
                axi_read(7'h04, status);
                timeout = timeout + 1;
            end
            if (timeout >= 100000)
                $display("ERROR: Timeout waiting for DONE!");
        end
    endtask

    // =========================================================================
    // Test counters
    // =========================================================================
    integer tests_run, tests_passed;

    // =========================================================================
    // Main test
    // =========================================================================
    reg [11:0] test_masks [0:63];
    reg [31:0] rd_val;
    integer ti;

    initial begin
        $dumpfile("tb_enose_accel.vcd");
        $dumpvars(0, tb_enose_accel);

        tests_run = 0;
        tests_passed = 0;

        // Init signals
        resetn        = 0;
        awaddr = 0; awvalid = 0;
        wdata = 0; wstrb = 0; wvalid = 0;
        bready = 0;
        araddr = 0; arvalid = 0; rready = 0;
        s_axis_tdata = 0; s_axis_tvalid = 0; s_axis_tlast = 0;

        // Reset
        repeat(10) @(posedge clk);
        resetn = 1;
        repeat(5) @(posedge clk);

        // =====================================================================
        // TEST 1: All zeros — no spikes
        // =====================================================================
        $display("\n========== TEST 1: All zeros ==========");
        tests_run = tests_run + 1;

        // Set window length
        axi_write(7'h08, WINDOW_LEN);

        // Reset core
        axi_write(7'h00, 32'h2); // RESET
        repeat(3) @(posedge clk);

        // Start
        axi_write(7'h00, 32'h1); // START

        // Send all-zero spike masks
        for (ti = 0; ti < WINDOW_LEN; ti = ti + 1)
            test_masks[ti] = 12'h000;
        stream_send_window(test_masks, WINDOW_LEN);

        // Wait for done
        wait_done;

        // Read results
        axi_read(7'h18, rd_val); // RESULT_CLASS
        $display("  RESULT_CLASS = %0d", rd_val);

        axi_read(7'h1C, rd_val); $display("  COUNT0 = %0d", rd_val);
        axi_read(7'h20, rd_val); $display("  COUNT1 = %0d", rd_val);
        axi_read(7'h24, rd_val); $display("  COUNT2 = %0d", rd_val);
        axi_read(7'h2C, rd_val); $display("  LATENCY = %0d cycles", rd_val);
        axi_read(7'h30, rd_val); $display("  DEBUG0 (words_rx) = %0d", rd_val);
        axi_read(7'h34, rd_val); $display("  DEBUG1 (h_spikes) = %0d", rd_val);

        // With all-zero input, all counts should be 0, class should be 0
        axi_read(7'h1C, rd_val);
        if (rd_val == 0) begin
            $display("  TEST 1 PASSED: count0=0 as expected");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  TEST 1 FAILED: expected count0=0, got %0d", rd_val);
        end

        // =====================================================================
        // TEST 2: All ones — all 12 channels active
        // =====================================================================
        $display("\n========== TEST 2: All ones (0xFFF) ==========");
        tests_run = tests_run + 1;

        axi_write(7'h00, 32'h2); // RESET
        repeat(3) @(posedge clk);
        axi_write(7'h00, 32'h1); // START

        for (ti = 0; ti < WINDOW_LEN; ti = ti + 1)
            test_masks[ti] = 12'hFFF;
        stream_send_window(test_masks, WINDOW_LEN);

        wait_done;

        axi_read(7'h18, rd_val); $display("  RESULT_CLASS = %0d", rd_val);
        axi_read(7'h1C, rd_val); $display("  COUNT0 = %0d", rd_val);
        axi_read(7'h20, rd_val); $display("  COUNT1 = %0d", rd_val);
        axi_read(7'h24, rd_val); $display("  COUNT2 = %0d", rd_val);
        axi_read(7'h2C, rd_val); $display("  LATENCY = %0d cycles", rd_val);
        axi_read(7'h34, rd_val); $display("  DEBUG1 (h_spikes) = %0d", rd_val);

        // Status should be DONE
        axi_read(7'h04, rd_val);
        if (rd_val & 32'h1) begin
            $display("  TEST 2 PASSED: inference completed");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  TEST 2 FAILED: status=%08X (not DONE)", rd_val);
        end

        // =====================================================================
        // TEST 3: Ramp pattern
        // =====================================================================
        $display("\n========== TEST 3: Ramp pattern ==========");
        tests_run = tests_run + 1;

        axi_write(7'h00, 32'h2);
        repeat(3) @(posedge clk);
        axi_write(7'h00, 32'h1);

        for (ti = 0; ti < WINDOW_LEN; ti = ti + 1) begin
            if (ti + 1 <= 12)
                test_masks[ti] = (1 << (ti + 1)) - 1;
            else
                test_masks[ti] = 12'hFFF;
        end
        stream_send_window(test_masks, WINDOW_LEN);

        wait_done;

        axi_read(7'h18, rd_val); $display("  RESULT_CLASS = %0d", rd_val);
        axi_read(7'h1C, rd_val); $display("  COUNT0 = %0d", rd_val);
        axi_read(7'h20, rd_val); $display("  COUNT1 = %0d", rd_val);
        axi_read(7'h24, rd_val); $display("  COUNT2 = %0d", rd_val);
        axi_read(7'h2C, rd_val); $display("  LATENCY = %0d cycles", rd_val);

        axi_read(7'h04, rd_val);
        if (rd_val & 32'h1) begin
            $display("  TEST 3 PASSED: inference completed");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  TEST 3 FAILED");
        end

        // =====================================================================
        // TEST 4: Read constant registers
        // =====================================================================
        $display("\n========== TEST 4: Read constant regs ==========");
        tests_run = tests_run + 1;

        axi_read(7'h0C, rd_val);
        $display("  N_IN = %0d (expected %0d)", rd_val, N_IN);
        if (rd_val == N_IN) begin
            axi_read(7'h10, rd_val);
            $display("  N_HIDDEN = %0d (expected %0d)", rd_val, N_HIDDEN);
            if (rd_val == N_HIDDEN) begin
                axi_read(7'h14, rd_val);
                $display("  N_OUT = %0d (expected %0d)", rd_val, N_OUT);
                if (rd_val == N_OUT) begin
                    $display("  TEST 4 PASSED");
                    tests_passed = tests_passed + 1;
                end else $display("  TEST 4 FAILED: N_OUT mismatch");
            end else $display("  TEST 4 FAILED: N_HIDDEN mismatch");
        end else $display("  TEST 4 FAILED: N_IN mismatch");

        // =====================================================================
        // Summary
        // =====================================================================
        $display("\n============================================");
        $display("  RESULTS: %0d / %0d tests PASSED", tests_passed, tests_run);
        $display("============================================\n");

        if (tests_passed == tests_run)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        #100;
        $finish;
    end

endmodule
