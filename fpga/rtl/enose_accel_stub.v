`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// enose_accel_stub.v — Overlay 0 (v5, single-file)
//
// Stream-first: data arrives via AXI-Stream, accumulates on the fly.
// PS writes START → IP reads accumulators, classifies, writes results.
// PS writes RESET → clears accumulators for next frame.
//
// Sequence: RESET → stream N words → START → read results → RESET → ...
//////////////////////////////////////////////////////////////////////////////

module enose_accel_stub #(
    parameter C_S00_AXI_DATA_WIDTH = 32,
    parameter C_S00_AXI_ADDR_WIDTH = 7
)(
    input  wire                                  s00_axi_aclk,
    input  wire                                  s00_axi_aresetn,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]       s00_axi_awaddr,
    input  wire [2:0]                             s00_axi_awprot,
    input  wire                                   s00_axi_awvalid,
    output reg                                    s00_axi_awready,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0]       s00_axi_wdata,
    input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0]   s00_axi_wstrb,
    input  wire                                   s00_axi_wvalid,
    output reg                                    s00_axi_wready,
    output wire [1:0]                             s00_axi_bresp,
    output reg                                    s00_axi_bvalid,
    input  wire                                   s00_axi_bready,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]       s00_axi_araddr,
    input  wire [2:0]                             s00_axi_arprot,
    input  wire                                   s00_axi_arvalid,
    output reg                                    s00_axi_arready,
    output reg  [C_S00_AXI_DATA_WIDTH-1:0]       s00_axi_rdata,
    output wire [1:0]                             s00_axi_rresp,
    output reg                                    s00_axi_rvalid,
    input  wire                                   s00_axi_rready,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast
);

    wire clk    = s00_axi_aclk;
    wire resetn = s00_axi_aresetn;
    assign s00_axi_bresp = 2'b00;
    assign s00_axi_rresp = 2'b00;

    // ══════════════════════════════════════════
    //  Registers
    // ══════════════════════════════════════════
    reg [31:0] r_window_len;
    reg        r_done, r_busy, r_err;
    reg [1:0]  r_result_class;
    reg [31:0] r_count0, r_count1, r_count2;
    reg [31:0] r_conf, r_latency, r_debug0, r_debug1;

    // Control pulses (active for 1 cycle)
    reg ctrl_start, ctrl_reset;

    // ══════════════════════════════════════════
    //  AXI-Lite WRITE (ready-by-default)
    // ══════════════════════════════════════════
    wire wr_txn = s00_axi_awvalid & s00_axi_awready &
                  s00_axi_wvalid  & s00_axi_wready;

    always @(posedge clk) begin
        if (!resetn) begin
            s00_axi_awready <= 1'b1;
            s00_axi_wready  <= 1'b1;
            s00_axi_bvalid  <= 1'b0;
            r_window_len    <= 32'd10;
            ctrl_start      <= 1'b0;
            ctrl_reset      <= 1'b0;
        end else begin
            ctrl_start <= 1'b0;
            ctrl_reset <= 1'b0;

            if (wr_txn) begin
                s00_axi_awready <= 1'b0;
                s00_axi_wready  <= 1'b0;
                s00_axi_bvalid  <= 1'b1;
                case (s00_axi_awaddr[6:2])
                    5'h00: begin
                        if (s00_axi_wdata[0]) ctrl_start <= 1'b1;
                        if (s00_axi_wdata[1]) ctrl_reset <= 1'b1;
                    end
                    5'h02: r_window_len <= s00_axi_wdata;
                    default: ;
                endcase
            end

            if (s00_axi_bvalid && s00_axi_bready) begin
                s00_axi_bvalid  <= 1'b0;
                s00_axi_awready <= 1'b1;
                s00_axi_wready  <= 1'b1;
            end
        end
    end

    // ══════════════════════════════════════════
    //  AXI-Lite READ (ready-by-default)
    // ══════════════════════════════════════════
    always @(posedge clk) begin
        if (!resetn) begin
            s00_axi_arready <= 1'b1;
            s00_axi_rvalid  <= 1'b0;
            s00_axi_rdata   <= 32'd0;
        end else begin
            if (s00_axi_arvalid && s00_axi_arready) begin
                s00_axi_arready <= 1'b0;
                s00_axi_rvalid  <= 1'b1;
                case (s00_axi_araddr[6:2])
                    5'h00: s00_axi_rdata <= 32'd0;
                    5'h01: s00_axi_rdata <= {29'd0, r_err, r_busy, r_done};
                    5'h02: s00_axi_rdata <= r_window_len;
                    5'h03: s00_axi_rdata <= 32'd12;
                    5'h04: s00_axi_rdata <= 32'd32;
                    5'h05: s00_axi_rdata <= 32'd3;
                    5'h06: s00_axi_rdata <= {30'd0, r_result_class};
                    5'h07: s00_axi_rdata <= r_count0;
                    5'h08: s00_axi_rdata <= r_count1;
                    5'h09: s00_axi_rdata <= r_count2;
                    5'h0A: s00_axi_rdata <= r_conf;
                    5'h0B: s00_axi_rdata <= r_latency;
                    5'h0C: s00_axi_rdata <= r_debug0;
                    5'h0D: s00_axi_rdata <= r_debug1;
                    default: s00_axi_rdata <= 32'd0;
                endcase
            end
            if (s00_axi_rvalid && s00_axi_rready) begin
                s00_axi_rvalid  <= 1'b0;
                s00_axi_arready <= 1'b1;
            end
        end
    end

    // ══════════════════════════════════════════
    //  AXI-Stream: always accept, accumulate
    // ══════════════════════════════════════════
    assign s_axis_tready = resetn;  // always accept when not in reset

    wire stream_beat = s_axis_tvalid & s_axis_tready;

    function [3:0] popcount12;
        input [11:0] bits;
        integer k;
        begin
            popcount12 = 0;
            for (k = 0; k < 12; k = k + 1)
                popcount12 = popcount12 + {3'b0, bits[k]};
        end
    endfunction

    // Accumulators: reset ONLY on ctrl_reset (not on ctrl_start!)
    reg [31:0] acc_pop;
    reg [31:0] acc_words;

    always @(posedge clk) begin
        if (!resetn || ctrl_reset) begin
            acc_pop   <= 32'd0;
            acc_words <= 32'd0;
        end else if (stream_beat) begin
            acc_pop   <= acc_pop + {28'd0, popcount12(s_axis_tdata[11:0])};
            acc_words <= acc_words + 32'd1;
        end
    end

    // ══════════════════════════════════════════
    //  Processing: START reads accumulators
    // ══════════════════════════════════════════
    always @(posedge clk) begin
        if (!resetn || ctrl_reset) begin
            r_done         <= 1'b0;
            r_busy         <= 1'b0;
            r_err          <= 1'b0;
            r_result_class <= 2'd0;
            r_count0       <= 32'd0;
            r_count1       <= 32'd0;
            r_count2       <= 32'd0;
            r_conf         <= 32'd0;
            r_latency      <= 32'd0;
            r_debug0       <= 32'd0;
            r_debug1       <= 32'd0;
        end else if (ctrl_start) begin
            r_debug0 <= acc_words;
            r_debug1 <= acc_pop;
            r_done   <= 1'b1;

            if (acc_words < r_window_len) begin
                r_err <= 1'b1;
            end else begin
                r_err <= 1'b0;
                // Classify
                if (acc_pop < 32'd30) begin
                    r_result_class <= 2'd0;
                    r_count0 <= acc_pop; r_count1 <= 0; r_count2 <= 0;
                end else if (acc_pop < 32'd70) begin
                    r_result_class <= 2'd1;
                    r_count0 <= 0; r_count1 <= acc_pop; r_count2 <= 0;
                end else begin
                    r_result_class <= 2'd2;
                    r_count0 <= 0; r_count1 <= 0; r_count2 <= acc_pop;
                end
                r_conf    <= 32'd32767;
                r_latency <= acc_words;
            end
        end
    end

endmodule
