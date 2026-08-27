// =============================================================================
// top_coralnpu_soc.sv —— T022 标量 SoC 顶层
//
//   host_cmd_fsm（UART 命令解析，AXI master）→ CoralNPUChiselSubsystem.io_uart_host_axi
//   （SoC 内 Axi2TLUL → Xbar → 核 tl_device/外设，加载程序 + 回读）
//
//   时钟：clk_p/clk_n（OSC1，100MHz 差分）→ IBUFDS → MMCME2_BASE → BUFG → clk_core（20MHz）
//   UART：RS232 J26（115200 8N1）
//   LED：led_halted/led_fault/led_locked（测试区）+ gpio_led[2:0]（小板 J8，host L 命令）
// =============================================================================
module top_coralnpu_soc #(
    parameter int  CORE_CLK_HZ = 20_000_000,    // MMCM 输出（20MHz：时序完全收敛，M3 默认）
    parameter int  BAUD        = 115200,
    parameter bit  USE_DIFF_CLK = 1'b1,
    parameter bit  USE_MMCM     = 1'b1
)(
    // ---- 时钟：OSC1 ----
    input  logic clk_p,
    input  logic clk_n,
    // ---- 复位：SW1（按下=0） ----
    input  logic rst_btn_n,
    // ---- RS232 J26 ----
    input  logic uart_rx,
    output logic uart_tx,
    // ---- 测试区 LED ----
    output logic led_halted,
    output logic led_fault,
    output logic led_locked,
    // ---- GPIO LED（小板 J8 AH44/AH43/AL40，T020 L 命令） ----
    output logic [2:0] gpio_led
);
    // ==================== 时钟树 ====================
    logic clk_ref, clk_fb, clk_fb_buf, clk_mmcm_out, clk_core, mmcm_locked;
    logic clk_p_buf;
    parameter logic [31:0] CLKIN_PERIOD_NS = 10.0;

    if (USE_DIFF_CLK) begin : g_diff
        IBUFDS u_ibufds (
            .I  (clk_p),
            .IB (clk_n),
            .O  (clk_p_buf)
        );
        assign clk_ref = clk_p_buf;
    end else begin : g_single
        assign clk_ref = clk_p;
    end

    if (USE_MMCM) begin : g_mmcm
        MMCME2_BASE #(
            .BANDWIDTH          ("OPTIMIZED"),
            .CLKFBOUT_MULT_F    (12.0),             // 100MHz×12/1/60 = 20MHz
            .CLKFBOUT_PHASE     (0.0),
            .CLKIN1_PERIOD      (10.0),
            .CLKOUT0_DIVIDE_F   (60.0),
            .CLKOUT0_DUTY_CYCLE (0.5),
            .CLKOUT0_PHASE      (0.0),
            .CLKOUT1_DIVIDE     (1.0),
            .CLKOUT1_DUTY_CYCLE (0.5),
            .CLKOUT1_PHASE      (0.0),
            .CLKOUT2_DIVIDE     (1.0),
            .CLKOUT2_DUTY_CYCLE (0.5),
            .CLKOUT2_PHASE      (0.0),
            .CLKOUT3_DIVIDE     (1.0),
            .CLKOUT3_DUTY_CYCLE (0.5),
            .CLKOUT3_PHASE      (0.0),
            .CLKOUT4_DIVIDE     (1.0),
            .CLKOUT4_DUTY_CYCLE (0.5),
            .CLKOUT4_PHASE      (0.0),
            .CLKOUT5_DIVIDE     (1.0),
            .CLKOUT5_DUTY_CYCLE (0.5),
            .CLKOUT5_PHASE      (0.0),
            .CLKOUT6_DIVIDE     (1.0),
            .CLKOUT6_DUTY_CYCLE (0.5),
            .CLKOUT6_PHASE      (0.0),
            .DIVCLK_DIVIDE      (1),
            .REF_JITTER1        (0.010),
            .STARTUP_WAIT       ("FALSE")
        ) u_mmcm (
            .CLKOUT0   (clk_mmcm_out),
            .CLKOUT0B  (),
            .CLKOUT1   (),
            .CLKOUT1B  (),
            .CLKOUT2   (),
            .CLKOUT2B  (),
            .CLKOUT3   (),
            .CLKOUT3B  (),
            .CLKOUT4   (),
            .CLKOUT5   (),
            .CLKOUT6   (),
            .CLKFBOUT  (clk_fb),
            .CLKFBOUTB (),
            .LOCKED    (mmcm_locked),
            .CLKIN1    (clk_ref),
            .PWRDWN    (1'b0),
            .RST       (1'b0),
            .CLKFBIN   (clk_fb_buf)
        );
        BUFG u_bufg_fb   (.I(clk_fb),       .O(clk_fb_buf));
        BUFG u_bufg_core (.I(clk_mmcm_out), .O(clk_core));
    end else begin : g_direct
        // 仿真/调试：clk_p 直连（不经 IBUFDS，避免仿真模型问题），mmcm_locked 恒 1
        assign mmcm_locked = 1'b1;
        BUFG u_bufg_core (.I(clk_p), .O(clk_core));
    end

    // ==================== 复位 ====================
    logic rst_unsync_n;
    logic [2:0] rst_ff;
    assign rst_unsync_n = rst_btn_n & mmcm_locked;
    always_ff @(posedge clk_core or negedge rst_unsync_n) begin
        if (!rst_unsync_n) rst_ff <= 3'b0;
        else              rst_ff <= {rst_ff[1:0], 1'b1};
    end
    logic rst_n;
    assign rst_n = rst_ff[2];

    // ==================== UART + host_cmd_fsm（AXI master） ====================
    logic       uart_rx_valid;
    logic [7:0] uart_rx_data;
    logic       uart_tx_valid;
    logic [7:0] uart_tx_data;
    logic       uart_tx_busy;

    uart_rx #(.CLK_HZ(CORE_CLK_HZ), .BAUD(BAUD)) u_uart_rx (
        .clk(clk_core), .rst_n(rst_n), .rx_in(uart_rx),
        .rx_valid(uart_rx_valid), .rx_data(uart_rx_data), .rx_busy()
    );
    uart_tx #(.CLK_HZ(CORE_CLK_HZ), .BAUD(BAUD)) u_uart_tx (
        .clk(clk_core), .rst_n(rst_n),
        .tx_valid(uart_tx_valid), .tx_data(uart_tx_data),
        .tx_busy(uart_tx_busy), .tx_out(uart_tx)
    );

    // host AXI master（→ SoC uart_host_axi）
    logic        s_awvalid, s_awready;
    logic [31:0] s_awaddr;
    logic [5:0]  s_awid;
    logic [7:0]  s_awlen;
    logic [2:0]  s_awsize;
    logic [1:0]  s_awburst;
    logic [3:0]  s_awcache, s_awqos, s_awregion;
    logic [2:0]  s_awprot;
    logic        s_wvalid, s_wready;
    logic [127:0] s_wdata;
    logic [15:0]  s_wstrb;
    logic        s_wlast;
    logic        s_bvalid, s_bready;
    logic [5:0]  s_bid;
    logic [1:0]  s_bresp;
    logic        s_arvalid, s_arready;
    logic [31:0] s_araddr;
    logic [5:0]  s_arid;
    logic [7:0]  s_arlen;
    logic [2:0]  s_arsize;
    logic [1:0]  s_arburst;
    logic [3:0]  s_arcache, s_arqos, s_arregion;
    logic [2:0]  s_arprot;
    logic        s_rvalid, s_rready;
    logic [127:0] s_rdata;
    logic [5:0]  s_rid;
    logic [1:0]  s_rresp;
    logic        s_rlast;

    host_cmd_fsm u_host (
        .clk(clk_core), .rst_n(rst_n),
        .rx_valid(uart_rx_valid), .rx_data(uart_rx_data),
        .tx_valid(uart_tx_valid), .tx_data(uart_tx_data), .tx_busy(uart_tx_busy),
        .s_awvalid(s_awvalid), .s_awready(s_awready), .s_awaddr(s_awaddr),
        .s_awid(s_awid), .s_awlen(s_awlen), .s_awsize(s_awsize), .s_awburst(s_awburst),
        .s_awcache(s_awcache), .s_awqos(s_awqos), .s_awregion(s_awregion), .s_awprot(s_awprot),
        .s_wvalid(s_wvalid), .s_wready(s_wready), .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wlast(s_wlast),
        .s_bvalid(s_bvalid), .s_bready(s_bready), .s_bid(s_bid), .s_bresp(s_bresp),
        .s_arvalid(s_arvalid), .s_arready(s_arready), .s_araddr(s_araddr),
        .s_arid(s_arid), .s_arlen(s_arlen), .s_arsize(s_arsize), .s_arburst(s_arburst),
        .s_arcache(s_arcache), .s_arqos(s_arqos), .s_arregion(s_arregion), .s_arprot(s_arprot),
        .s_rvalid(s_rvalid), .s_rready(s_rready), .s_rdata(s_rdata), .s_rid(s_rid), .s_rresp(s_rresp), .s_rlast(s_rlast),
        .led_ctrl(gpio_led)
    );

    // ==================== ROM 响应桩（TL-UL 从，error 响应） ====================
    logic        rom_a_valid, rom_a_ready;
    logic [2:0]  rom_a_bits_opcode;
    logic [1:0]  rom_a_bits_param;
    logic [3:0]  rom_a_bits_size;
    logic [9:0]  rom_a_bits_source;
    logic [31:0] rom_a_bits_address;
    logic [3:0]  rom_a_bits_mask;
    logic [31:0] rom_a_bits_data;
    logic [4:0]  rom_a_bits_user_rsvd;
    logic [3:0]  rom_a_bits_user_instr_type;
    logic [6:0]  rom_a_bits_user_cmd_intg, rom_a_bits_user_data_intg;
    logic        rom_d_valid, rom_d_ready;
    logic [2:0]  rom_d_bits_opcode;
    logic [1:0]  rom_d_bits_param;
    logic [3:0]  rom_d_bits_size;
    logic [9:0]  rom_d_bits_source;
    logic        rom_d_bits_sink;
    logic [31:0] rom_d_bits_data;
    logic [6:0]  rom_d_bits_user_rsp_intg, rom_d_bits_user_data_intg;
    logic        rom_d_bits_error;

    assign rom_a_ready = 1'b1;
    always_ff @(posedge clk_core or negedge rst_n) begin
        if (!rst_n) begin
            rom_d_valid <= 1'b0;
        end else if (rom_a_valid) begin
            rom_d_valid           <= 1'b1;
            rom_d_bits_opcode     <= (rom_a_bits_opcode == 3'd4) ? 2'd1 : 2'd0;  // Get→AccessAckData, Put→AccessAck
            rom_d_bits_param      <= 2'b0;
            rom_d_bits_size       <= rom_a_bits_size;
            rom_d_bits_source     <= rom_a_bits_source;
            rom_d_bits_sink       <= 1'b0;
            rom_d_bits_data       <= 32'h0;
            rom_d_bits_error      <= 1'b1;  // 未实现 ROM，error 响应
        end else begin
            rom_d_valid <= 1'b0;
        end
    end

    // ==================== SoC 状态/控制 ====================
    logic core_halted, core_fault;
    logic [7:0] gpio_o;

    // ==================== CoralNPUChiselSubsystem（64K/1M TCM） ====================
    CoralNPUChiselSubsystem_ITCM64KB_DTCM1024KB u_soc (
        .io_clk_i(clk_core),
        .io_rst_ni(rst_n),
        // ---- uart_host AXI（host_cmd_fsm → Axi2TLUL → Xbar） ----
        .io_uart_host_axi_write_addr_ready(s_awready),
        .io_uart_host_axi_write_addr_valid(s_awvalid),
        .io_uart_host_axi_write_addr_bits_addr(s_awaddr),
        .io_uart_host_axi_write_addr_bits_prot(s_awprot),
        .io_uart_host_axi_write_addr_bits_id(s_awid),
        .io_uart_host_axi_write_addr_bits_len(s_awlen),
        .io_uart_host_axi_write_addr_bits_size(s_awsize),
        .io_uart_host_axi_write_addr_bits_burst(s_awburst),
        .io_uart_host_axi_write_addr_bits_lock(1'b0),
        .io_uart_host_axi_write_addr_bits_cache(s_awcache),
        .io_uart_host_axi_write_addr_bits_qos(s_awqos),
        .io_uart_host_axi_write_addr_bits_region(s_awregion),
        .io_uart_host_axi_write_data_ready(s_wready),
        .io_uart_host_axi_write_data_valid(s_wvalid),
        .io_uart_host_axi_write_data_bits_data(s_wdata),
        .io_uart_host_axi_write_data_bits_last(s_wlast),
        .io_uart_host_axi_write_data_bits_strb(s_wstrb),
        .io_uart_host_axi_write_resp_ready(s_bready),
        .io_uart_host_axi_write_resp_valid(s_bvalid),
        .io_uart_host_axi_write_resp_bits_id(s_bid),
        .io_uart_host_axi_write_resp_bits_resp(s_bresp),
        .io_uart_host_axi_read_addr_ready(s_arready),
        .io_uart_host_axi_read_addr_valid(s_arvalid),
        .io_uart_host_axi_read_addr_bits_addr(s_araddr),
        .io_uart_host_axi_read_addr_bits_prot(s_arprot),
        .io_uart_host_axi_read_addr_bits_id(s_arid),
        .io_uart_host_axi_read_addr_bits_len(s_arlen),
        .io_uart_host_axi_read_addr_bits_size(s_arsize),
        .io_uart_host_axi_read_addr_bits_burst(s_arburst),
        .io_uart_host_axi_read_addr_bits_lock(1'b0),
        .io_uart_host_axi_read_addr_bits_cache(s_arcache),
        .io_uart_host_axi_read_addr_bits_qos(s_arqos),
        .io_uart_host_axi_read_addr_bits_region(s_arregion),
        .io_uart_host_axi_read_data_ready(s_rready),
        .io_uart_host_axi_read_data_valid(s_rvalid),
        .io_uart_host_axi_read_data_bits_data(s_rdata),
        .io_uart_host_axi_read_data_bits_id(s_rid),
        .io_uart_host_axi_read_data_bits_resp(s_rresp),
        .io_uart_host_axi_read_data_bits_last(s_rlast),
        // ---- 核状态/控制 ----
        .io_external_ports_halted(core_halted),
        .io_external_ports_fault(core_fault),
        .io_external_ports_wfi(),
        .io_external_ports_te(1'b0),
        .io_external_ports_boot_addr(32'h0),
        .io_external_ports_dm_req_valid(1'b0),
        .io_external_ports_dm_req_ready(),
        .io_external_ports_dm_req_bits_address(32'h0),
        .io_external_ports_dm_req_bits_data(32'h0),
        .io_external_ports_dm_req_bits_op(2'b0),
        .io_external_ports_dm_rsp_valid(),
        .io_external_ports_dm_rsp_ready(1'b0),
        .io_external_ports_dm_rsp_bits_data(),
        .io_external_ports_dm_rsp_bits_op(),
        .io_external_ports_ext_intrs(31'h0),
        .io_external_ports_gpio_en_o(),
        .io_external_ports_gpio_i(8'h0),
        .io_external_ports_gpio_o(gpio_o),
        // ---- ROM external device（响应桩） ----
        .io_external_devices_rom_a_valid(rom_a_valid),
        .io_external_devices_rom_a_ready(rom_a_ready),
        .io_external_devices_rom_a_bits_opcode(rom_a_bits_opcode),
        .io_external_devices_rom_a_bits_param(rom_a_bits_param),
        .io_external_devices_rom_a_bits_size(rom_a_bits_size),
        .io_external_devices_rom_a_bits_source(rom_a_bits_source),
        .io_external_devices_rom_a_bits_address(rom_a_bits_address),
        .io_external_devices_rom_a_bits_mask(rom_a_bits_mask),
        .io_external_devices_rom_a_bits_data(rom_a_bits_data),
        .io_external_devices_rom_a_bits_user_rsvd(rom_a_bits_user_rsvd),
        .io_external_devices_rom_a_bits_user_instr_type(rom_a_bits_user_instr_type),
        .io_external_devices_rom_a_bits_user_cmd_intg(rom_a_bits_user_cmd_intg),
        .io_external_devices_rom_a_bits_user_data_intg(rom_a_bits_user_data_intg),
        .io_external_devices_rom_d_valid(rom_d_valid),
        .io_external_devices_rom_d_ready(rom_d_ready),
        .io_external_devices_rom_d_bits_opcode(rom_d_bits_opcode),
        .io_external_devices_rom_d_bits_param(rom_d_bits_param),
        .io_external_devices_rom_d_bits_size(rom_d_bits_size),
        .io_external_devices_rom_d_bits_source(rom_d_bits_source),
        .io_external_devices_rom_d_bits_sink(rom_d_bits_sink),
        .io_external_devices_rom_d_bits_data(rom_d_bits_data),
        .io_external_devices_rom_d_bits_user_rsp_intg(rom_d_bits_user_rsp_intg),
        .io_external_devices_rom_d_bits_user_data_intg(rom_d_bits_user_data_intg),
        .io_external_devices_rom_d_bits_error(rom_d_bits_error)
    );

    // ==================== LED ====================
    assign led_halted = core_halted;
    assign led_fault  = core_fault;
    assign led_locked = mmcm_locked;
endmodule
