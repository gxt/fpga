// rvv_defines.svh —— RVV 核编译宏（必须在 RvvCoreMiniAxi.sv 之前编译）
//
// RvvCoreMiniAxi.sv 内 `ifdef VLEN_128 / RVVI_ON / ZVE32F_ON 控制 RVV 参数与
// 浮点向量指令使能。这些宏需先于核文件定义（read/add 顺序在最前）。
`define VLEN_128
`define ZVE32F_ON
