`timescale 1ns / 1ps

module enose_preproc (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    // AXI-Lite Slave Interface (Конфигурация от ARM)
    input  wire [7:0]  s_axi_awaddr,  // <--- КОРИГИРАНО НА [7:0]
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
    input  wire [7:0]  s_axi_araddr,  // <--- КОРИГИРАНО НА [7:0]
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // AXI-Stream Master Interface
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // ==========================================
    // НОВА РЕГИСТРОВА КАРТА (6 Сензора)
    // ==========================================
    reg [31:0] reg_ctrl;
    reg signed [31:0] base_0, base_1, base_2, base_3, base_4, base_5;
    reg signed [31:0] thr_0,  thr_1,  thr_2,  thr_3,  thr_4,  thr_5;
    reg signed [31:0] val_0,  val_1,  val_2,  val_3,  val_4,  val_5;

    reg awready, wready, bvalid;
    assign s_axi_awready = awready;
    assign s_axi_wready  = wready;
    assign s_axi_bvalid  = bvalid;
    assign s_axi_bresp   = 2'b00;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            awready <= 0; wready <= 0; bvalid <= 0; reg_ctrl <= 0;
            base_0 <= 0; base_1 <= 0; base_2 <= 0; base_3 <= 0; base_4 <= 0; base_5 <= 0;
            thr_0  <= 0; thr_1  <= 0; thr_2  <= 0; thr_3  <= 0; thr_4  <= 0; thr_5  <= 0;
            val_0  <= 0; val_1  <= 0; val_2  <= 0; val_3  <= 0; val_4  <= 0; val_5  <= 0;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && !awready && !wready) begin
                awready <= 1; wready <= 1;
                case (s_axi_awaddr[7:2])
                    6'd0:  reg_ctrl <= s_axi_wdata;
                    6'd1:  base_0   <= s_axi_wdata; // MQ135
                    6'd2:  base_1   <= s_axi_wdata; // MQ3
                    6'd3:  base_2   <= s_axi_wdata; // MQ4
                    6'd4:  base_3   <= s_axi_wdata; // VOC
                    6'd5:  base_4   <= s_axi_wdata; // TEMP
                    6'd6:  base_5   <= s_axi_wdata; // HUM
                    6'd7:  thr_0    <= s_axi_wdata;
                    6'd8:  thr_1    <= s_axi_wdata;
                    6'd9:  thr_2    <= s_axi_wdata;
                    6'd10: thr_3    <= s_axi_wdata;
                    6'd11: thr_4    <= s_axi_wdata;
                    6'd12: thr_5    <= s_axi_wdata;
                    6'd13: val_0    <= s_axi_wdata;
                    6'd14: val_1    <= s_axi_wdata;
                    6'd15: val_2    <= s_axi_wdata;
                    6'd16: val_3    <= s_axi_wdata;
                    6'd17: val_4    <= s_axi_wdata;
                    6'd18: val_5    <= s_axi_wdata;
                endcase
            end else begin
                awready <= 0; wready <= 0;
                if (reg_ctrl[0] && m_axis_tready && m_axis_tvalid) reg_ctrl[0] <= 1'b0;
            end
            if (s_axi_awvalid && s_axi_wvalid && awready && wready) bvalid <= 1;
            else if (s_axi_bready && bvalid) bvalid <= 0;
        end
    end

    assign s_axi_arready = 1'b1;
    assign s_axi_rvalid  = s_axi_arvalid;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rdata   = 32'h0;

    // ==========================================
    // ХАРДУЕРНА ЛОГИКА (6 Сензора х 2 Състояния)
    // ==========================================
    wire signed [31:0] d0 = val_0 - base_0; wire up_0 = (d0 > thr_0); wire dn_0 = (d0 < -thr_0);
    wire signed [31:0] d1 = val_1 - base_1; wire up_1 = (d1 > thr_1); wire dn_1 = (d1 < -thr_1);
    wire signed [31:0] d2 = val_2 - base_2; wire up_2 = (d2 > thr_2); wire dn_2 = (d2 < -thr_2);
    wire signed [31:0] d3 = val_3 - base_3; wire up_3 = (d3 > thr_3); wire dn_3 = (d3 < -thr_3);
    wire signed [31:0] d4 = val_4 - base_4; wire up_4 = (d4 > thr_4); wire dn_4 = (d4 < -thr_4);
    wire signed [31:0] d5 = val_5 - base_5; wire up_5 = (d5 > thr_5); wire dn_5 = (d5 < -thr_5);

    // Сглобяваме точно 12 бита за SNN мрежата!
    wire [11:0] spike_mask = {
        dn_5, up_5, // Sensor 5: Hum
        dn_4, up_4, // Sensor 4: Temp
        dn_3, up_3, // Sensor 3: VOC
        dn_2, up_2, // Sensor 2: MQ4
        dn_1, up_1, // Sensor 1: MQ3
        dn_0, up_0  // Sensor 0: MQ135
    };

    assign m_axis_tvalid = reg_ctrl[0];
    assign m_axis_tdata  = {20'd0, spike_mask};
    assign m_axis_tlast  = 1'b0;

endmodule