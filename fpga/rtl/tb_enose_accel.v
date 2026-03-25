// ============================================================================
// tb_enose_accel.v — Testbench v4 (Fixed AXI-Lite & AXI-Stream Handshakes)
// ============================================================================

`timescale 1ns / 1ps

module tb_enose_accel;
    localparam CLK_PERIOD  = 10;
    localparam N_IN        = 12;
    localparam N_HIDDEN    = 32;
    localparam N_OUT       = 3;
    localparam WINDOW_LEN  = 10;

    reg clk, resetn;

    // AXI-Lite
    reg  [6:0]  awaddr;  reg awvalid; wire awready;
    reg  [31:0] wdata;   reg [3:0] wstrb; reg wvalid; wire wready;
    wire [1:0]  bresp;   wire bvalid; reg bready;
    reg  [6:0]  araddr;  reg arvalid; wire arready;
    wire [31:0] rdata;   wire [1:0] rresp; wire rvalid; reg rready;

    // AXI-Stream
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;

    enose_accel #(
        .N_IN(N_IN), .N_HIDDEN(N_HIDDEN), .N_OUT(N_OUT),
        .TH_H(64), .TH_O(64), .LEAK_H(4), .LEAK_O(4)
    ) dut (
        .s00_axi_aclk(clk), .s00_axi_aresetn(resetn),
        .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'b000),
        .s00_axi_awvalid(awvalid), .s00_axi_awready(awready),
        .s00_axi_wdata(wdata), .s00_axi_wstrb(wstrb),
        .s00_axi_wvalid(wvalid), .s00_axi_wready(wready),
        .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid), .s00_axi_bready(bready),
        .s00_axi_araddr(araddr), .s00_axi_arprot(3'b000),
        .s00_axi_arvalid(arvalid), .s00_axi_arready(arready),
        .s00_axi_rdata(rdata), .s00_axi_rresp(rresp),
        .s00_axi_rvalid(rvalid), .s00_axi_rready(rready),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready), .s_axis_tlast(s_axis_tlast)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Shared spike buffer
    reg [11:0] send_buf [0:63];
    reg [31:0] rd_data;

    // =========================================================================
    // AXI-Lite WRITE — Fixed parallel channel acknowledgment
    // =========================================================================
    task axi_write;
        input [6:0] addr;
        input [31:0] data;
        reg aw_done_local, w_done_local;
        begin
            aw_done_local = 0; w_done_local = 0;
            @(posedge clk);
            #1; 
            awaddr  = addr; awvalid = 1;
            wdata   = data; wstrb   = 4'hF; wvalid  = 1;
            bready  = 1;

            // Wait for both AW and W to be accepted (can happen in any order or same cycle)
            while (!aw_done_local || !w_done_local) begin
                @(posedge clk);
                if (awready) begin awvalid = 0; aw_done_local = 1; end
                if (wready)  begin wvalid  = 0; w_done_local  = 1; end
            end

            // Wait for write response
            while (!bvalid) @(posedge clk);
            #1;
            bready = 0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // AXI-Lite READ — result in rd_data
    // =========================================================================
    task axi_read;
        input [6:0] addr;
        begin
            @(posedge clk);
            #1;
            araddr  = addr;
            arvalid = 1;
            rready  = 1;

            @(posedge clk);
            while (!arready) @(posedge clk);
            #1;
            arvalid = 0;

            while (!rvalid) @(posedge clk);
            rd_data = rdata;
            #1;
            rready = 0;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Stream send — Fixed single-cycle validity
    // =========================================================================
    task stream_send;
        input integer wlen;
        integer si;
        begin
            for (si = 0; si < wlen; si = si + 1) begin
                #1;
                s_axis_tdata  = {20'd0, send_buf[si]};
                s_axis_tvalid = 1;
                s_axis_tlast  = (si == wlen - 1) ? 1'b1 : 1'b0;

                @(posedge clk);
                while (!s_axis_tready) @(posedge clk); // Hold if DUT isn't ready
            end
            #1;
            s_axis_tvalid = 0;
            s_axis_tlast  = 0;
        end
    endtask

    // =========================================================================
    // Wait for DONE
    // =========================================================================
    task wait_done;
        integer timeout;
        begin
            timeout = 0;
            rd_data = 0;
            while (!(rd_data & 32'h1) && timeout < 50000) begin
                axi_read(7'h04);
                timeout = timeout + 1;
            end
            if (timeout >= 50000)
                $display("  ERROR: Timeout after %0d polls!", timeout);
        end
    endtask

    // =========================================================================
    // Tests
    // =========================================================================
    integer tests_run, tests_passed;
    integer ti;

    initial begin
        tests_run    = 0;
        tests_passed = 0;
        resetn = 0;
        awaddr = 0; awvalid = 0; wdata = 0; wstrb = 0; wvalid = 0;
        bready = 0; araddr = 0; arvalid = 0; rready = 0;
        s_axis_tdata = 0; s_axis_tvalid = 0; s_axis_tlast = 0;

        repeat(20) @(posedge clk);
        resetn = 1;
        repeat(10) @(posedge clk);

        $display("");
        $display("============================================");
        $display(" SNN Inference Core — Simulation Start");
        $display("============================================");

        // TEST 1: All zeros
        $display("\n========== TEST 1: All zeros ==========");
        tests_run = tests_run + 1;
        axi_write(7'h08, WINDOW_LEN);
        axi_write(7'h00, 32'h2);  // RESET
        repeat(5) @(posedge clk);
        axi_write(7'h00, 32'h1);  // START

        for (ti = 0; ti < WINDOW_LEN; ti = ti + 1)
            send_buf[ti] = 12'h000;
        stream_send(WINDOW_LEN);
        wait_done;

        axi_read(7'h18); $display("  RESULT_CLASS = %0d", rd_data);
        axi_read(7'h1C); $display("  COUNT0 = %0d", rd_data);
        axi_read(7'h20); $display("  COUNT1 = %0d", rd_data);
        axi_read(7'h24); $display("  COUNT2 = %0d", rd_data);
        axi_read(7'h2C); $display("  LATENCY = %0d cycles", rd_data);
        axi_read(7'h30); $display("  DEBUG0 (words_rx) = %0d", rd_data);
        axi_read(7'h34); $display("  DEBUG1 (h_spikes) = %0d", rd_data);

        axi_read(7'h1C);
        if (rd_data == 0) begin
            axi_read(7'h20);
            if (rd_data == 0) begin
                axi_read(7'h24);
                if (rd_data == 0) begin
                    $display("  >> TEST 1 PASSED");
                    tests_passed = tests_passed + 1;
                end else $display("  >> TEST 1 FAILED: count2 = %0d", rd_data);
            end else $display("  >> TEST 1 FAILED: count1 = %0d", rd_data);
        end else $display("  >> TEST 1 FAILED: count0 = %0d", rd_data);

        // TEST 2: All ones (0xFFF)
        $display("\n========== TEST 2: All ones (0xFFF) ==========");
        tests_run = tests_run + 1;
        axi_write(7'h00, 32'h2);
        repeat(5) @(posedge clk);
        axi_write(7'h00, 32'h1);
        for (ti = 0; ti < WINDOW_LEN; ti = ti + 1)
            send_buf[ti] = 12'hFFF;
        stream_send(WINDOW_LEN);
        wait_done;

        axi_read(7'h18); $display("  RESULT_CLASS = %0d", rd_data);
        axi_read(7'h1C); $display("  COUNT0 = %0d", rd_data);
        axi_read(7'h20); $display("  COUNT1 = %0d", rd_data);
        axi_read(7'h24); $display("  COUNT2 = %0d", rd_data);
        axi_read(7'h2C); $display("  LATENCY = %0d cycles", rd_data);
        axi_read(7'h34); $display("  DEBUG1 (h_spikes) = %0d", rd_data);

        axi_read(7'h04);
        if (rd_data & 32'h1) begin
            $display("  >> TEST 2 PASSED (DONE=1)");
            tests_passed = tests_passed + 1;
        end else $display("  >> TEST 2 FAILED: status=0x%08X", rd_data);

        // TEST 3: Ramp pattern
        $display("\n========== TEST 3: Ramp pattern ==========");
        tests_run = tests_run + 1;
        axi_write(7'h00, 32'h2);
        repeat(5) @(posedge clk);
        axi_write(7'h00, 32'h1);
        for (ti = 0; ti < WINDOW_LEN; ti = ti + 1) begin
            if (ti + 1 <= 12) send_buf[ti] = (1 << (ti + 1)) - 1;
            else              send_buf[ti] = 12'hFFF;
        end
        stream_send(WINDOW_LEN);
        wait_done;

        axi_read(7'h18); $display("  RESULT_CLASS = %0d", rd_data);
        axi_read(7'h1C); $display("  COUNT0 = %0d", rd_data);
        axi_read(7'h20); $display("  COUNT1 = %0d", rd_data);
        axi_read(7'h24); $display("  COUNT2 = %0d", rd_data);
        axi_read(7'h2C); $display("  LATENCY = %0d cycles", rd_data);

        axi_read(7'h04);
        if (rd_data & 32'h1) begin
            $display("  >> TEST 3 PASSED");
            tests_passed = tests_passed + 1;
        end else $display("  >> TEST 3 FAILED");

        // TEST 4: Constant registers
        $display("\n========== TEST 4: Read constant regs ==========");
        tests_run = tests_run + 1;
        axi_read(7'h0C); $display("  N_IN = %0d", rd_data);
        if (rd_data != N_IN) begin
            $display("  >> TEST 4 FAILED: N_IN=%0d", rd_data);
        end else begin
            axi_read(7'h10); $display("  N_HIDDEN = %0d", rd_data);
            if (rd_data != N_HIDDEN) begin
                $display("  >> TEST 4 FAILED: N_HIDDEN=%0d", rd_data);
            end else begin
                axi_read(7'h14); $display("  N_OUT = %0d", rd_data);
                if (rd_data != N_OUT) begin
                    $display("  >> TEST 4 FAILED: N_OUT=%0d", rd_data);
                end else begin
                    $display("  >> TEST 4 PASSED");
                    tests_passed = tests_passed + 1;
                end
            end
        end

        // Summary
        $display("\n============================================");
        $display("  RESULTS: %0d / %0d tests PASSED", tests_passed, tests_run);
        $display("============================================");
        if (tests_passed == tests_run) $display("  >>> ALL TESTS PASSED <<<");
        else                           $display("  >>> SOME TESTS FAILED <<<");

        $display("");
        #200;
        $finish;
    end
endmodule