// uart_tx.sv —— UART 发送器（8N1）
//
// 握手：tx_valid 与 tx_data 在 tx_busy=0 时给出（单拍），模块捕获后开始发送；
//       tx_busy 高电平表示正在发送（不应再给新字节）。
// 时钟参数：CLK_HZ 为实际驱动时钟频率，BAUD 为波特率。
module uart_tx #(
    parameter int CLK_HZ = 50_000_000,
    parameter int BAUD   = 115200
)(
    input  logic clk,
    input  logic rst_n,
    input  logic tx_valid,
    input  logic [7:0] tx_data,
    output logic tx_busy,
    output logic tx_out
);
    localparam int DIV    = (CLK_HZ + (BAUD / 2)) / BAUD;   // 每 bit 的时钟周期数（四舍五入）
    localparam int DIVW   = $clog2(DIV + 1);

    logic                busy_r;
    logic [DIVW-1:0]     cnt;
    logic [3:0]          bit_idx;            // 0=start, 1..8=data, 9=stop
    logic [8:0]          shreg;              // [8:1]=data[7:0], [0]=当前发送位

    assign tx_out = busy_r ? shreg[0] : 1'b1;  // 空闲时保持高电平
    assign tx_busy = busy_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_r  <= 1'b0;
            cnt     <= '0;
            bit_idx <= '0;
            shreg   <= 9'h1FF;
        end else if (!busy_r && tx_valid) begin
            busy_r  <= 1'b1;
            cnt     <= '0;
            bit_idx <= 4'd0;
            shreg   <= {tx_data, 1'b0};      // bit0 = start 位
        end else if (busy_r) begin
            if (cnt == DIV - 1) begin
                cnt <= '0;
                if (bit_idx == 4'd9) begin
                    busy_r <= 1'b0;          // stop 位发送完毕
                end else begin
                    bit_idx <= bit_idx + 1'b1;
                    shreg   <= {1'b1, shreg[8:1]};  // 右移，高位补 1
                end
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule
