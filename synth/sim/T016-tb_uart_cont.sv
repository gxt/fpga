// tb_uart_cont.sv —— 40MHz（贴近上板）连续写 TCM 复现 host 卡点
//
// 目的：验证 host 连续单拍 AXI 写 TCM 在 40MHz 下是否出现
//       "响应队列满→fabric 写停→死锁"（3-4 字后卡）。
// 时钟：USE_MMCM=0，clk_p 40MHz（25ns）；BAUD=625000，BIT_NS=1600
module tb_uart_cont;
    logic clk_p = 1'b0, clk_n = 1'b0;
    logic rst_btn_n = 1'b0;
    logic uart_rx = 1'b1, uart_tx;
    logic led_halted, led_fault, led_locked;

    top_coralnpu #(
        .CORE_CLK_HZ (40_000_000),
        .BAUD        (625000),
        .USE_MMCM    (0)
    ) u_dut (
        .clk_p(clk_p), .clk_n(clk_n), .rst_btn_n(rst_btn_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .led_halted(led_halted), .led_fault(led_fault), .led_locked(led_locked)
    );

    always #12.5 clk_p = ~clk_p;   // 40MHz

    localparam int BIT_NS = 1600;  // 40MHz, 625000 baud

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

    logic [7:0] rx_last_byte;
    int test_fail = 0;

    task automatic recv_byte();
        wait (rx_byte_q.size() > 0);
        rx_last_byte = rx_byte_q.pop_front();
    endtask
    // 收 3 字节，期望 "OK\n"；返回是否匹配
    task automatic recv_ok(output int got_ok);
        got_ok = 1;
        for (int i = 0; i < 3; i++) begin
            recv_byte();
            if (i == 0 && rx_last_byte != "O") got_ok = 0;
            if (i == 1 && rx_last_byte != "K") got_ok = 0;
            if (i == 2 && rx_last_byte != "\n") got_ok = 0;
        end
    endtask

    // 连续写 N 个字，返回成功的字数
    task automatic cont_write(input logic [31:0] base, input int n, output int ok_cnt);
        logic [31:0] data;
        for (int i = 0; i < n; i++) begin
            int got_ok;
            send_str($sformatf("W%08X%08X\n", base + i*4, 32'hA0000000 + i));
            recv_ok(got_ok);
            if (got_ok) ok_cnt++;
            else begin
                $display("TB: FAIL 写 0x%08X（第 %0d 字）", base + i*4, i+1);
                return;
            end
        end
    endtask

    initial begin
        int okd, oki;
        #100;
        rst_btn_n = 1'b1;
        #1000;
        rx_byte_q.delete();
        #500;

        $display("=== 40MHz 连续写 TCM 复现 ===");

        // 连续写 DTCM 16 字
        okd = 0;
        cont_write(32'h00010000, 16, okd);
        $display("TB: 40MHz 连续写 DTCM 成功 %0d/16", okd);

        // 连续写 ITCM 16 字
        #500;
        oki = 0;
        cont_write(32'h00000000, 16, oki);
        $display("TB: 40MHz 连续写 ITCM 成功 %0d/16", oki);

        $display("=== 复现完成（DTCM %0d/16, ITCM %0d/16）===", okd, oki);
        $finish;
    end

    initial begin
        #20_000_000;  // 20ms 超时
        $display("TB: TIMEOUT");
        $finish;
    end
endmodule
