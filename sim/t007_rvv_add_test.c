// T007: 自定义测试程序 - RVV 向量加法 + TCM 回读自校验
//
// 覆盖 ISA/模块特性（rvv_core_mini_axi 配置，RVV + FP）：
//   - RVV (zve32f) : vsetvli / vle32.v / vadd.vv / vfadd.vv / vse32.v
//     （RvvCore 后端：vadd 走 rvv_backend ALU，vfadd 走 rvv_backend FALU，
//      向量 load/store 走 LSU uop 经标量 LSU 访存 DTCM）
//   - RV32F : 标量浮点 fadd.s（标量 FPU，与向量 FP 并行验证）
//   - CSR   : mpause 退出（STATUS.HALTED=1）
//   - DTCM  : 结果写回 DTCM（.data 段）并读回自校验（TCM 回读）
//
// 判定方式：程序内自校验，全部预期值一致返回 0（sim exit 0）；
// 任一不一致返回非 0（sim exit 1）。浮点 bit-exact（0 ULP）。

#include <riscv_vector.h>
#include <stdint.h>

// 输入/输出放 .data（DTCM）。int 与 float 两组。
int32_t in_a[16] __attribute__((section(".data"))) = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
int32_t in_b[16] __attribute__((section(".data"))) = {
    100, 200, 300, 400, 500, 600, 700, 800,
    900, 1000, 1100, 1200, 1300, 1400, 1500, 1600};
int32_t out_add[16] __attribute__((section(".data")));

float fin_a[16] __attribute__((section(".data"))) = {
    1.0f,  2.0f,  3.0f,  4.0f,  5.0f,  6.0f,  7.0f,  8.0f,
    9.0f,  10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
float fin_b[16] __attribute__((section(".data"))) = {
    0.5f,  1.0f,  1.5f,  2.0f,  2.5f,  3.0f,  3.5f,  4.0f,
    4.5f,  5.0f,  5.5f,  6.0f,  6.5f,  7.0f,  7.5f,  8.0f};
float fout_add[16] __attribute__((section(".data")));

// 标量浮点输入（验证标量 FPU 与 RVV 共存）
float sin_a[4] __attribute__((section(".data"))) = {1.5f, 2.25f, 3.125f, 4.5f};
float sin_b[4] __attribute__((section(".data"))) = {0.5f, 0.75f, 1.875f, 2.5f};
float sout[4] __attribute__((section(".data")));

// 预期值放 .rodata（ITCM）。
// int 加：i + 100*i = 101*i，i=1..16 -> 101, 202, ..., 1616
// float 加：i + (i/2) = 1.5*i，全部可精确表示 -> bit-exact
const int32_t exp_add[16] = {101, 202, 303, 404, 505, 606, 707, 808,
                             909, 1010, 1111, 1212, 1313, 1414, 1515, 1616};
const float exp_fadd[16] = {1.5f, 3.0f, 4.5f, 6.0f, 7.5f, 9.0f, 10.5f, 12.0f,
                            13.5f, 15.0f, 16.5f, 18.0f, 19.5f, 21.0f, 22.5f, 24.0f};
const float exp_sadd[4] = {2.0f, 3.0f, 5.0f, 7.0f};

int main() {
  // 1) RVV 整数向量加法：vle32.v + vadd.vv + vse32.v
  //    VLEN=128，int32 元素，一次处理 4 个（LMUL=1）。
  const size_t vl = 4;  // 128 / 32
  for (int i = 0; i < 16; i += 4) {
    vint32m1_t va = __riscv_vle32_v_i32m1(&in_a[i], vl);
    vint32m1_t vb = __riscv_vle32_v_i32m1(&in_b[i], vl);
    vint32m1_t vs = __riscv_vadd_vv_i32m1(va, vb, vl);
    __riscv_vse32_v_i32m1(&out_add[i], vs, vl);
  }

  // 2) RVV 浮点向量加法：vle32.v + vfadd.vv + vse32.v
  for (int i = 0; i < 16; i += 4) {
    vfloat32m1_t va = __riscv_vle32_v_f32m1(&fin_a[i], vl);
    vfloat32m1_t vb = __riscv_vle32_v_f32m1(&fin_b[i], vl);
    vfloat32m1_t vs = __riscv_vfadd_vv_f32m1(va, vb, vl);
    __riscv_vse32_v_f32m1(&fout_add[i], vs, vl);
  }

  // 3) 标量浮点加法（RV32F fadd.s，与 RVV 并行验证）
  for (int i = 0; i < 4; i++) {
    sout[i] = sin_a[i] + sin_b[i];
  }

  // 4) TCM 回读自校验：读回 DTCM 中结果，与预期值逐项比对。
  for (int i = 0; i < 16; i++) {
    if (out_add[i] != exp_add[i]) return 1;   // 整数按位精确
    if (fout_add[i] != exp_fadd[i]) return 2; // 浮点 bit-exact（0 ULP）
  }
  for (int i = 0; i < 4; i++) {
    if (sout[i] != exp_sadd[i]) return 3;     // 标量浮点 bit-exact
  }
  return 0;
}
