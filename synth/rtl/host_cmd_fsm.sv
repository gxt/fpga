// host_cmd_fsm.sv —— 主机命令 FSM（UART 字节流 → AXI4 单拍读写）
//
// 协议（ASCII，以 '\n'（或 '\r'）结束）：
//   W<8hex addr><8hex data>\n   写 32 位字到 addr
//       应答："OK\n"（OKAY）或 "ERR\n"（SLVERR/参数错误）
//   R<8hex addr><2hex count>\n  从 addr 起连续读 count（1..16）个 32 位字
//       应答：每字一行 "<8hex addr><8hex data>\n"，结尾 "OK\n"；出错 "ERR\n"
//   S\n                          启动 core 引导序列：
//       写 CSR 0x30004 = 0（PC_START）→ 写 0x30000 = 1（开时钟、保持复位）
//       → 写 0x30000 = 0（释放复位）；应答 "OK\n"/"ERR\n"
//   Q\n                          查询状态：读 CSR 0x30008（STATUS.HALTED）
//       应答 "<8hex addr><8hex data>\nOK\n"
//   ?\n                          帮助，应答 "HELP\n"
//
// AXI 侧约定（与 CoreMiniAxi s_axi 一致）：
//   - 单拍（AWLEN=0），size=2（4 字节），burst=INCR，id=0
//   - 标准 AXI 字节通道对齐：写数据放在 addr[3:0] 对应通道，读数据从对应通道提取。
//     core 的 TCM/CSR 写入路径不做地址旋转（SRAM 直接按 strb 写入）、
//     CSR 读回包也是按字节偏移固定组装，因此 AXI 标准对齐即可（见 synth-notes）。
module host_cmd_fsm (
    input  logic        clk,
    input  logic        rst_n,
    // ---- UART RX ----
    input  logic        rx_valid,
    input  logic [7:0]  rx_data,
    // ---- UART TX（tx_valid 单拍脉冲，需 !tx_busy 才接受） ----
    output logic        tx_valid,
    output logic [7:0]  tx_data,
    input  logic        tx_busy,
    // ---- AXI4 master（连接 CoreMiniAxi 的 io_axi_slave_*） ----
    output logic        s_awvalid,
    input  logic        s_awready,
    output logic [31:0] s_awaddr,
    output logic [5:0]  s_awid,
    output logic [7:0]  s_awlen,
    output logic [2:0]  s_awsize,
    output logic [1:0]  s_awburst,
    output logic [3:0]  s_awcache,
    output logic [3:0]  s_awqos,
    output logic [3:0]  s_awregion,
    output logic [2:0]  s_awprot,
    output logic        s_wvalid,
    input  logic        s_wready,
    output logic [127:0] s_wdata,
    output logic [15:0]  s_wstrb,
    output logic        s_wlast,
    input  logic        s_bvalid,
    output logic        s_bready,
    input  logic [5:0]  s_bid,
    input  logic [1:0]  s_bresp,
    output logic        s_arvalid,
    input  logic        s_arready,
    output logic [31:0] s_araddr,
    output logic [5:0]  s_arid,
    output logic [7:0]  s_arlen,
    output logic [2:0]  s_arsize,
    output logic [1:0]  s_arburst,
    output logic [3:0]  s_arcache,
    output logic [3:0]  s_arqos,
    output logic [3:0]  s_arregion,
    output logic [2:0]  s_arprot,
    input  logic        s_rvalid,
    output logic        s_rready,
    input  logic [127:0] s_rdata,
    input  logic [5:0]  s_rid,
    input  logic [1:0]  s_rresp,
    input  logic        s_rlast
);
    // ---- 常量 ----
    localparam logic [5:0] AXI_ID        = 6'd0;
    localparam logic [7:0] AXI_LEN0      = 8'd0;        // 单拍
    localparam logic [2:0] AXI_SIZE_WORD = 3'd2;        // 4 字节
    localparam logic [1:0] AXI_BURST_INCR = 2'b01;
    localparam logic [2:0] AXI_PROT      = 3'd0;
    localparam logic [3:0] AXI_CACHE     = 4'd0;
    localparam logic [3:0] AXI_QOS       = 4'd0;
    localparam logic [3:0] AXI_REGION    = 4'd0;

    // CSR 地址（见 coralnpu-architecture.md §6.2 与 integration_guide Booting）
    localparam logic [31:0] CSR_CTRL     = 32'h00030000;  // RESET(bit0)/CLOCK_GATE(bit1)
    localparam logic [31:0] CSR_PC_START = 32'h00030004;
    localparam logic [31:0] CSR_STATUS   = 32'h00030008;  // bit0=HALTED

    // S 命令引导序列：3 次写
    localparam logic [31:0] BOOT_ADDRS[3] = '{CSR_PC_START, CSR_CTRL, CSR_CTRL};
    localparam logic [31:0] BOOT_DATAS[3] = '{32'h0, 32'h1, 32'h0};

    // ---- 状态 ----
    typedef enum logic [5:0] {
        IDLE,
        P_W_ADDR, P_W_DATA,          // W 命令参数收集
        P_R_ADDR, P_R_CNT,           // R 命令参数收集
        P_END,                       // 等待行结束符
        XW_AW, XW_W, XW_B,           // AXI 写事务
        XR_AR, XR_R,                 // AXI 读事务
        BOOT_NEXT,                   // S 序列下一步
        TX_OK, TX_ERR, TX_HELP,      // 文本应答
        TX_HADDR, TX_HDATA, TX_NL,   // hex 行应答
        ERR_DRAIN                    // 丢弃到行尾
    } state_t;

    state_t      state;
    logic [31:0] cmd_addr;       // 参数地址 / 当前读地址
    logic [31:0] cmd_data;       // 参数数据
    logic [31:0] rd_data;        // 最近读到的 32 位字
    logic [7:0]  cmd_count;      // R 剩余次数
    logic [2:0]  cmd_kind;       // 0=W 1=R 2=S 3=Q 4=HELP
    logic [2:0]  hex_cnt;        // 参数收集计数
    logic [2:0]  seq_idx;        // S 序列索引
    logic [2:0]  tx_cnt;         // TX 序列内索引
    logic        cmd_is_boot;    // 当前 AXI 写来自 S 序列

    // ---- TX 请求（tx_req=1 且 !tx_busy 时 uart_tx 捕获，随后 tx_req 清 0） ----
    // 注意：tx_req 的清/置都在主 FSM always_ff 中处理（见下方主 FSM 顶部），
    //       避免多驱动。
    logic       tx_req;
    logic [7:0] tx_byte;
    assign tx_valid = tx_req && !tx_busy;
    assign tx_data  = tx_byte;

    // ---- hex 转换 ----
    function automatic logic hex_ok(input logic [7:0] c);
        return (c >= "0" && c <= "9") ||
               (c >= "A" && c <= "F") ||
               (c >= "a" && c <= "f");
    endfunction
    function automatic logic [3:0] hex_val(input logic [7:0] c);
        case (c)
            "0","1","2","3","4","5","6","7","8","9": return c - "0";
            "A","B","C","D","E","F": return c - "A" + 4'd10;
            default: return c - "a" + 4'd10;
        endcase
    endfunction
    function automatic logic [7:0] hex_digit(input logic [3:0] n);
        return (n < 10) ? ("0" + n) : ("A" + n - 10);
    endfunction

    // ---- AXI 输出（注册，解决 host→core 短路径 hold：启动寄存器靠近 core AXI 端口） ----
    // 每个 valid/ready 在进入对应阶段时置位、握手完成后清除，避免 AXI 双握手。
    logic [3:0] w_lane;
    assign w_lane = cmd_addr[3:0];
    logic          s_awvalid_r, s_wvalid_r, s_bready_r, s_arvalid_r, s_rready_r;
    logic [31:0]   s_awaddr_r, s_araddr_r;
    logic [127:0]  s_wdata_r;
    logic [15:0]   s_wstrb_r;
    logic          s_wlast_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awvalid_r <= 1'b0;
            s_wvalid_r  <= 1'b0;
            s_bready_r  <= 1'b0;
            s_arvalid_r <= 1'b0;
            s_rready_r  <= 1'b0;
            s_awaddr_r  <= '0;
            s_araddr_r  <= '0;
            s_wdata_r   <= '0;
            s_wstrb_r   <= '0;
            s_wlast_r   <= 1'b0;
        end else begin
            // AW：进入 XW_AW 置位，握手后清除
            if (state == XW_AW && !s_awvalid_r) s_awvalid_r <= 1'b1;
            if (s_awvalid_r && s_awready)      s_awvalid_r <= 1'b0;
            if (state == XW_AW)                s_awaddr_r  <= cmd_addr;
            // W
            if (state == XW_W && !s_wvalid_r)  s_wvalid_r  <= 1'b1;
            if (s_wvalid_r && s_wready)        s_wvalid_r  <= 1'b0;
            if (state == XW_W) begin
                s_wdata_r <= {96'd0, cmd_data} << (w_lane * 8);   // 字节通道对齐
                s_wstrb_r <= 16'h000F << w_lane;
                s_wlast_r <= 1'b1;
            end
            // B
            if (state == XW_B && !s_bready_r)  s_bready_r <= 1'b1;
            if (s_bvalid && s_bready_r)        s_bready_r <= 1'b0;
            // AR
            if (state == XR_AR && !s_arvalid_r) s_arvalid_r <= 1'b1;
            if (s_arvalid_r && s_arready)       s_arvalid_r <= 1'b0;
            if (state == XR_AR)                 s_araddr_r  <= cmd_addr;
            // R
            if (state == XR_R && !s_rready_r)  s_rready_r <= 1'b1;
            if (s_rvalid && s_rready_r)        s_rready_r <= 1'b0;
        end
    end

    assign s_awvalid  = s_awvalid_r;
    assign s_wvalid   = s_wvalid_r;
    assign s_bready   = s_bready_r;
    assign s_arvalid  = s_arvalid_r;
    assign s_rready   = s_rready_r;
    assign s_awaddr   = s_awaddr_r;
    assign s_awid     = AXI_ID;
    assign s_awlen    = AXI_LEN0;
    assign s_awsize   = AXI_SIZE_WORD;
    assign s_awburst  = AXI_BURST_INCR;
    assign s_awcache  = AXI_CACHE;
    assign s_awqos    = AXI_QOS;
    assign s_awregion = AXI_REGION;
    assign s_awprot   = AXI_PROT;
    assign s_wdata    = s_wdata_r;
    assign s_wstrb    = s_wstrb_r;
    assign s_wlast    = s_wlast_r;
    assign s_araddr   = s_araddr_r;
    assign s_arid     = AXI_ID;
    assign s_arlen    = AXI_LEN0;
    assign s_arsize   = AXI_SIZE_WORD;
    assign s_arburst  = AXI_BURST_INCR;
    assign s_arcache  = AXI_CACHE;
    assign s_arqos    = AXI_QOS;
    assign s_arregion = AXI_REGION;
    assign s_arprot   = AXI_PROT;

    // 读数据提取（标准 AXI 对齐：按 addr[3:0] 通道）
    logic [31:0] rd_lane_word;
    always_comb begin
        case (cmd_addr[3:0])
            4'h0:     rd_lane_word = s_rdata[31:0];
            4'h4:     rd_lane_word = s_rdata[63:32];
            4'h8:     rd_lane_word = s_rdata[95:64];
            default:  rd_lane_word = s_rdata[127:96];
        endcase
    end

    // ---- 主 FSM ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            cmd_addr    <= '0;
            cmd_data    <= '0;
            rd_data     <= '0;
            cmd_count   <= '0;
            cmd_kind    <= '0;
            hex_cnt     <= '0;
            seq_idx     <= '0;
            tx_cnt      <= '0;
            cmd_is_boot <= 1'b0;
            tx_req      <= 1'b0;
            tx_byte     <= '0;
        end else begin
            // TX 字节被 uart_tx 接受后清除请求（在 TX 状态下发字节用同拍置位覆盖）
            if (tx_valid) begin
                tx_req <= 1'b0;
            end
            case (state)
                // =====================================================
                IDLE: begin
                    cmd_is_boot <= 1'b0;
                    if (rx_valid) begin
                        case (rx_data)
                            "W": begin cmd_kind <= 3'd0; state <= P_W_ADDR; hex_cnt <= '0; end
                            "R": begin cmd_kind <= 3'd1; state <= P_R_ADDR; hex_cnt <= '0; end
                            "S": begin cmd_kind <= 3'd2; state <= P_END; end
                            "Q": begin
                                cmd_kind  <= 3'd3;
                                cmd_addr  <= CSR_STATUS;
                                cmd_count <= 8'd1;
                                state     <= P_END;
                            end
                            "?": begin cmd_kind <= 3'd4; state <= P_END; end
                            // 忽略孤立换行（CRLF 容错：'\r' 已作为命令终止符被 P_END 消费，
                            // 紧随的 '\n' 在此丢弃，不触发 ERR）
                            "\n", "\r": ;
                            default: state <= ERR_DRAIN;
                        endcase
                    end
                end

                // ---- W 命令：8 hex addr + 8 hex data ----
                P_W_ADDR: begin
                    if (rx_valid) begin
                        if (!hex_ok(rx_data)) begin
                            state <= ERR_DRAIN;
                        end else begin
                            cmd_addr <= {cmd_addr[27:0], hex_val(rx_data)};
                            if (hex_cnt == 3'd7) begin
                                state   <= P_W_DATA;
                                hex_cnt <= '0;
                            end else begin
                                hex_cnt <= hex_cnt + 1'b1;
                            end
                        end
                    end
                end
                P_W_DATA: begin
                    if (rx_valid) begin
                        if (!hex_ok(rx_data)) begin
                            state <= ERR_DRAIN;
                        end else begin
                            cmd_data <= {cmd_data[27:0], hex_val(rx_data)};
                            if (hex_cnt == 3'd7) begin
                                state   <= P_END;
                                hex_cnt <= '0;
                            end else begin
                                hex_cnt <= hex_cnt + 1'b1;
                            end
                        end
                    end
                end

                // ---- R 命令：8 hex addr + 2 hex count ----
                P_R_ADDR: begin
                    if (rx_valid) begin
                        if (!hex_ok(rx_data)) begin
                            state <= ERR_DRAIN;
                        end else begin
                            cmd_addr <= {cmd_addr[27:0], hex_val(rx_data)};
                            if (hex_cnt == 3'd7) begin
                                state   <= P_R_CNT;
                                hex_cnt <= '0;
                            end else begin
                                hex_cnt <= hex_cnt + 1'b1;
                            end
                        end
                    end
                end
                P_R_CNT: begin
                    if (rx_valid) begin
                        if (!hex_ok(rx_data)) begin
                            state <= ERR_DRAIN;
                        end else begin
                            cmd_count <= {cmd_count[3:0], hex_val(rx_data)};
                            if (hex_cnt == 3'd1) begin
                                state   <= P_END;
                                hex_cnt <= '0;
                            end else begin
                                hex_cnt <= hex_cnt + 1'b1;
                            end
                        end
                    end
                end

                // ---- 行结束 ----
                P_END: begin
                    if (rx_valid) begin
                        if (rx_data == "\n" || rx_data == "\r") begin
                            case (cmd_kind)
                                3'd0: begin                                // W
                                    state <= XW_AW;                    // ITCM 也走 AXI（验证 AXI 写 ITCM，暂时关闭直写分支）
                                end
                                3'd1: state <= XR_AR;                      // R
                                3'd2: begin                                // S
                                    cmd_is_boot <= 1'b1;
                                    seq_idx     <= '0;
                                    cmd_addr    <= BOOT_ADDRS[0];
                                    cmd_data    <= BOOT_DATAS[0];
                                    state       <= XW_AW;
                                end
                                3'd3: state <= XR_AR;                      // Q
                                default: begin
                                    state  <= TX_HELP;                     // ?
                                    tx_cnt <= '0;
                                end
                            endcase
                        end else begin
                            state <= ERR_DRAIN;
                        end
                    end
                end

                // ---- AXI 写事务 ----
                XW_AW: begin
                    if (s_awvalid_r && s_awready) state <= XW_W;
                end
                XW_W: begin
                    if (s_wvalid_r && s_wready) state <= XW_B;
                end
                XW_B: begin
                    if (s_bvalid && s_bready_r) begin
                        if (s_bresp[1]) begin            // SLVERR
                            state  <= TX_ERR;
                            tx_cnt <= '0;
                        end else if (cmd_is_boot) begin
                            state  <= BOOT_NEXT;
                        end else begin
                            state  <= TX_OK;
                            tx_cnt <= '0;
                        end
                    end
                end
                BOOT_NEXT: begin
                    if (seq_idx == 3'd2) begin
                        state  <= TX_OK;
                        tx_cnt <= '0;
                    end else begin
                        seq_idx  <= seq_idx + 1'b1;
                        cmd_addr <= BOOT_ADDRS[seq_idx + 1'b1];
                        cmd_data <= BOOT_DATAS[seq_idx + 1'b1];
                        state    <= XW_AW;
                    end
                end

                // ---- AXI 读事务 ----
                XR_AR: begin
                    if (s_arvalid_r && s_arready) state <= XR_R;
                end
                XR_R: begin
                    if (s_rvalid && s_rready_r) begin
                        rd_data <= rd_lane_word;
                        if (s_rresp[1]) begin            // SLVERR
                            state  <= TX_ERR;
                            tx_cnt <= '0;
                        end else begin
                            state  <= TX_HADDR;
                            tx_cnt <= '0;
                        end
                    end
                end

                // ---- 应答：hex 行 ----
                TX_HADDR: begin
                    if (!tx_req) begin
                        tx_byte <= hex_digit(cmd_addr[(3'd7 - tx_cnt) * 4 +: 4]);
                        tx_req  <= 1'b1;
                        if (tx_cnt == 3'd7) begin
                            state  <= TX_HDATA;
                            tx_cnt <= '0;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end
                end
                TX_HDATA: begin
                    if (!tx_req) begin
                        tx_byte <= hex_digit(rd_data[(3'd7 - tx_cnt) * 4 +: 4]);
                        tx_req  <= 1'b1;
                        if (tx_cnt == 3'd7) begin
                            state  <= TX_NL;
                            tx_cnt <= '0;
                        end else begin
                            tx_cnt <= tx_cnt + 1'b1;
                        end
                    end
                end
                TX_NL: begin
                    if (!tx_req) begin
                        tx_byte <= "\n";
                        tx_req  <= 1'b1;
                        if (cmd_count > 8'd1) begin
                            cmd_count <= cmd_count - 1'b1;
                            cmd_addr  <= cmd_addr + 32'd4;
                            state     <= XR_AR;
                        end else begin
                            state  <= TX_OK;
                            tx_cnt <= '0;
                        end
                    end
                end

                // ---- 应答：文本 ----
                TX_OK: begin
                    if (!tx_req) begin
                        case (tx_cnt)
                            3'd0: tx_byte <= "O";
                            3'd1: tx_byte <= "K";
                            default: tx_byte <= "\n";
                        endcase
                        tx_req <= 1'b1;
                        if (tx_cnt == 3'd2) state <= IDLE;
                        else tx_cnt <= tx_cnt + 1'b1;
                    end
                end
                TX_ERR: begin
                    if (!tx_req) begin
                        case (tx_cnt)
                            3'd0: tx_byte <= "E";
                            3'd1: tx_byte <= "R";
                            3'd2: tx_byte <= "R";
                            default: tx_byte <= "\n";
                        endcase
                        tx_req <= 1'b1;
                        if (tx_cnt == 3'd3) state <= IDLE;
                        else tx_cnt <= tx_cnt + 1'b1;
                    end
                end
                TX_HELP: begin
                    if (!tx_req) begin
                        case (tx_cnt)
                            3'd0: tx_byte <= "H";
                            3'd1: tx_byte <= "E";
                            3'd2: tx_byte <= "L";
                            3'd3: tx_byte <= "P";
                            default: tx_byte <= "\n";
                        endcase
                        tx_req <= 1'b1;
                        if (tx_cnt == 3'd4) state <= IDLE;
                        else tx_cnt <= tx_cnt + 1'b1;
                    end
                end

                // ---- 错误行：丢弃到行尾再报 ERR ----
                ERR_DRAIN: begin
                    if (rx_valid && (rx_data == "\n" || rx_data == "\r")) begin
                        state  <= TX_ERR;
                        tx_cnt <= '0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
