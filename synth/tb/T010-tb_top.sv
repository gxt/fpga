// tb_top.sv —— top_coralnpu 功能验证 testbench（xsim）
//
// 目标：验证 host 桥（UART→AXI）驱动真实 CoreMiniAxi 的完整链路：
//   1) W 命令加载 4 条指令到 ITCM（0x0-0xc）
//   2) S 命令启动 core（PC_START=0，释放复位）
//   3) Q 命令轮询 CSR 0x30008 直到 HALTED=1
//   4) R 命令回读 DTCM 0x10000，验证程序写出的 42
//   5) LED/help/错误路径检查
//
// 测试程序（rv32i，运行后 mpause 停机）：
//   0x0: 0x02A00293 addi x5, x0, 42
//   0x4: 0x00010137  lui  x2, 0x10        # x2 = 0x10000 (DTCM base)
//   0x8: 0x00512023  sw   x5, 0(x2)       # DTCM[0x10000] = 42
//   0xc: 0x08000073  mpause               # halted
//
// 时钟：USE_MMCM=0（clk_p 直连 clk_core，50MHz），避免 MMCM 仿真模型 VCO 爬升问题。
// UART：BAUD=781250，RX DIV=4、TX DIV=64，位周期均 1280ns。
// 注意：不加 `timescale —— CoreMiniAxi.sv（firtool 生成）无 timescale，
//       xsim 默认按 1ns/1ps 处理全局。
module tb_top;
    // ---- DUT 信号 ----
    logic clk_p = 1'b0;
    logic clk_n = 1'b0;
    logic rst_btn_n = 1'b0;
    logic uart_rx = 1'b1;      // DUT 接收（TB 发送）
    logic uart_tx;             // DUT 发送（TB 接收）
    logic led_halted, led_fault, led_locked;

    top_coralnpu #(
        .CORE_CLK_HZ (50_000_000),   // 仿真 clk_p 实际 50MHz（USE_MMCM=0 直连）
        .BAUD        (781250),
        .USE_MMCM    (0)
    ) u_dut (
        .clk_p     (clk_p),
        .clk_n     (clk_n),
        .rst_btn_n (rst_btn_n),
        .uart_rx   (uart_rx),
        .uart_tx   (uart_tx),
        .led_halted(led_halted),
        .led_fault (led_fault),
        .led_locked(led_locked)
    );

    // ---- 时钟：50MHz（20ns 周期，直连 clk_core） ----
    always #10 clk_p = ~clk_p;

    // ---- 串口位参数（DUT BAUD=781250, clk_core=50MHz） ----
    // RX DIV = 50e6/(781250*16)=4，TX DIV = 50e6/781250=64，位周期 = 64×20 = 1280ns
    localparam int BIT_NS = 1280;

    // ==================== TB 串口发送器 ====================
    task send_bit(input logic b);
        uart_rx = b;
        #(BIT_NS);
    endtask
    task send_byte(input logic [7:0] byte_in);
        send_bit(1'b0);                      // start
        for (int i = 0; i < 8; i++) begin
            send_bit(byte_in[i]);            // LSB first
        end
        send_bit(1'b1);                      // stop
    endtask
    task send_str(input string s);
        for (int i = 0; i < s.len(); i++) begin
            send_byte(s[i]);
        end
    endtask

    // ==================== TB 串口接收器 ====================
    // 检测 start 位下降沿后逐位采样，推入字节队列
    logic [7:0] rx_byte_q [$];
    int rx_errors = 0;

    // start 沿后采 start 位中点（BIT_NS/2），然后每隔 BIT_NS 采各数据位中点
    always begin
        @(negedge uart_tx);
        #(BIT_NS / 2);
        if (uart_tx === 1'b0) begin
            logic [7:0] sh = 8'h0;
            for (int i = 0; i < 8; i++) begin
                #(BIT_NS);
                sh = {uart_tx, sh[7:1]};
            end
            #(BIT_NS);                       // stop 位中点
            if (uart_tx !== 1'b1) begin
                $display("TB: RX framing error");
                rx_errors++;
            end else begin
                rx_byte_q.push_back(sh);
            end
        end else begin
            $display("TB: RX false start");
            rx_errors++;
        end
    end

    // ==================== 主测试序列 ====================
    int test_fail = 0;
    string exp_str;
    int exp_idx;
    logic [7:0] rx_last_byte;

    // 接收一个字节（阻塞）到 rx_last_byte
    task automatic recv_byte();
        wait (rx_byte_q.size() > 0);
        rx_last_byte = rx_byte_q.pop_front();
    endtask

    // 按期望字符串接收 n 个字节
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

    // 接收 Q/R 的一行："<8hex addr><8hex data>\n"，结果存 hex_data_out
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

    // 超时保护
    initial begin
        #20_000_000;
        $display("TB: TIMEOUT");
        $finish;
    end
endmodule
