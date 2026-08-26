// T022-tb_soc.sv —— 验证 host→Axi2TLUL→Xbar→核 加载通路（xsim，机器202）
//
// 目标：验证裁剪 SoC（CoralNPUChiselSubsystem）的 r/w 通路：
//   1) W 命令加载 4 指令到 ITCM（0x0-0xc）
//   2) S 命令启动 core
//   3) R 命令轮询 CSR 0x30008（STATUS）直到 HALTED=1
//   4) R 命令回读 DTCM 0x10000，验证程序写出的 42
//
// 测试程序：addi x5,x0,42 → lui x2,0x10 → sw x5,0(x2) → mpause
// 时钟：USE_MMCM=0（clk_p 直连 clk_core，20MHz）；UART 115200
module tb_soc;
    logic clk_p = 1'b0;
    logic clk_n = 1'b0;
    logic rst_btn_n = 1'b0;
    logic uart_rx = 1'b1;
    logic uart_tx = 1'b1;   // 初始 idle 高，避免 x 触发 negedge
    logic led_halted, led_fault, led_locked;
    logic [2:0] gpio_led;
    logic [31:0] st;
    logic [31:0] dtcm;

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

    task send_bit(input logic b); uart_rx = b; #(BIT_NS); endtask
    task send_byte(input logic [7:0] byte_in);
        send_bit(1'b0);                      // start
        for (int i = 0; i < 8; i++) send_bit(byte_in[i]);  // LSB first
        send_bit(1'b1);                      // stop
    endtask
    task send_str(input string s);
        foreach (s[i]) send_byte(s[i]);
    endtask

    // 接收一个字节（UART TX）
    logic [7:0] rx_buf = 8'h0;
    logic rx_done = 1'b0;
    always @(negedge uart_tx) begin
        #(BIT_NS / 2);
        if (uart_tx === 1'b0) begin
            rx_buf = 8'h0;
            for (int i = 0; i < 8; i++) begin
                #(BIT_NS);
                rx_buf[i] = uart_tx;
            end
            #(BIT_NS);
            rx_done = 1'b1;
        end
    end

    // 等待并收集 DUT 响应（直到 timeout）
    task expect_rx(input string pat, input int timeout_us = 1000);
        int cnt;
        string got;
        rx_done = 1'b0;
        got = "";
        cnt = 0;
        while (cnt < timeout_us) begin
            @(posedge clk_p);
            cnt++;
            if (rx_done) begin
                got = {got, string'(rx_buf)};
                rx_done = 1'b0;
                if (got.len() >= pat.len() && got.substr(got.len()-pat.len(), got.len()-1) == pat) begin
                    $display("TB: recv OK (%s)", got);
                    return;
                end
            end
        end
        $display("TB: TIMEOUT waiting %s, got=%s", pat, got);
        $finish;
    endtask

    // 读一个 32 位字（R 命令）
    task read_word(input logic [31:0] addr, output logic [31:0] val);
        string got;
        int cnt;
        rx_done = 1'b0;
        got = "";
        cnt = 0;
        $sformat(got, "");
        // 发 R 命令
        send_str($sformatf("R%08X01\n", addr));
        while (cnt < 2000) begin
            @(posedge clk_p);
            cnt++;
            if (rx_done) begin
                got = {got, string'(rx_buf)};
                rx_done = 1'b0;
                if (got.len() >= 16 && got.substr(0,7) == $sformatf("%08X", addr)) begin
                    val = got.substr(8, 15).atohex();
                    $display("TB: recv_hex_line %08X = 0x%08X", addr, val);
                    return;
                end
            end
        end
        $display("TB: read_word TIMEOUT addr=%08X got=%s", addr, got);
        $finish;
    endtask

    initial begin
        // 复位释放
        rst_btn_n = 1'b0;
        #(100);
        rst_btn_n = 1'b1;
        #(200);

        // 诊断：top 内部时钟/复位/host 状态
        $display("TB: diag clk_core=%b rst_n=%b locked=%b uart_rx_valid=%b uart_tx=%b",
                 u_dut.clk_core, u_dut.rst_n, u_dut.mmcm_locked, u_dut.uart_rx_valid, uart_tx);
        #(100);
        $display("TB: diag2 uart_rx_valid=%b", u_dut.uart_rx_valid);

        // 0) UART 通路
        rx_done = 1'b0;
        send_str("?\n");
        expect_rx("HELP");

        // 1) 加载 4 指令到 ITCM
        send_str("W0000000002A00293\n"); expect_rx("OK");
        send_str("W0000000400010137\n"); expect_rx("OK");
        send_str("W0000000800512023\n"); expect_rx("OK");
        send_str("W0000000C08000073\n"); expect_rx("OK");

        // 2) 启动
        send_str("S\n"); expect_rx("OK");
        $display("TB: core started");

        // 3) 轮询 STATUS（R 读 0x30008）直到 HALTED
        for (int i = 0; i < 100; i++) begin
            read_word(32'h00030008, st);
            if (st & 1) begin
                $display("TB: HALTED detected (status=0x%08X)", st);
                break;
            end
        end

        // 4) 回读 DTCM 0x10000（应=42）
        read_word(32'h00010000, dtcm);
        if (dtcm == 32'h2A) begin
            $display("TB: DTCM[0x10000]=42 OK");
        end else begin
            $display("TB: DTCM[0x10000]=0x%08X FAIL (expect 42)", dtcm);
            $finish;
        end

        $display("TB: ==== T022: r/w 通路验证完成 ====");
        $finish;
    end
endmodule
