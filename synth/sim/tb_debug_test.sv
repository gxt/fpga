// tb_debug_test.sv —— T016 阶段 A: Debug 抽象命令读写 TCM 验证（xsim，机器202）
//
// 目标：验证经 UART host（W 命令写 CSR 0x30800 区域）触发 Debug 模块
//       抽象命令（Access Memory）读写 ITCM/DTCM，作为 T015 加载通道备选。
//
// 序列（Access Memory 写 ITCM 0x0）：
//   1) W 30810 80000001   Dmcontrol: haltreq[31]+dmactive[0]（halt 核）
//   2) 轮询 Q 直到 CSR_STATUS(0x30008) bit0=HALTED=1
//   3) W 30805 <addr>     Data1 = 内存地址
//   4) W 30804 <data>     Data0 = 写数据
//   5) W 30817 02230000   Command: cmdtype=2(AccessMem)+aamsize=2+write+transfer
//   6) 轮询 R 30816 (Abstractcs) busy=0 且 cmderr=0
//   7) R <addr> 读回验证（ITCM/DTCM）
// 读内存：同序列 command=02220000（读，无 write 位），后 R 30804 读 Data0
//
// 时钟：USE_MMCM=0（clk_p 直连），BAUD=781250，BIT_NS=1280（同 tb_top）
module tb_debug_test;
    logic clk_p = 1'b0, clk_n = 1'b0;
    logic rst_btn_n = 1'b0;
    logic uart_rx = 1'b1, uart_tx;
    logic led_halted, led_fault, led_locked;

    top_coralnpu #(
        .CORE_CLK_HZ (50_000_000),
        .BAUD        (781250),
        .USE_MMCM    (0)
    ) u_dut (
        .clk_p(clk_p), .clk_n(clk_n), .rst_btn_n(rst_btn_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .led_halted(led_halted), .led_fault(led_fault), .led_locked(led_locked)
    );

    always #10 clk_p = ~clk_p;

    localparam int BIT_NS = 1280;

    // ---- TB 串口发送器（同 tb_top）----
    task send_bit(input logic b); uart_rx = b; #(BIT_NS); endtask
    task send_byte(input logic [7:0] byte_in);
        send_bit(1'b0);
        for (int i = 0; i < 8; i++) send_bit(byte_in[i]);
        send_bit(1'b1);
    endtask
    task send_str(input string s);
        for (int i = 0; i < s.len(); i++) send_byte(s[i]);
    endtask

    // ---- TB 串口接收器（同 tb_top）----
    logic [7:0] rx_byte_q [$];
    always begin
        @(negedge uart_tx);
        #(BIT_NS / 2);
        if (uart_tx === 1'b0) begin
            logic [7:0] sh = 8'h0;
            for (int i = 0; i < 8; i++) begin
                #(BIT_NS); sh = {uart_tx, sh[7:1]};
            end
            #(BIT_NS);
            if (uart_tx !== 1'b1) $display("TB: RX framing error");
            else rx_byte_q.push_back(sh);
        end
    end

    int test_fail = 0;
    string exp_str;
    logic [7:0] rx_last_byte;

    task automatic recv_byte();
        wait (rx_byte_q.size() > 0);
        rx_last_byte = rx_byte_q.pop_front();
    endtask
    task automatic recv_expect_str(input string s);
        for (int i = 0; i < s.len(); i++) begin
            recv_byte();
            if (rx_last_byte != s[i]) begin
                $display("TB: MISMATCH idx=%0d got=0x%02x exp=0x%02x", i, rx_last_byte, s[i]);
                test_fail = 1;
            end
        end
    endtask

    // 读取一行响应（直到 \n），返回前 16 字符（addr+data）
    task automatic recv_hexline(output logic [31:0] hexval);
        logic [7:0] b;
        logic [31:0] v = 32'h0;
        int n = 0;
        begin
            for (int i = 0; i < 8; i++) begin  // 8 hex 字符 addr
                recv_byte();
            end
            for (int i = 0; i < 8; i++) begin  // 8 hex 字符 data
                recv_byte();
                if (rx_last_byte >= "0" && rx_last_byte <= "9") v = (v << 4) | (rx_last_byte - "0");
                else if (rx_last_byte >= "A" && rx_last_byte <= "F") v = (v << 4) | (rx_last_byte - "A" + 10);
                else if (rx_last_byte >= "a" && rx_last_byte <= "f") v = (v << 4) | (rx_last_byte - "a" + 10);
            end
            hexval = v;
        end
    endtask

    // 发 W 命令并等 OK
    task automatic w_cmd(input logic [31:0] addr, input logic [31:0] data);
        send_str($sformatf("W%08X%08X\n", addr, data));
        recv_expect_str("OK\n");
    endtask

    // 发 R 命令读取一个 32 位字并返回 data
    task automatic r_word(input logic [31:0] addr, output logic [31:0] data);
        send_str($sformatf("R%08X01\n", addr));
        recv_hexline(data);
        recv_expect_str("OK\n");
    endtask

    // Debug Access Memory 命令
    task automatic debug_access_mem(input logic [31:0] mem_addr, input logic [31:0] data,
                                    input logic is_write, output logic [31:0] rdata);
        logic [31:0] v;
        w_cmd(32'h30805, mem_addr);              // Data1 = 地址
        if (is_write) w_cmd(32'h30804, data);    // Data0 = 写数据
        if (is_write) w_cmd(32'h30817, 32'h02230000);  // AccessMem + aamsize=2 + write + transfer
        else          w_cmd(32'h30817, 32'h02220000);  // AccessMem + aamsize=2 + transfer(读)
        // 轮询 Abstractcs busy=0
        repeat (20) begin
            r_word(32'h30816, v);
            if (!(v & 32'h1)) break;             // busy bit0 清除
        end
        // 检查 cmderr（[10:8]）
        r_word(32'h30816, v);
        if ((v >> 8) & 32'h7) begin
            $display("TB: DEBUG cmderr=%0d", (v >> 8) & 7);
            test_fail = 1;
        end
        rdata = data;
        if (!is_write) r_word(32'h30804, rdata); // 读结果在 Data0
    endtask

    initial begin
        logic [31:0] got;
        #100;
        rst_btn_n = 1'b1;
        #1000;

        $display("=== T016-A: Debug 抽象命令读写 TCM ===");

        // 1) halt 核
        w_cmd(32'h30810, 32'h80000001);          // Dmcontrol haltreq+dmactive
        // 轮询 halted（Q: CSR_STATUS bit0）
        begin
            int found = 0;
            for (int i = 0; i < 50 && !found; i++) begin
                send_str("Q\n");
                recv_hexline(got);
                recv_expect_str("OK\n");
                if (got & 32'h1) begin
                    found = 1;
                    $display("TB: 核已 halted (status=%08X)", got);
                end
                #1000;
            end
            if (!found) begin
                $display("TB: FAIL 核未 halted");
                test_fail = 1;
            end
        end

        // 2) Debug 写 ITCM 0x0 = 0xDEADBEEF
        debug_access_mem(32'h00000000, 32'hDEADBEEF, 1'b1, got);
        $display("TB: Debug 写 ITCM[0x0] 完成");
        // R 命令读回 ITCM 0x0 验证
        r_word(32'h00000000, got);
        if (got == 32'hDEADBEEF) $display("TB: PASS ITCM[0x0] 读回 = %08X", got);
        else begin $display("TB: FAIL ITCM[0x0] 读回 = %08X exp DEADBEEF", got); test_fail = 1; end

        // 3) Debug 写 DTCM 0x10000 = 0x12345678
        debug_access_mem(32'h00010000, 32'h12345678, 1'b1, got);
        r_word(32'h00010000, got);
        if (got == 32'h12345678) $display("TB: PASS DTCM[0x10000] 读回 = %08X", got);
        else begin $display("TB: FAIL DTCM[0x10000] 读回 = %08X exp 12345678", got); test_fail = 1; end

        // 4) Debug 读 ITCM（Access Memory 读路径）
        debug_access_mem(32'h00000000, 32'h0, 1'b0, got);
        if (got == 32'hDEADBEEF) $display("TB: PASS Debug 读 ITCM[0x0] = %08X", got);
        else begin $display("TB: FAIL Debug 读 ITCM[0x0] = %08X exp DEADBEEF", got); test_fail = 1; end

        if (test_fail) $display("=== T016-A: FAIL ===");
        else           $display("=== T016-A: ALL CHECKS PASSED ===");
        $finish;
    end

    // 超时保护
    initial begin
        #5_000_000;
        $display("TB: TIMEOUT");
        $finish;
    end
endmodule
