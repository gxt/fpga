// T007: 自定义测试程序 - 标量浮点 + 整数 + ZBB + TCM 回读自校验
//
// 覆盖 ISA/模块特性（core_mini_axi 配置，scalar-only + FP）：
//   - RV32I : add/addi/sw/lw 等标量指令
//   - RV32M : mul（标量乘法单元 MLU）
//   - RV32F : flw/fadd.s/fsw（标量浮点单元 FPU）
//   - ZBB   : clz 指令
//   - CSR   : mstatus FS 置位（crt0）、mpause（退出，STATUS.HALTED=1）
//   - DTCM  : 程序把结果写回 DTCM（.data 段）并读回自校验（TCM 回读）
//
// 判定方式：程序内自校验，全部预期值一致返回 0（crt0 success -> mpause ->
// halted -> sim exit 0）；任一不一致返回非 0（crt0 failure -> ebreak ->
// fault -> sim exit 1）。
// 浮点精度：本测试选取可精确表示的值，预期 bit-exact（0 ULP）。

#include <stdint.h>

// 输入/输出放 .data（DTCM，0x10000 起），运行前由 ELF 加载进 DTCM。
int32_t in_a[4] __attribute__((section(".data"))) = {100, 200, 300, 400};
int32_t in_b[4] __attribute__((section(".data"))) = {7, 8, 9, 10};
int32_t out_mul[4] __attribute__((section(".data")));
float fin_a[4] __attribute__((section(".data"))) = {1.5f, 2.25f, 3.125f, 4.5f};
float fin_b[4] __attribute__((section(".data"))) = {0.5f, 0.75f, 1.875f, 2.5f};
float fout[4] __attribute__((section(".data")));

// 预期值放 .rodata（ITCM）。整数按位精确；浮点 bit-exact（0 ULP）。
const int32_t exp_mul[4] = {700, 1600, 2700, 4000};
const float exp_fadd[4] = {2.0f, 3.0f, 5.0f, 7.0f};

int main() {
  // 1) 标量整数乘法（RV32M mul）：out_mul[i] = in_a[i] * in_b[i]
  for (int i = 0; i < 4; i++) {
    out_mul[i] = in_a[i] * in_b[i];
  }

  // 2) 标量浮点加法（RV32F fadd.s）：fout[i] = fin_a[i] + fin_b[i]
  for (int i = 0; i < 4; i++) {
    fout[i] = fin_a[i] + fin_b[i];
  }

  // 3) ZBB clz：0xF000 的 32 位前导零个数 = 16
  uint32_t clz_res = 0;
  {
    uint32_t x = 0x0000F000u;
    // 手工展开前导零计数（避免依赖 libgcc 的 clz 实现，确保生成 clz 指令）
    asm volatile("clz %0, %1" : "=r"(clz_res) : "r"(x));
  }

  // 4) TCM 回读自校验：读回 DTCM 中结果，与预期值逐项比对。
  for (int i = 0; i < 4; i++) {
    if (out_mul[i] != exp_mul[i]) return 1;  // 整数按位精确
    if (fout[i] != exp_fadd[i]) return 2;    // 浮点 bit-exact（0 ULP）
  }
  if (clz_res != 16) return 3;  // clz 结果校验
  return 0;
}
