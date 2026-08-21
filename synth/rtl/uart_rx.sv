// uart_rx.sv —— UART 接收器（8N1，16x 过采样）
//
// 检测起始位下降沿后按波特率 16x 采样，在每个 bit 中间（第 8 个采样点）采样。
// rx_valid 在完整收到一个字节后置位一周期；rx_busy 高表示正在接收。
module uart_rx #(
    parameter int CLK_HZ = 50_000_000,
    parameter int BAUD   = 115200
)(
    input  logic clk,
    input  logic rst_n,
    input  logic rx_in,
    output logic rx_valid,
    output logic [7:0] rx_data,
    output logic rx_busy
);
    // 16x 过采样：DIV = 每 1/16 bit 的时钟周期数；bit 周期 = 16 × DIV 个时钟
    // 四舍五入取整（避免向下取整引入 ~3.3% 波特率偏差导致长命令偶发 RX 错）
    localparam int DIV    = (CLK_HZ + (BAUD * 8)) / (BAUD * 16);
    localparam int DIVW   = $clog2(DIV + 1);

    logic              busy_r;
    logic [DIVW-1:0]   clk_cnt;
    logic [3:0]        osr_cnt;              // 0..15，bit 内 16 份
    logic [3:0]        bit_idx;              // 0=start, 1..8=data, 9=stop
    logic [7:0]        shreg;
    logic              valid_r;
    // 异步输入同步（2 级寄存器，消除亚稳态；空闲=1 防误触发起始位）
    logic              rx_q1, rx_q2;

    assign rx_busy   = busy_r;
    assign rx_valid  = valid_r;
    assign rx_data   = shreg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_q1 <= 1'b1;
            rx_q2 <= 1'b1;
        end else begin
            rx_q1 <= rx_in;
            rx_q2 <= rx_q1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_r   <= 1'b0;
            clk_cnt  <= '0;
            osr_cnt  <= '0;
            bit_idx  <= '0;
            shreg    <= '0;
            valid_r  <= 1'b0;
        end else begin
            valid_r <= 1'b0;
            if (!busy_r) begin
                // 空闲：检测起始位下降沿
                if (!rx_q2) begin
                    busy_r  <= 1'b1;
                    clk_cnt <= '0;
                    osr_cnt <= 4'd0;
                    bit_idx <= 4'd0;
                end
            end else if (clk_cnt == DIV - 1) begin
                clk_cnt <= '0;
                osr_cnt <= osr_cnt + 1'b1;
                if (osr_cnt == 4'd8) begin
                    // 每个 bit 的中间采样点
                    if (bit_idx == 4'd0) begin
                        if (rx_q2) begin
                            busy_r <= 1'b0;  // start 位非 0：帧错误，放弃
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else if (bit_idx >= 4'd1 && bit_idx <= 4'd8) begin
                        shreg   <= {rx_q2, shreg[7:1]};
                        bit_idx <= bit_idx + 1'b1;
                    end else begin
                        // stop 位：置 1 才算有效帧
                        busy_r <= 1'b0;
                        if (rx_q2) begin
                            valid_r <= 1'b1;
                        end
                    end
                end
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end
endmodule
