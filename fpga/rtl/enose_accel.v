// ============================================================================
// enose_accel.v — SNN Inference Accelerator (v3 - Robust BRAM Pipeline)
// ============================================================================

`timescale 1ns / 1ps

module enose_accel #(
    parameter integer N_IN      = 12,
    parameter integer N_HIDDEN  = 32,
    parameter integer N_OUT     = 3,
    parameter integer W_LEN_MAX = 64,
    parameter integer TH_H     = 64,
    parameter integer TH_O     = 64,
    parameter integer LEAK_H   = 4,
    parameter integer LEAK_O   = 4,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 7
)(
    input  wire                                s00_axi_aclk,
    input  wire                                s00_axi_aresetn,
    // AXI-Lite
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s00_axi_awaddr,
    input  wire [2:0]                          s00_axi_awprot,
    input  wire                                s00_axi_awvalid,
    output reg                                 s00_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       s00_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   s00_axi_wstrb,
    input  wire                                s00_axi_wvalid,
    output reg                                 s00_axi_wready,
    output wire [1:0]                          s00_axi_bresp,
    output reg                                 s00_axi_bvalid,
    input  wire                                s00_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       s00_axi_araddr,
    input  wire [2:0]                          s00_axi_arprot,
    input  wire                                s00_axi_arvalid,
    output reg                                 s00_axi_arready,
    output reg  [C_S_AXI_DATA_WIDTH-1:0]       s00_axi_rdata,
    output wire [1:0]                          s00_axi_rresp,
    output reg                                 s00_axi_rvalid,
    input  wire                                s00_axi_rready,
    // AXI-Stream
    input  wire [31:0]                         s_axis_tdata,
    input  wire                                s_axis_tvalid,
    output wire                                s_axis_tready,
    input  wire                                s_axis_tlast
);
    assign s00_axi_bresp = 2'b00;
    assign s00_axi_rresp = 2'b00;

    // --- Core Registers ---
    reg [31:0] reg_control, reg_status, reg_window_len, reg_result_class;
    reg [31:0] reg_count0, reg_count1, reg_count2, reg_conf, reg_latency;
    reg [31:0] reg_debug0, reg_debug1;

    // --- AXI-Lite Write Latching ---
    reg [6:0] aw_addr_latched;
    reg [31:0] w_data_latched;
    reg aw_done, w_done;
    wire wr_fire = aw_done && w_done && !s00_axi_bvalid;

    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            s00_axi_awready <= 0; s00_axi_wready  <= 0; s00_axi_bvalid  <= 0;
            aw_done <= 0; w_done  <= 0;
        end else begin
            if (s00_axi_awvalid && !aw_done) begin s00_axi_awready <= 1; aw_addr_latched <= s00_axi_awaddr[6:0]; aw_done <= 1; end 
            else s00_axi_awready <= 0;
            if (s00_axi_wvalid && !w_done) begin s00_axi_wready <= 1; w_data_latched <= s00_axi_wdata; w_done <= 1; end 
            else s00_axi_wready <= 0;
            if (wr_fire) s00_axi_bvalid <= 1;
            if (s00_axi_bvalid && s00_axi_bready) begin s00_axi_bvalid <= 0; aw_done <= 0; w_done  <= 0; end
        end
    end

    // --- AXI-Lite Read ---
    reg [6:0] ar_addr_latched;
    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            s00_axi_arready <= 0; s00_axi_rvalid  <= 0; s00_axi_rdata   <= 0;
        end else begin
            if (s00_axi_arvalid && !s00_axi_rvalid && !s00_axi_arready) begin s00_axi_arready <= 1; ar_addr_latched <= s00_axi_araddr[6:0]; end 
            else s00_axi_arready <= 0;

            if (s00_axi_arready) begin
                s00_axi_rvalid <= 1;
                case (ar_addr_latched)
                    7'h00: s00_axi_rdata <= reg_control;      7'h04: s00_axi_rdata <= reg_status;
                    7'h08: s00_axi_rdata <= reg_window_len;   7'h0C: s00_axi_rdata <= N_IN;
                    7'h10: s00_axi_rdata <= N_HIDDEN;         7'h14: s00_axi_rdata <= N_OUT;
                    7'h18: s00_axi_rdata <= reg_result_class; 7'h1C: s00_axi_rdata <= reg_count0;
                    7'h20: s00_axi_rdata <= reg_count1;       7'h24: s00_axi_rdata <= reg_count2;
                    7'h28: s00_axi_rdata <= reg_conf;         7'h2C: s00_axi_rdata <= reg_latency;
                    7'h30: s00_axi_rdata <= reg_debug0;       7'h34: s00_axi_rdata <= reg_debug1;
                    default: s00_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end
            if (s00_axi_rvalid && s00_axi_rready) s00_axi_rvalid <= 0;
        end
    end

    // --- Spike buffer ---
    reg [N_IN-1:0] spike_buf [0:W_LEN_MAX-1];
    reg [5:0] recv_cnt;

    // --- Block RAMs (Synchronous read) ---
    (* ram_style = "block" *) reg signed [7:0] w1_bram [0:N_IN*N_HIDDEN-1];
    (* ram_style = "block" *) reg signed [7:0] w2_bram [0:N_HIDDEN*N_OUT-1];
    
    initial begin
        $readmemh("C:/fpga_work/rtl/w1.mem", w1_bram);
        $readmemh("C:/fpga_work/rtl/w2.mem", w2_bram);
    end

    reg [15:0] w1_addr, w2_addr;
    reg signed [7:0] w1_dout, w2_dout;
    always @(posedge s00_axi_aclk) begin
        w1_dout <= w1_bram[w1_addr];
        w2_dout <= w2_bram[w2_addr];
    end

    // --- Neuron State ---
    reg signed [15:0] vh [0:N_HIDDEN-1];
    reg signed [15:0] vo [0:N_OUT-1];
    reg [15:0] out_count [0:N_OUT-1];
    reg [N_HIDDEN-1:0] h_spikes;

    // --- FSM ---
    localparam [2:0] S_IDLE = 3'd0, S_RECV = 3'd1, S_HIDDEN = 3'd2,
                     S_OUTPUT = 3'd3, S_NEXT_T = 3'd4, S_DONE = 3'd5;

    reg [2:0]  state;
    reg [5:0]  t_idx, neuron_idx, hn_idx;
    reg [15:0] ch_idx, out_neuron_idx;
    reg signed [15:0] acc;
    reg [31:0] cycle_cnt, total_h_spikes;
    
    reg [1:0] read_phase; // Pipeline state

    assign s_axis_tready = (state == S_RECV);
    wire stream_accept = (state == S_RECV) && s_axis_tvalid;
    integer i;

    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            state <= S_IDLE; reg_control <= 0; reg_status <= 0; reg_window_len <= 32'd10; reg_result_class <= 0;
            reg_count0 <= 0; reg_count1 <= 0; reg_count2 <= 0; reg_conf <= 0; reg_latency <= 0; reg_debug0 <= 0; reg_debug1 <= 0;
            recv_cnt <= 0; t_idx <= 0; neuron_idx <= 0; ch_idx <= 0; acc <= 0; read_phase <= 0;
            h_spikes <= 0; out_neuron_idx <= 0; hn_idx <= 0; cycle_cnt <= 0; total_h_spikes <= 0;
            w1_addr <= 0; w2_addr <= 0;
            for (i=0; i<N_HIDDEN; i=i+1) vh[i] <= 0;
            for (i=0; i<N_OUT; i=i+1) begin vo[i] <= 0; out_count[i] <= 0; end
        end else begin

            // Latency Timer: Only count when actually processing or actively receiving
            if (state != S_IDLE && state != S_DONE) begin
                if (state == S_RECV && recv_cnt == 0 && !s_axis_tvalid) begin
                    // Do nothing. Wait for the first DMA packet to arrive.
                end else begin
                    cycle_cnt <= cycle_cnt + 1;
                end
            end

            // AXI-Lite Command
            if (wr_fire && aw_addr_latched == 7'h00) begin
                reg_control <= w_data_latched;
                if (w_data_latched[1]) begin // RESET
                    state <= S_IDLE; reg_status <= 0; recv_cnt <= 0; t_idx <= 0; cycle_cnt <= 0; total_h_spikes <= 0;
                    reg_debug0 <= 0; reg_debug1 <= 0; h_spikes <= 0; read_phase <= 0;
                    for (i=0; i<N_HIDDEN; i=i+1) vh[i] <= 0;
                    for (i=0; i<N_OUT; i=i+1) begin vo[i] <= 0; out_count[i] <= 0; end
                end
                else if (w_data_latched[0] && state == S_IDLE) begin // START
                    state <= S_RECV; reg_status <= 32'h2; recv_cnt <= 0; t_idx <= 0; cycle_cnt <= 0; total_h_spikes <= 0; h_spikes <= 0; read_phase <= 0;
                    for (i=0; i<N_HIDDEN; i=i+1) vh[i] <= 0;
                    for (i=0; i<N_OUT; i=i+1) begin vo[i] <= 0; out_count[i] <= 0; end
                end
            end
            if (wr_fire && aw_addr_latched == 7'h08) reg_window_len <= w_data_latched;

            // FSM
            case (state)
                S_IDLE: begin end
                
                S_RECV: begin
                    if (stream_accept) begin
                        spike_buf[recv_cnt] <= s_axis_tdata[N_IN-1:0];
                        recv_cnt <= recv_cnt + 1;
                        if ((recv_cnt + 1) >= reg_window_len[5:0] || s_axis_tlast) begin
                            reg_debug0 <= {26'd0, recv_cnt + 6'd1};
                            state <= S_HIDDEN; t_idx <= 0; neuron_idx <= 0; ch_idx <= 0; acc <= 0; read_phase <= 0;
                        end
                    end
                end

                S_HIDDEN: begin
                    if (ch_idx < N_IN) begin
                        // 3-Stage Pipeline for robust BRAM reads
                        if (read_phase == 0) begin
                            w1_addr <= ch_idx * N_HIDDEN + neuron_idx;
                            read_phase <= 1;
                        end else if (read_phase == 1) begin
                            read_phase <= 2; // Wait for BRAM sync read
                        end else begin
                            if (spike_buf[t_idx][ch_idx]) acc <= acc + w1_dout;
                            ch_idx <= ch_idx + 1;
                            read_phase <= 0;
                        end
                    end else begin
                        begin : hidden_update_blk
                            reg signed [15:0] v_leaked, v_new;
                            v_leaked = vh[neuron_idx] - ($signed(vh[neuron_idx]) >>> LEAK_H);
                            v_new    = v_leaked + acc;
                            if (v_new >= TH_H) begin
                                vh[neuron_idx] <= 16'sd0; h_spikes[neuron_idx] <= 1'b1; total_h_spikes <= total_h_spikes + 1;
                            end else begin
                                vh[neuron_idx] <= v_new; h_spikes[neuron_idx] <= 1'b0;
                            end
                        end
                        if (neuron_idx + 1 < N_HIDDEN) begin
                            neuron_idx <= neuron_idx + 1; ch_idx <= 0; acc <= 0;
                        end else begin
                            state <= S_OUTPUT; out_neuron_idx <= 0; hn_idx <= 0; acc <= 0; read_phase <= 0;
                        end
                    end
                end

                S_OUTPUT: begin
                    if (hn_idx < N_HIDDEN) begin
                        if (read_phase == 0) begin
                            w2_addr <= hn_idx * N_OUT + out_neuron_idx;
                            read_phase <= 1;
                        end else if (read_phase == 1) begin
                            read_phase <= 2;
                        end else begin
                            if (h_spikes[hn_idx]) acc <= acc + w2_dout;
                            hn_idx <= hn_idx + 1;
                            read_phase <= 0;
                        end
                    end else begin
                        begin : output_update_blk
                            reg signed [15:0] v_leaked, v_new;
                            v_leaked = vo[out_neuron_idx] - ($signed(vo[out_neuron_idx]) >>> LEAK_O);
                            v_new    = v_leaked + acc;
                            if (v_new >= TH_O) begin
                                vo[out_neuron_idx] <= 16'sd0; out_count[out_neuron_idx] <= out_count[out_neuron_idx] + 1;
                            end else vo[out_neuron_idx] <= v_new;
                        end
                        if (out_neuron_idx + 1 < N_OUT) begin
                            out_neuron_idx <= out_neuron_idx + 1; hn_idx <= 0; acc <= 0;
                        end else state <= S_NEXT_T;
                    end
                end

                S_NEXT_T: begin
                    h_spikes <= 0;
                    if (t_idx + 1 < reg_window_len[5:0]) begin
                        t_idx <= t_idx + 1; neuron_idx <= 0; ch_idx <= 0; acc <= 0; state <= S_HIDDEN; read_phase <= 0;
                    end else state <= S_DONE;
                end

                S_DONE: begin
                    if (out_count[0] >= out_count[1] && out_count[0] >= out_count[2]) reg_result_class <= 32'd0;
                    else if (out_count[1] >= out_count[2]) reg_result_class <= 32'd1;
                    else reg_result_class <= 32'd2;

                    reg_count0 <= {16'd0, out_count[0]}; reg_count1 <= {16'd0, out_count[1]}; reg_count2 <= {16'd0, out_count[2]};
                    reg_latency <= cycle_cnt; reg_debug1 <= total_h_spikes; reg_status <= 32'h1; reg_conf <= 32'd0;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule