// tb_debug_test.sv —— T016 阶段 A: Debug 抽象命令读写 TCM 验证（xsim，机器202）
//
// 目标：验证经 UART host 触发 Debug 模块抽象命令（Access Memory）读写 ITCM/DTCM。
//
// Debug 访问协议（CoreAxiCSR 的 Dbg 寄存器，非标准 Debug 0x30810/0x30817 直地址）：
//   DbgReqAddr = 0x30800  写 Debug 内部寄存器偏移（Data0=0x4 Data1=0x5 Dmcontrol=0x10
//                         Dmstatus=0x11 Abstractcs=0x16 Command=0x17）
//   DbgReqData = 0x30804  写数据
//   DbgReqOp   = 0x30808  写 op（READ=1 / WRITE=2）触发访问
//   DbgRspData = 0x30810  读结果
//   DbgStatus  = 0x30814  写=清响应队列
//
// 序列：
//   1) halt 核：Dmcontrol(0x10) = 0x80000001（haltreq+dmactive），WRITE
//   2) 轮询 Q（CSR_STATUS 0x30008）bit0=HALTED
//   3) Access Memory 写：Data0(0x4)=数据 → Data1(0x5)=地址 → Command(0x17)=0x02230000
//   4) 轮询 Abstractcs(0x16) busy=0 cmderr=0
//   5) R 命令读回验证（或 Access Memory 读）
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

    task send_bit(input logic b); uart_rx = b; #(BIT_NS); endtask
    task send_byte(input logic [7:0] byte_in);
        send_bit(1'b0);
        for (int i = 0; i < 8; i++) send_bit(byte_in[i]);
        send_bit(1'b1);
    endtask
    task send_str(input string s);
        for (int i = 0; i < s.len(); i++) send_byte(s[i]);
    endtask

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

    task automatic recv_hexline(output logic [31:0] hexval);
        logic [31:0] v = 32'h0;
        for (int i = 0; i < 8; i++) recv_byte();  // addr 8 hex
        for (int i = 0; i < 8; i++) begin          // data 8 hex
            recv_byte();
            if (rx_last_byte >= "0" && rx_last_byte <= "9") v = (v << 4) | (rx_last_byte - "0");
            else if (rx_last_byte >= "A" && rx_last_byte <= "F") v = (v << 4) | (rx_last_byte - "A" + 10);
            else if (rx_last_byte >= "a" && rx_last_byte <= "f") v = (v << 4) | (rx_last_byte - "a" + 10);
        end
        recv_byte();  // 消费行尾 \n
        hexval = v;
    endtask

    task automatic w_cmd(input logic [31:0] addr, input logic [31:0] data);
        send_str($sformatf("W%08X%08X\n", addr, data));
        recv_expect_str("OK\n");
    endtask
    task automatic r_word(input logic [31:0] addr, output logic [31:0] data);
        send_str($sformatf("R%08X01\n", addr));
        recv_hexline(data);
        recv_expect_str("OK\n");
    endtask

    // 经 Dbg 寄存器访问 Debug 内部寄存器
    task automatic dbg_reg(input logic [31:0] reg_off, input logic [31:0] data,
                           input bit is_write, output logic [31:0] rdata);
        w_cmd(32'h30800, reg_off);            // DbgReqAddr = Debug 寄存器偏移
        if (is_write) w_cmd(32'h30804, data); // DbgReqData
        w_cmd(32'h30808, is_write ? 32'h2 : 32'h1);  // DbgReqOp = WRITE(2)/READ(1) 触发
        rdata = data;
        if (!is_write) r_word(32'h30810, rdata);  // DbgRspData 读结果
        w_cmd(32'h30814, 32'h0);              // 写 DbgStatus 清响应队列（深度1，必须消费）
    endtask

    // 轮询 Abstractcs(0x16) busy=0 且 cmderr=0
    task automatic debug_wait_busy();
        logic [31:0] v;
        for (int i = 0; i < 50; i++) begin
            dbg_reg(32'h16, 32'h0, 0, v);   // 读 Abstractcs
            if (!(v & 32'h1)) begin          // busy 清除
                if ((v >> 8) & 32'h7) begin
                    $display("TB: DEBUG cmderr=%0d", (v >> 8) & 7);
                    test_fail = 1;
                end
                return;
            end
        end
        $display("TB: DEBUG busy 超时");
        test_fail = 1;
    endtask

    // Access Memory 命令（经 Debug 抽象命令）
    task automatic debug_access_mem(input logic [31:0] mem_addr, input logic [31:0] data,
                                    input bit is_write, output logic [31:0] rdata);
        logic [31:0] v;
        if (is_write) dbg_reg(32'h4, data, 1, v);            // Data0 = 写数据
        dbg_reg(32'h5, mem_addr, 1, v);                      // Data1 = 内存地址
        if (is_write) dbg_reg(32'h17, 32'h02230000, 1, v);   // Command: AccessMem write
        else          dbg_reg(32'h17, 32'h02220000, 1, v);   // Command: AccessMem read
        debug_wait_busy();
        rdata = data;
        if (!is_write) dbg_reg(32'h4, 32'h0, 0, rdata);      // 读 Data0 = 结果
    endtask

    initial begin
        logic [31:0] got;
        #100;
        rst_btn_n = 1'b1;
        #1000;
        rx_byte_q.delete();   // 清空复位后可能残留的 host 初始发送
        #500;

        $display("=== T016-A: Debug 抽象命令读写 TCM（Dbg 寄存器协议）===");

        // 1) halt 核：Dmcontrol(0x10) = haltreq[31]+dmactive[0]
        dbg_reg(32'h10, 32'h80000001, 1, got);
        $display("TB: 写 Dmcontrol haltreq");
        begin
            logic [31:0] dmc, dms;
            dbg_reg(32'h10, 32'h0, 0, dmc);   // 读 Dmcontrol（haltreq 是否置位）
            dbg_reg(32'h11, 32'h0, 0, dms);   // 读 Dmstatus
            $display("TB: Dmcontrol=0x%08X (haltreq=%0d) Dmstatus=0x%08X (allhalted=%0d)",
                     dmc, dmc[31], dms, dms[31]);
        end
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

        // 2) Debug 写 ITCM[0x0] = 0xDEADBEEF
        debug_access_mem(32'h00000000, 32'hDEADBEEF, 1, got);
        r_word(32'h00000000, got);
        if (got == 32'hDEADBEEF) $display("TB: PASS ITCM[0x0] 读回 = %08X", got);
        else begin $display("TB: FAIL ITCM[0x0] 读回 = %08X exp DEADBEEF", got); test_fail = 1; end

        // 3) Debug 写 DTCM[0x10000] = 0x12345678
        debug_access_mem(32'h00010000, 32'h12345678, 1, got);
        r_word(32'h00010000, got);
        if (got == 32'h12345678) $display("TB: PASS DTCM[0x10000] 读回 = %08X", got);
        else begin $display("TB: FAIL DTCM[0x10000] 读回 = %08X exp 12345678", got); test_fail = 1; end

        // 4) Debug 读 ITCM（Access Memory 读）
        debug_access_mem(32'h00000000, 32'h0, 0, got);
        if (got == 32'hDEADBEEF) $display("TB: PASS Debug 读 ITCM[0x0] = %08X", got);
        else begin $display("TB: FAIL Debug 读 ITCM[0x0] = %08X exp DEADBEEF", got); test_fail = 1; end

        if (test_fail) $display("=== T016-A: FAIL ===");
        else           $display("=== T016-A: ALL CHECKS PASSED ===");
        $finish;
    end

    initial begin
        #50_000_000;   // 50ms 超时（halt/抽象命令可能需要更长时间）
        $display("TB: TIMEOUT");
        $finish;
    end
endmodule
