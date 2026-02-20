`timescale 1ns / 1ps
module tb_enose_accel_stub;

    reg clk = 0;
    always #5 clk = ~clk;

    reg resetn = 0;
    reg  [6:0]  awaddr=0;  reg awvalid=0;  wire awready;
    reg  [31:0] wdata=0;   reg [3:0] wstrb=0;  reg wvalid=0;  wire wready;
    wire [1:0]  bresp;     wire bvalid;  reg bready=0;
    reg  [6:0]  araddr=0;  reg arvalid=0;  wire arready;
    wire [31:0] rdata;     wire [1:0] rresp;  wire rvalid;  reg rready=0;
    reg  [31:0] tdata=0;   reg tvalid=0;  wire tready;  reg tlast=0;

    enose_accel_stub #(.C_S00_AXI_DATA_WIDTH(32),.C_S00_AXI_ADDR_WIDTH(7)) dut (
        .s00_axi_aclk(clk), .s00_axi_aresetn(resetn),
        .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'b0),
        .s00_axi_awvalid(awvalid), .s00_axi_awready(awready),
        .s00_axi_wdata(wdata), .s00_axi_wstrb(wstrb),
        .s00_axi_wvalid(wvalid), .s00_axi_wready(wready),
        .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid), .s00_axi_bready(bready),
        .s00_axi_araddr(araddr), .s00_axi_arprot(3'b0),
        .s00_axi_arvalid(arvalid), .s00_axi_arready(arready),
        .s00_axi_rdata(rdata), .s00_axi_rresp(rresp),
        .s00_axi_rvalid(rvalid), .s00_axi_rready(rready),
        .s_axis_tdata(tdata), .s_axis_tvalid(tvalid),
        .s_axis_tready(tready), .s_axis_tlast(tlast)
    );

    // AXI-Lite write — setup on negedge, DUT samples on posedge
    task wr(input [6:0] a, input [31:0] d);
        begin
            @(negedge clk);  // setup before rising edge
            awaddr  <= a;
            awvalid <= 1'b1;
            wdata   <= d;
            wstrb   <= 4'hF;
            wvalid  <= 1'b1;
            bready  <= 1'b1;
            @(posedge clk);  // DUT sees valid+ready → transaction
            @(negedge clk);  // deassert after DUT sampled
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
            @(posedge clk);  // bvalid cycle
            @(negedge clk);
            bready  <= 1'b0;
            @(posedge clk);  // settle
        end
    endtask

    // AXI-Lite read
    reg [31:0] rd;
    task rdtask(input [6:0] a);
        begin
            @(negedge clk);
            araddr  <= a;
            arvalid <= 1'b1;
            rready  <= 1'b1;
            @(posedge clk);  // DUT accepts address
            @(negedge clk);
            arvalid <= 1'b0;
            @(posedge clk);  // rvalid + rdata
            rd = rdata;
            @(negedge clk);
            rready  <= 1'b0;
            @(posedge clk);
        end
    endtask

    // Stream send — setup on negedge, exactly 1 posedge with tvalid=1
    task sw(input [31:0] d, input last);
        begin
            @(negedge clk);        // setup half-cycle before rising edge
            tdata  <= d;
            tvalid <= 1'b1;
            tlast  <= last;
            @(posedge clk);        // DUT samples: tvalid=1, tready=1 → 1 beat
            @(negedge clk);        // deassert immediately after
            tvalid <= 1'b0;
            tlast  <= 1'b0;
        end
    endtask

    integer i, pass_count;

    initial begin
        pass_count = 0;
        repeat(20) @(posedge clk);
        resetn = 1;
        repeat(5) @(posedge clk);

        $display("============================================");
        $display("  TB START (v7)");
        $display("============================================");

        // ─── TEST 1: zeros → Fresh(0) ───
        $display("\n-- TEST 1: All zeros -> Fresh(0) --");
        wr(7'h00, 32'h02);          // RESET
        repeat(3) @(posedge clk);
        wr(7'h08, 32'd10);          // WINDOW_LEN = 10

        for (i=0; i<9; i=i+1) sw(32'h000, 0);
        sw(32'h000, 1);
        repeat(5) @(posedge clk);

        wr(7'h00, 32'h01);          // START
        repeat(10) @(posedge clk);

        rdtask(7'h04); $display("  STATUS    = 0x%08X (DONE=%b ERR=%b)", rd, rd[0], rd[2]);
        rdtask(7'h18); $display("  CLASS     = %0d", rd);
        if (rd==0) begin $display("  [PASS]"); pass_count=pass_count+1; end
        else       $display("  [FAIL] expected 0 got %0d", rd);
        rdtask(7'h30); $display("  words_rx  = %0d (expect 10)", rd);
        rdtask(7'h34); $display("  total_pop = %0d (expect 0)", rd);

        // ─── TEST 2: 0xFFF → Spoiled(2) ───
        $display("\n-- TEST 2: All FFF -> Spoiled(2) --");
        wr(7'h00, 32'h02);          // RESET
        repeat(3) @(posedge clk);
        wr(7'h08, 32'd10);

        for (i=0; i<9; i=i+1) sw(32'hFFF, 0);
        sw(32'hFFF, 1);
        repeat(5) @(posedge clk);

        wr(7'h00, 32'h01);          // START
        repeat(10) @(posedge clk);

        rdtask(7'h04); $display("  STATUS    = 0x%08X", rd);
        rdtask(7'h18); $display("  CLASS     = %0d", rd);
        if (rd==2) begin $display("  [PASS]"); pass_count=pass_count+1; end
        else       $display("  [FAIL] expected 2 got %0d", rd);
        rdtask(7'h30); $display("  words_rx  = %0d (expect 10)", rd);
        rdtask(7'h34); $display("  total_pop = %0d (expect 120)", rd);

        // ─── TEST 3: 5 bits/word → Warning(1) ───
        $display("\n-- TEST 3: ~5 bits/word -> Warning(1) --");
        wr(7'h00, 32'h02);          // RESET
        repeat(3) @(posedge clk);
        wr(7'h08, 32'd10);

        sw(32'h01F,0); sw(32'h03E,0); sw(32'h07C,0); sw(32'h0F8,0); sw(32'h1F0,0);
        sw(32'h01F,0); sw(32'h03E,0); sw(32'h07C,0); sw(32'h0F8,0); sw(32'h1F0,1);
        repeat(5) @(posedge clk);

        wr(7'h00, 32'h01);          // START
        repeat(10) @(posedge clk);

        rdtask(7'h04); $display("  STATUS    = 0x%08X", rd);
        rdtask(7'h18); $display("  CLASS     = %0d", rd);
        if (rd==1) begin $display("  [PASS]"); pass_count=pass_count+1; end
        else       $display("  [FAIL] expected 1 got %0d", rd);
        rdtask(7'h30); $display("  words_rx  = %0d (expect 10)", rd);
        rdtask(7'h34); $display("  total_pop = %0d (expect 50)", rd);

        $display("\n============================================");
        $display("  RESULT: %0d / 3 PASSED", pass_count);
        $display("============================================");
        #200; $finish;
    end

    initial begin #5000000; $display("[TIMEOUT]"); $finish; end

endmodule
