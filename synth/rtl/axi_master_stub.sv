// axi_master_stub.sv —— CoreMiniAxi 的 AXI master 端口响应桩
//
// 用途：core_mini_axi 的 m_axi（AXI4 128-bit master）在 T013 测试程序中不会访问
//       外部内存（EXTMEM/DDR 区域），但为防 core 误访问外部区域而挂死，
//       本桩对任何读/写事务立即以 OKAY 响应（读数据全 0）。
// 约束：本桩不是功能正确的外部内存，仅用于防挂死。
module axi_master_stub (
    input  logic        clk,
    input  logic        rst_n,
    // ---- 写通道（core = master，本桩 = slave） ----
    input  logic        m_awvalid,
    output logic        m_awready,
    input  logic [31:0] m_awaddr,
    input  logic [5:0]  m_awid,
    input  logic [7:0]  m_awlen,
    input  logic [1:0]  m_awburst,
    input  logic        m_wvalid,
    output logic        m_wready,
    input  logic [127:0] m_wdata,
    input  logic [15:0]  m_wstrb,
    input  logic        m_wlast,
    output logic        m_bvalid,
    input  logic        m_bready,
    output logic [5:0]  m_bid,
    output logic [1:0]  m_bresp,
    // ---- 读通道 ----
    input  logic        m_arvalid,
    output logic        m_arready,
    input  logic [31:0] m_araddr,
    input  logic [5:0]  m_arid,
    input  logic [7:0]  m_arlen,
    input  logic [1:0]  m_arburst,
    output logic        m_rvalid,
    input  logic        m_rready,
    output logic [127:0] m_rdata,
    output logic [5:0]  m_rid,
    output logic [1:0]  m_rresp,
    output logic        m_rlast
);
    // ---- 写响应 FSM ----
    // b_pending: 有写突发待响应；w_last_seen: 已收到该突发最后一个 W 拍。
    // BVALID 仅在 AW 已收且 WLAST 已收后置位（满足 AXI 写数据/响应依赖）。
    logic       b_pending;
    logic       w_last_seen;
    logic [5:0] bid_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_pending   <= 1'b0;
            w_last_seen <= 1'b0;
            bid_q       <= '0;
        end else begin
            if (!b_pending && m_awvalid) begin
                bid_q       <= m_awid;
                b_pending   <= 1'b1;
                // 允许 AW 与 WLAST 同拍到达
                w_last_seen <= m_wvalid && m_wlast;
            end else if (!b_pending) begin
                // 空闲时 W 先到（异常顺序）：记下 WLAST
                if (m_wvalid && m_wlast) begin
                    w_last_seen <= 1'b1;
                end
            end else begin
                if (m_wvalid && m_wlast) begin
                    w_last_seen <= 1'b1;
                end
            end
            // B 响应被接受后回到空闲
            if (b_pending && w_last_seen && m_bready) begin
                b_pending   <= 1'b0;
                w_last_seen <= 1'b0;
            end
        end
    end
    assign m_awready = !b_pending;               // 忙时不接收新 AW
    assign m_wready  = 1'b1;
    assign m_bvalid  = b_pending && w_last_seen;
    assign m_bid     = bid_q;
    assign m_bresp   = 2'b00;                    // OKAY

    // ---- 读响应 FSM ----
    // 捕获 AR 后按 ARLEN 拍数回 0 数据（rdata 全 0），rlast 在最后一拍。
    logic       r_pending;
    logic [7:0] r_remaining;
    logic [5:0] rid_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_pending  <= 1'b0;
            r_remaining <= '0;
            rid_q      <= '0;
        end else begin
            if (!r_pending && m_arvalid) begin
                rid_q       <= m_arid;
                r_remaining <= m_arlen;
                r_pending   <= 1'b1;
            end
            if (r_pending && m_rready) begin
                if (r_remaining == 8'd0) begin
                    r_pending <= 1'b0;
                end else begin
                    r_remaining <= r_remaining - 1'b1;
                end
            end
        end
    end
    assign m_arready = !r_pending;               // 忙时不接收新 AR
    assign m_rvalid  = r_pending;
    assign m_rdata   = '0;
    assign m_rid     = rid_q;
    assign m_rresp   = 2'b00;                    // OKAY
    assign m_rlast   = (r_remaining == 8'd0);
endmodule
