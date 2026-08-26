// T022-tb_soc.sv —— 验证 host→Axi2TLUL→Xbar→核 加载通路（xsim，机器202）
//
// 基于 M1 已验证的 T010-tb_top.sv（UART 收发/接收器/recv task 原样复用），只改 DUT 例化：
//   top_coralnpu_soc（裁剪 SoC：CoreTlul + Xbar + uart_host 桥）
//
// 验证：W 加载 4 指令到 ITCM → S 启动 → Q 轮询 HALTED → R 回读 DTCM=42 → LED/HELP/ERR
// 时钟：USE_MMCM=0（clk_p 直连 clk_core，20MHz）；UART 115200
module tb_soc;
    logic clk_p = 1'b0;
    logic clk_n = 1'b0;
    logic rst_btn_n = 1'b0;
    logic uart_rx = 1'b1;      // DUT 接收（TB 发送）
    logic uart_tx;             // DUT 发送（TB 接收）
    logic led_halted, led_fault, led_locked;
    logic [2:0] gpio_led;

    top_coralnpu_soc #(
        .CORE_CLK_HZ (20_000_000),
        .BAUD        (115200),
        .USE_MMCM    (0)
    ) u_dut (
        .clk_p(clk_p), .clk_n(clk_n), .rst_btn_n(rst_btn_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .led_halted(led_halted), .led_fault(led_fault), .led_locked(led_locked),
        .gpio_led(gpio_led)
    );

    always #25 clk_p = ~clk_p;   // 20MHz

    localparam int BIT_NS = 8680;  // 20MHz, 115200 baud

    // ---- 发送 ----
    task send_bit(input logic b); uart_rx = b; #(BIT_NS); endtask
    task send_byte(input logic [7:0] byte_in);
        send_bit(1'b0);                      // start
        for (int i = 0; i < 8; i++) send_bit(byte_in[i]);  // LSB first
        send_bit(1'b1);                      // stop
    endtask
    task send_str(input string s);
        for (int i = 0; i < s.len(); i++) send_byte(s[i]);
    endtask

    // ---- TB 串口接收器（队列，M1 验证过的模式） ----
    logic [7:0] rx_byte_q [$];
    int rx_errors = 0;

    always begin
        @(negedge uart_tx);
        #(BIT_NS / 2);
        if (uart_tx === 1'b0) begin
            logic [7:0] sh = 8'h0;
            for (int i = 0; i < 8; i++) begin
                #(BIT_NS);
                sh = {uart_tx, sh[7:1]};
            end
            #(BIT_NS);
            if (uart_tx !== 1'b1) begin
                $display("TB: RX framing error");
                rx_errors++;
            end else begin
                rx_byte_q.push_back(sh);
            end
        end
    end

    // ---- 主测试序列 ----
    int test_fail = 0;
    string exp_str;
    int exp_idx;
    logic [7:0] rx_last_byte;

    task automatic recv_byte();
        wait (rx_byte_q.size() > 0);
        rx_last_byte = rx_byte_q.pop_front();
    endtask

    task automatic recv_expect_str(input string s);
        for (int i = 0; i < s.len(); i++) begin
            recv_byte();
            if (rx_last_byte != s[i]) begin
                $display("TB: MISMATCH idx=%0d got=0x%02x('%c') exp=0x%02x('%c')",
                         i, rx_last_byte, rx_last_byte, s[i], s[i]);
                test_fail = 1;
            end
        end
        $display("TB: recv_expect_str OK: %s", s);
    endtask

    logic [31:0] hex_data_out;
    task automatic hex_digit(input logic [7:0] c, output logic [3:0] v);
        if (c >= "0" && c <= "9") v = c - "0";
        else if (c >= "A" && c <= "F") v = c - "A" + 10;
        else v = c - "a" + 10;
    endtask
    task automatic recv_hex_line(input string addr_hex);
        string got = "";
        logic [3:0] nib;
        for (int i = 0; i < 8; i++) begin
            recv_byte();
            got = {got, rx_last_byte};
        end
        if (got != addr_hex) begin
            $display("TB: LINE addr mismatch got=%s exp=%s", got, addr_hex);
            test_fail = 1;
        end
        hex_data_out = 32'h0;
        for (int i = 0; i < 8; i++) begin
            recv_byte();
            hex_digit(rx_last_byte, nib);
            hex_data_out = (hex_data_out << 4) | nib;
        end
        recv_byte();                         // '\n'
        if (rx_last_byte != "\n") begin
            $display("TB: LINE missing newline got=0x%02x", rx_last_byte);
            test_fail = 1;
        end
        $display("TB: recv_hex_line %s = 0x%08x", addr_hex, hex_data_out);
    endtask

    initial begin
        #200;                          // 复位保持
        rst_btn_n = 1'b1;
        $display("TB: reset released");

        // ---- 1) 加载程序到 ITCM ----
        $display("TB: == load program to ITCM ==");
        send_str("W0000000002a00293\n");
        recv_expect_str("OK\n");
        send_str("W0000000400010137\n");
        recv_expect_str("OK\n");
        send_str("W0000000800512023\n");
        recv_expect_str("OK\n");
        send_str("W0000000c08000073\n");
        recv_expect_str("OK\n");
        $display("TB: program loaded");

        // ---- 2) 启动 core ----
        $display("TB: == start core (S) ==");
        send_str("S\n");
        recv_expect_str("OK\n");
        $display("TB: core started");

        // ---- 3) 轮询 Q 直到 HALTED ----
        $display("TB: == poll status until halted ==");
        begin
            int halted_seen = 0;
            for (int i = 0; i < 50; i++) begin
                send_str("Q\n");
                recv_hex_line("00030008");
                recv_expect_str("OK\n");
                if (hex_data_out[0]) begin
                    $display("TB: HALTED detected (status=0x%08x) on poll %0d", hex_data_out, i);
                    halted_seen = 1;
                    break;
                end
            end
            if (!halted_seen) begin
                $display("TB: FAIL: core did not halt after 50 polls");
                test_fail = 1;
            end
        end

        // ---- 4) 回读 DTCM ----
        $display("TB: == readback DTCM 0x10000 ==");
        begin
            send_str("R0001000001\n");
            recv_hex_line("00010000");
            recv_expect_str("OK\n");
            if (hex_data_out != 32'h2A) begin
                $display("TB: FAIL: DTCM[0x10000]=0x%08x exp 0x2A", hex_data_out);
                test_fail = 1;
            end else begin
                $display("TB: DTCM[0x10000]=42 OK");
            end
        end

        // ---- 5) LED 检查 ----
        if (led_halted !== 1'b1) begin
            $display("TB: FAIL: led_halted not set");
            test_fail = 1;
        end else begin
            $display("TB: led_halted=1 OK");
        end
        if (led_fault !== 1'b0) begin
            $display("TB: FAIL: led_fault should be 0");
            test_fail = 1;
        end else begin
            $display("TB: led_fault=0 OK");
        end

        // ---- 6) 帮助命令 ----
        send_str("?\n");
        recv_expect_str("HELP\n");

        // ---- 7) 错误路径 ----
        send_str("X123\n");
        recv_expect_str("ERR\n");

        $display("TB: ==== TEST DONE ====");
        if (test_fail == 0 && rx_errors == 0) begin
            $display("TB: *** ALL CHECKS PASSED ***");
        end else begin
            $display("TB: *** TEST FAILED: test_fail=%0d rx_errors=%0d ***",
                     test_fail, rx_errors);
        end
        $finish;
    end
endmodule
