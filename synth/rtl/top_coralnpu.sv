// top_coralnpu.sv —— S2C Dual Virtex-7 TAI LM（F1 片）上板顶层
//
// 结构：
//   clk_p/clk_n（OSC1，默认差分 LVDS）→ IBUFDS → MMCME2_BASE → BUFG → clk_core
//   rst_btn_n（SW1，按下=0）& mmcm_locked → 复位同步器 → core/FSM 复位
//   host_cmd_fsm + uart_rx/uart_tx（RS232 J26）→ 驱动 CoreMiniAxi 的 s_axi（程序加载/CSR/回读）
//   CoreMiniAxi 的 m_axi → axi_master_stub（防 core 外部访问挂死）
//   LED40/41/42 显示 halted / fault / mmcm_locked
//
// 器件：xc7v2000tflg1925-1（F1）
// 引脚映射（见 synth/xdc/top_coralnpu.xdc 与 board-notes.md）：
//   s2cclk_1: L4(P)/L3(N)（100MHz 差分，JG1/JG2）；SW1: AP31（低有效）；
//   子板 UART: uart_rx=AV42、uart_tx=AU42（1.8V，硬件工程师 2026-08-20）；
//   LED40: K25（halted）；LED41: K28（fault）；LED42: J28（locked）
//
// 时钟参数（2026-08-20 已确认：时钟源 = s2cclk_1 L4/L3 100MHz，OSC1 W4/W3 48MHz 已废弃）：
//   CLK_IN_HZ  = 时钟输入频率（100MHz，L4/L3 s2cclk_1）
//   CORE_CLK_HZ = MMCM 输出频率（默认 40MHz，同时是 UART 波特率基准）
//   MMCM 比例：CLK_IN × MMCM_MULT / MMCM_DIVCLK / MMCM_OUT_DIV = CORE_CLK
module top_coralnpu #(
    parameter int  CLK_IN_HZ   = 100_000_000,   // s2cclk_1 (L4/L3) 100MHz 输入
    parameter int  CORE_CLK_HZ = 40_000_000,    // MMCM 输出频率（40MHz：在 xc7v2000t -1
                                                //   上给时序留出裕量；50MHz 有 -0.15ns 违例，
                                                //   见 synth-notes T010）
    parameter int  BAUD        = 115200,        // RS232 波特率
    parameter bit  USE_DIFF_CLK = 1'b1,         // 1=差分 LVDS(IBUFDS) 0=单端(IBUF)
    parameter bit  USE_MMCM     = 1'b1          // 1=MMCM 时钟树；0=clk_p 直连（仿真/调试用，
                                                //   clk_core = clk_p，mmcm_locked 恒 1）
)(
    // ---- 时钟：OSC1 ----
    input  logic clk_p,
    input  logic clk_n,
    // ---- 复位：SW1（按下=0） ----
    input  logic rst_btn_n,
    // ---- RS232 J26 ----
    input  logic uart_rx,       // PC→FPGA（F20）
    output logic uart_tx,       // FPGA→PC（E20）
    // ---- 测试区 LED（输出 H 点亮） ----
    output logic led_halted,    // LED40（K25）
    output logic led_fault,     // LED41（K28）
    output logic led_locked     // LED42（J28）
);
    // ==================== 时钟树 ====================
    logic clk_ref;          // 输入时钟（IBUFDS/IBUF 后）
    logic clk_fb;           // MMCM 反馈（BUFG 前）
    logic clk_fb_buf;       // MMCM 反馈（BUFG 后）
    logic clk_mmcm_out;     // MMCM CLKOUT0（BUFG 前）
    logic clk_core;         // 全局核心时钟（BUFG 后）
    logic mmcm_locked;

    generate
        if (USE_MMCM) begin : g_mmcm
            if (USE_DIFF_CLK) begin : g_clk_diff
                IBUFDS #(
                    .DIFF_TERM    ("TRUE"),
                    .IOSTANDARD   ("LVDS")
                ) u_ibuf_clk (
                    .I  (clk_p),
                    .IB (clk_n),
                    .O  (clk_ref)
                );
            end else begin : g_clk_se
                IBUF u_ibuf_clk (
                    .I (clk_p),
                    .O (clk_ref)
                );
            end

            MMCME2_BASE #(
                .BANDWIDTH          ("OPTIMIZED"),
                .CLKFBOUT_MULT_F    (12.0),             // 100MHz×12/1/30 = 40MHz
                .CLKFBOUT_PHASE     (0.0),
                .CLKIN1_PERIOD      (10.0),             // 对应 100MHz 假定输入
                .CLKOUT0_DIVIDE_F   (30.0),
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
            // 仿真/调试：clk_p 直连作为核心时钟，mmcm_locked 恒 1
            assign mmcm_locked = 1'b1;
            BUFG u_bufg_core (.I(clk_p), .O(clk_core));
        end
    endgenerate

    // ==================== 复位 ====================
    // SW1 按下=0；mmcm_locked 前保持复位。异步置位、同步释放。
    logic rst_unsync_n;
    logic [2:0] rst_ff;
    assign rst_unsync_n = rst_btn_n & mmcm_locked;
    always_ff @(posedge clk_core or negedge rst_unsync_n) begin
        if (!rst_unsync_n) begin
            rst_ff <= 3'b0;
        end else begin
            rst_ff <= {rst_ff[1:0], 1'b1};
        end
    end
    logic rst_n;
    assign rst_n = rst_ff[2];

    // ==================== 实例化 ====================
    // ---- UART ----
    logic       uart_rx_valid;
    logic [7:0] uart_rx_data;
    logic       uart_tx_valid;
    logic [7:0] uart_tx_data;
    logic       uart_tx_busy;

    uart_rx #(
        .CLK_HZ (CORE_CLK_HZ),
        .BAUD   (BAUD)
    ) u_uart_rx (
        .clk      (clk_core),
        .rst_n    (rst_n),
        .rx_in    (uart_rx),
        .rx_valid (uart_rx_valid),
        .rx_data  (uart_rx_data),
        .rx_busy  ()
    );

    uart_tx #(
        .CLK_HZ (CORE_CLK_HZ),
        .BAUD   (BAUD)
    ) u_uart_tx (
        .clk      (clk_core),
        .rst_n    (rst_n),
        .tx_valid (uart_tx_valid),
        .tx_data  (uart_tx_data),
        .tx_busy  (uart_tx_busy),
        .tx_out   (uart_tx)
    );

    // ---- 主机命令 FSM（AXI master → core s_axi） ----
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
        .clk       (clk_core),
        .rst_n     (rst_n),
        .rx_valid  (uart_rx_valid),
        .rx_data   (uart_rx_data),
        .tx_valid  (uart_tx_valid),
        .tx_data   (uart_tx_data),
        .tx_busy   (uart_tx_busy),
        .s_awvalid (s_awvalid),
        .s_awready (s_awready),
        .s_awaddr  (s_awaddr),
        .s_awid    (s_awid),
        .s_awlen   (s_awlen),
        .s_awsize  (s_awsize),
        .s_awburst (s_awburst),
        .s_awcache (s_awcache),
        .s_awqos   (s_awqos),
        .s_awregion(s_awregion),
        .s_awprot  (s_awprot),
        .s_wvalid  (s_wvalid),
        .s_wready  (s_wready),
        .s_wdata   (s_wdata),
        .s_wstrb   (s_wstrb),
        .s_wlast   (s_wlast),
        .s_bvalid  (s_bvalid),
        .s_bready  (s_bready),
        .s_bid     (s_bid),
        .s_bresp   (s_bresp),
        .s_arvalid (s_arvalid),
        .s_arready (s_arready),
        .s_araddr  (s_araddr),
        .s_arid    (s_arid),
        .s_arlen   (s_arlen),
        .s_arsize  (s_arsize),
        .s_arburst (s_arburst),
        .s_arcache (s_arcache),
        .s_arqos   (s_arqos),
        .s_arregion(s_arregion),
        .s_arprot  (s_arprot),
        .s_rvalid  (s_rvalid),
        .s_rready  (s_rready),
        .s_rdata   (s_rdata),
        .s_rid     (s_rid),
        .s_rresp   (s_rresp),
        .s_rlast   (s_rlast)
    );

    // ---- CoreMiniAxi（bazel 生成，不改动） ----
    logic core_halted, core_fault, core_wfi;
    logic m_awvalid, m_awready;
    logic [31:0] m_awaddr;
    logic [5:0]  m_awid;
    logic [7:0]  m_awlen;
    logic [1:0]  m_awburst;
    logic m_wvalid, m_wready;
    logic [127:0] m_wdata;
    logic [15:0]  m_wstrb;
    logic m_wlast;
    logic m_bvalid, m_bready;
    logic [5:0]  m_bid;
    logic [1:0]  m_bresp;
    logic m_arvalid, m_arready;
    logic [31:0] m_araddr;
    logic [5:0]  m_arid;
    logic [7:0]  m_arlen;
    logic [1:0]  m_arburst;
    logic m_rvalid, m_rready;
    logic [127:0] m_rdata;
    logic [5:0]  m_rid;
    logic [1:0]  m_rresp;
    logic m_rlast;

    CoreMiniAxi u_core (
        .io_aclk                        (clk_core),
        .io_aresetn                     (rst_n),
        // ---- s_axi（host → core） ----
        .io_axi_slave_write_addr_ready  (s_awready),
        .io_axi_slave_write_addr_valid  (s_awvalid),
        .io_axi_slave_write_addr_bits_addr (s_awaddr),
        .io_axi_slave_write_addr_bits_prot (s_awprot),
        .io_axi_slave_write_addr_bits_id   (s_awid),
        .io_axi_slave_write_addr_bits_len  (s_awlen),
        .io_axi_slave_write_addr_bits_size (s_awsize),
        .io_axi_slave_write_addr_bits_burst(s_awburst),
        .io_axi_slave_write_addr_bits_lock (1'b0),
        .io_axi_slave_write_addr_bits_cache(s_awcache),
        .io_axi_slave_write_addr_bits_qos  (s_awqos),
        .io_axi_slave_write_addr_bits_region(s_awregion),
        .io_axi_slave_write_data_ready  (s_wready),
        .io_axi_slave_write_data_valid  (s_wvalid),
        .io_axi_slave_write_data_bits_data (s_wdata),
        .io_axi_slave_write_data_bits_last (s_wlast),
        .io_axi_slave_write_data_bits_strb (s_wstrb),
        .io_axi_slave_write_resp_ready  (s_bready),
        .io_axi_slave_write_resp_valid  (s_bvalid),
        .io_axi_slave_write_resp_bits_id  (s_bid),
        .io_axi_slave_write_resp_bits_resp(s_bresp),
        .io_axi_slave_read_addr_ready   (s_arready),
        .io_axi_slave_read_addr_valid   (s_arvalid),
        .io_axi_slave_read_addr_bits_addr  (s_araddr),
        .io_axi_slave_read_addr_bits_prot  (s_arprot),
        .io_axi_slave_read_addr_bits_id    (s_arid),
        .io_axi_slave_read_addr_bits_len   (s_arlen),
        .io_axi_slave_read_addr_bits_size  (s_arsize),
        .io_axi_slave_read_addr_bits_burst (s_arburst),
        .io_axi_slave_read_addr_bits_lock  (1'b0),
        .io_axi_slave_read_addr_bits_cache (s_arcache),
        .io_axi_slave_read_addr_bits_qos   (s_arqos),
        .io_axi_slave_read_addr_bits_region(s_arregion),
        .io_axi_slave_read_data_ready   (s_rready),
        .io_axi_slave_read_data_valid   (s_rvalid),
        .io_axi_slave_read_data_bits_data (s_rdata),
        .io_axi_slave_read_data_bits_id   (s_rid),
        .io_axi_slave_read_data_bits_resp (s_rresp),
        .io_axi_slave_read_data_bits_last (s_rlast),
        // ---- m_axi（core → 外部，接到响应桩） ----
        .io_axi_master_write_addr_ready (m_awready),
        .io_axi_master_write_addr_valid (m_awvalid),
        .io_axi_master_write_addr_bits_addr (m_awaddr),
        .io_axi_master_write_addr_bits_prot (),
        .io_axi_master_write_addr_bits_id   (m_awid),
        .io_axi_master_write_addr_bits_len  (m_awlen),
        .io_axi_master_write_addr_bits_size (),
        .io_axi_master_write_addr_bits_burst(m_awburst),
        .io_axi_master_write_addr_bits_lock (),
        .io_axi_master_write_addr_bits_cache(),
        .io_axi_master_write_addr_bits_qos  (),
        .io_axi_master_write_addr_bits_region(),
        .io_axi_master_write_data_ready  (m_wready),
        .io_axi_master_write_data_valid  (m_wvalid),
        .io_axi_master_write_data_bits_data (m_wdata),
        .io_axi_master_write_data_bits_last (m_wlast),
        .io_axi_master_write_data_bits_strb (m_wstrb),
        .io_axi_master_write_resp_ready  (m_bready),
        .io_axi_master_write_resp_valid  (m_bvalid),
        .io_axi_master_write_resp_bits_id  (m_bid),
        .io_axi_master_write_resp_bits_resp(m_bresp),
        .io_axi_master_read_addr_ready   (m_arready),
        .io_axi_master_read_addr_valid   (m_arvalid),
        .io_axi_master_read_addr_bits_addr  (m_araddr),
        .io_axi_master_read_addr_bits_prot  (),
        .io_axi_master_read_addr_bits_id    (m_arid),
        .io_axi_master_read_addr_bits_len   (m_arlen),
        .io_axi_master_read_addr_bits_size  (),
        .io_axi_master_read_addr_bits_burst (m_arburst),
        .io_axi_master_read_addr_bits_lock  (),
        .io_axi_master_read_addr_bits_cache (),
        .io_axi_master_read_addr_bits_qos   (),
        .io_axi_master_read_addr_bits_region(),
        .io_axi_master_read_data_ready   (m_rready),
        .io_axi_master_read_data_valid   (m_rvalid),
        .io_axi_master_read_data_bits_data (m_rdata),
        .io_axi_master_read_data_bits_id   (m_rid),
        .io_axi_master_read_data_bits_resp (m_rresp),
        .io_axi_master_read_data_bits_last (m_rlast),
        // ---- 控制/状态 ----
        .io_halted                      (core_halted),
        .io_fault                       (core_fault),
        .io_wfi                         (core_wfi),
        .io_irq                         (1'b0),
        .io_boot_addr                   (32'h0),
        .io_timer_irq                   (1'b0),
        .io_software_irq                (1'b0),
        // ---- debug（输出，悬空） ----
        .io_debug_en                    (),
        .io_debug_addr_0                (), .io_debug_addr_1 (), .io_debug_addr_2 (), .io_debug_addr_3 (),
        .io_debug_inst_0                (), .io_debug_inst_1 (), .io_debug_inst_2 (), .io_debug_inst_3 (),
        .io_debug_cycles                (),
        .io_debug_dbus_valid            (),
        .io_debug_dbus_bits_addr        (),
        .io_debug_dbus_bits_wdata       (),
        .io_debug_dbus_bits_write       (),
        .io_debug_dispatch_0_instFire   (), .io_debug_dispatch_0_instAddr (), .io_debug_dispatch_0_instInst (),
        .io_debug_dispatch_1_instFire   (), .io_debug_dispatch_1_instAddr (), .io_debug_dispatch_1_instInst (),
        .io_debug_dispatch_2_instFire   (), .io_debug_dispatch_2_instAddr (), .io_debug_dispatch_2_instInst (),
        .io_debug_dispatch_3_instFire   (), .io_debug_dispatch_3_instAddr (), .io_debug_dispatch_3_instInst (),
        .io_debug_regfile_writeAddr_0_valid (), .io_debug_regfile_writeAddr_0_bits (),
        .io_debug_regfile_writeAddr_1_valid (), .io_debug_regfile_writeAddr_1_bits (),
        .io_debug_regfile_writeAddr_2_valid (), .io_debug_regfile_writeAddr_2_bits (),
        .io_debug_regfile_writeAddr_3_valid (), .io_debug_regfile_writeAddr_3_bits (),
        .io_debug_regfile_writeData_0_valid (), .io_debug_regfile_writeData_0_bits_addr (), .io_debug_regfile_writeData_0_bits_data (),
        .io_debug_regfile_writeData_1_valid (), .io_debug_regfile_writeData_1_bits_addr (), .io_debug_regfile_writeData_1_bits_data (),
        .io_debug_regfile_writeData_2_valid (), .io_debug_regfile_writeData_2_bits_addr (), .io_debug_regfile_writeData_2_bits_data (),
        .io_debug_regfile_writeData_3_valid (), .io_debug_regfile_writeData_3_bits_addr (), .io_debug_regfile_writeData_3_bits_data (),
        .io_debug_regfile_writeData_4_valid (), .io_debug_regfile_writeData_4_bits_addr (), .io_debug_regfile_writeData_4_bits_data (),
        .io_debug_regfile_writeData_5_valid (), .io_debug_regfile_writeData_5_bits_addr (), .io_debug_regfile_writeData_5_bits_data (),
        .io_debug_float_writeAddr_valid (), .io_debug_float_writeAddr_bits (),
        .io_debug_float_writeData_0_valid (), .io_debug_float_writeData_0_bits_addr (), .io_debug_float_writeData_0_bits_data (),
        .io_debug_float_writeData_1_valid (), .io_debug_float_writeData_1_bits_addr (), .io_debug_float_writeData_1_bits_data (),
        .io_debug_rb_inst_0_valid (), .io_debug_rb_inst_0_bits_pc (), .io_debug_rb_inst_0_bits_inst (), .io_debug_rb_inst_0_bits_idx (), .io_debug_rb_inst_0_bits_data (), .io_debug_rb_inst_0_bits_trap (),
        .io_debug_rb_inst_1_valid (), .io_debug_rb_inst_1_bits_pc (), .io_debug_rb_inst_1_bits_inst (), .io_debug_rb_inst_1_bits_idx (), .io_debug_rb_inst_1_bits_data (), .io_debug_rb_inst_1_bits_trap (),
        .io_debug_rb_inst_2_valid (), .io_debug_rb_inst_2_bits_pc (), .io_debug_rb_inst_2_bits_inst (), .io_debug_rb_inst_2_bits_idx (), .io_debug_rb_inst_2_bits_data (), .io_debug_rb_inst_2_bits_trap (),
        .io_debug_rb_inst_3_valid (), .io_debug_rb_inst_3_bits_pc (), .io_debug_rb_inst_3_bits_inst (), .io_debug_rb_inst_3_bits_idx (), .io_debug_rb_inst_3_bits_data (), .io_debug_rb_inst_3_bits_trap (),
        .io_debug_rb_inst_4_valid (), .io_debug_rb_inst_4_bits_pc (), .io_debug_rb_inst_4_bits_inst (), .io_debug_rb_inst_4_bits_idx (), .io_debug_rb_inst_4_bits_data (), .io_debug_rb_inst_4_bits_trap (),
        .io_debug_rb_inst_5_valid (), .io_debug_rb_inst_5_bits_pc (), .io_debug_rb_inst_5_bits_inst (), .io_debug_rb_inst_5_bits_idx (), .io_debug_rb_inst_5_bits_data (), .io_debug_rb_inst_5_bits_trap (),
        .io_debug_rb_inst_6_valid (), .io_debug_rb_inst_6_bits_pc (), .io_debug_rb_inst_6_bits_inst (), .io_debug_rb_inst_6_bits_idx (), .io_debug_rb_inst_6_bits_data (), .io_debug_rb_inst_6_bits_trap (),
        .io_debug_rb_inst_7_valid (), .io_debug_rb_inst_7_bits_pc (), .io_debug_rb_inst_7_bits_inst (), .io_debug_rb_inst_7_bits_idx (), .io_debug_rb_inst_7_bits_data (), .io_debug_rb_inst_7_bits_trap (),
        .io_dm_req_ready                (),
        .io_dm_req_valid                (1'b0),
        .io_dm_req_bits_address         (32'h0),
        .io_dm_req_bits_data            (32'h0),
        .io_dm_req_bits_op              (2'b0),
        .io_dm_rsp_ready                (1'b0),
        .io_dm_rsp_valid                (),
        .io_dm_rsp_bits_data            (),
        .io_dm_rsp_bits_op              (),
        .io_te                          (1'b0)
    );

    // ---- m_axi 响应桩 ----
    axi_master_stub u_mstub (
        .clk        (clk_core),
        .rst_n      (rst_n),
        .m_awvalid  (m_awvalid),
        .m_awready  (m_awready),
        .m_awaddr   (m_awaddr),
        .m_awid     (m_awid),
        .m_awlen    (m_awlen),
        .m_awburst  (m_awburst),
        .m_wvalid   (m_wvalid),
        .m_wready   (m_wready),
        .m_wdata    (m_wdata),
        .m_wstrb    (m_wstrb),
        .m_wlast    (m_wlast),
        .m_bvalid   (m_bvalid),
        .m_bready   (m_bready),
        .m_bid      (m_bid),
        .m_bresp    (m_bresp),
        .m_arvalid  (m_arvalid),
        .m_arready  (m_arready),
        .m_araddr   (m_araddr),
        .m_arid     (m_arid),
        .m_arlen    (m_arlen),
        .m_arburst  (m_arburst),
        .m_rvalid   (m_rvalid),
        .m_rready   (m_rready),
        .m_rdata    (m_rdata),
        .m_rid      (m_rid),
        .m_rresp    (m_rresp),
        .m_rlast    (m_rlast)
    );

    // ==================== LED ====================
    assign led_halted = core_halted;
    assign led_fault  = core_fault;
    assign led_locked = mmcm_locked;
endmodule
