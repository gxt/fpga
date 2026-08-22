// T017-tb_rvv_elf.sv —— RVV 核上板前 xsim 仿真：加载 t007_rvv ELF → 启动 → 回读验证
//
// 流程（复用 UART host 通路，与上板一致）：
//   1) 从 WCMD_FILE（gen_wcmd.py 生成的 W 命令文件）逐条 W 命令加载 ELF 到 ITCM/DTCM
//   2) S 启动 → Q 轮询 CSR_STATUS(0x30008) bit0=HALTED
//   3) R 回读 DTCM 结果数组比对：
//        out_add[16] @ 0x10080  = {101,202,...,1616}     （RVV int vadd）
//        fout_add[16] @ 0x10140 = {1.5,3.0,...,24.0}     （RVV fp vfadd）
//        sout[4]      @ 0x101A0 = {2.0,3.0,5.0,7.0}      （标量浮点）
module tb_rvv_elf;
    logic clk_p = 1'b0, clk_n = 1'b0;
    logic rst_btn_n = 1'b0;
    logic uart_rx = 1'b1, uart_tx;
    logic led_halted, led_fault, led_locked;

    top_coralnpu_rvv #(
        .CORE_CLK_HZ (50_000_000),
        .BAUD        (1_562_500),
        .USE_MMCM    (0)
    ) u_dut (
        .clk_p(clk_p), .clk_n(clk_n), .rst_btn_n(rst_btn_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .led_halted(led_halted), .led_fault(led_fault), .led_locked(led_locked)
    );

    always #10 clk_p = ~clk_p;
    localparam int BIT_NS = 640;

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
        recv_byte();  // 消费 \n
        hexval = v;
    endtask

    // R 命令回读 count 个字（每字一行 addr+data，结尾 OK）
    task automatic r_words(input logic [31:0] addr, input int count, output logic [31:0] data_q[$]);
        send_str($sformatf("R%08X%02X\n", addr, count));
        data_q.delete();
        for (int i = 0; i < count; i++) begin
            logic [31:0] v;
            recv_hexline(v);
            data_q.push_back(v);
        end
        recv_expect_str("OK\n");
    endtask

    initial begin
        string line;
        integer fd;
        logic [31:0] got;
        int found;

        #100;
        rst_btn_n = 1'b1;
        #1000;
        rx_byte_q.delete();
        #500;

        $display("=== T017: RVV 核加载 t007_rvv ELF（UART host 通路）===");

        // 1) 加载 ELF（W 命令文件，每条等待 OK 确认）
        fd = $fopen(`WCMD_FILE, "r");
        if (!fd) begin $display("TB: FAIL WCMD_FILE 打开失败"); $finish; end
        while (!$feof(fd)) begin
            if ($fgets(line, fd)) begin
                send_str(line);
                recv_expect_str("OK\n");
            end
        end
        $fclose(fd);
        $display("TB: ELF 加载完成（W 命令）");

        // 2) S 启动
        send_str("S\n");
        recv_expect_str("OK\n");
        $display("TB: S 启动 OK");

        // 3) Q 轮询 HALTED
        found = 0;
        for (int i = 0; i < 2000 && !found; i++) begin
            send_str("Q\n");
            recv_hexline(got);
            recv_expect_str("OK\n");
            if (got & 32'h1) found = 1;
            #1000;
        end
        $display("TB: HALTED %0d（CSR_STATUS=%08X）", found, got);
        if (!found) begin test_fail = 1; $display("TB: 核未进入 HALTED"); end

        // 4) R 回读结果数组比对（程序自校验；外部比对做双保险）
        begin
            logic [31:0] q[$];
            int exp_add[16] = '{101,202,303,404,505,606,707,808,909,1010,1111,1212,1313,1414,1515,1616};
            int exp_fadd[16] = '{32'h3FC00000,32'h40400000,32'h40900000,32'h40C00000,
                                 32'h40F00000,32'h41100000,32'h41280000,32'h41400000,
                                 32'h41580000,32'h41700000,32'h41840000,32'h41900000,
                                 32'h419C0000,32'h41A80000,32'h41B40000,32'h41C00000};
            int exp_sadd[4] = '{32'h40000000,32'h40400000,32'h40A00000,32'h40E00000};
            int ok = 1;
            // out_add @ 0x10080
            r_words(32'h00010080, 16, q);
            for (int i = 0; i < 16; i++) begin
                if (q[i] != exp_add[i]) begin $display("TB: FAIL out_add[%0d]=%08X exp %08X", i, q[i], exp_add[i]); ok = 0; end
            end
            if (ok) $display("TB: PASS out_add（int vadd 101..1616）");
            // fout_add @ 0x10140
            ok = 1;
            r_words(32'h00010140, 16, q);
            for (int i = 0; i < 16; i++) begin
                if (q[i] != exp_fadd[i]) begin $display("TB: FAIL fout_add[%0d]=%08X exp %08X", i, q[i], exp_fadd[i]); ok = 0; end
            end
            if (ok) $display("TB: PASS fout_add（fp vfadd 1.5..24.0）");
            // sout @ 0x101A0
            ok = 1;
            r_words(32'h000101A0, 4, q);
            for (int i = 0; i < 4; i++) begin
                if (q[i] != exp_sadd[i]) begin $display("TB: FAIL sout[%0d]=%08X exp %08X", i, q[i], exp_sadd[i]); ok = 0; end
            end
            if (ok) $display("TB: PASS sout（标量 fp 2.0/3.0/5.0/7.0）");
        end

        if (test_fail) $display("=== T017: FAIL ===");
        else           $display("=== T017: ALL CHECKS PASSED ===");
        $finish;
    end

    initial begin
        #800_000_000;   // 800ms 超时（380 条 W 命令加载 + RVV 程序运行）
        $display("TB: TIMEOUT");
        $finish;
    end
endmodule
