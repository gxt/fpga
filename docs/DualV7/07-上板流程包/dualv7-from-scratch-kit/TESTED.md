# DualV7 From-Scratch Kit Tested Result

Test date: 2026-06-08

## Scope

Validated end-to-end:

1. Prepare a clean remote build sandbox on `202`
2. Build `rocket64b2` verilog, Vivado project, bitstream, and `boot.elf`
3. Build local Linux `Image` and `ramdisk-realcheck`
4. Program board over JTAG
5. Stop U-Boot autoboot over UART
6. Boot local kernel + ramdisk
7. Observe `REALCHECK: READY`

## Remote sandbox

- Host: `zzx@192.168.200.202`
- Sandbox: `~/dualv7-from-scratch-r1`
- Base commit: `137a01660c63948368aafd31fdabaf742314acd1`

Note: because `202` is offline, the sandbox is source-clean and submodule-pinned, but Scala/SBT build caches are seeded from the existing validated tree to keep the Rocket quick path usable.

## Built artifacts

### Remote build outputs

- Bitstream:
  `~/dualv7-from-scratch-r1/workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit`
- Boot ELF:
  `~/dualv7-from-scratch-r1/workspace/boot.elf`

### Local copied artifacts

- Bitstream:
  `/home/data/vivado-risc-v/workspace/from-scratch-kit-r1/rocket64b2-clean.bit`
- Boot ELF:
  `/home/data/vivado-risc-v/workspace/from-scratch-kit-r1/boot-clean.elf`

## Hashes

- `rocket64b2-clean.bit`
  - sha256: `db8018a1e347b86d70105b18494e72f148b5b164c6a2ee90d994868da5a3e4c0`
- `boot-clean.elf`
  - sha256: `1170ff05bac097f3153da7fe9d0ca4083f66d64d7e21b3a980e44f19393dfc03`
- Linux `Image`
  - sha256: `b42657a24031a2a6d9fae6790955deafcf7175e2fb25a61739ba0343b744aa64`
- `ramdisk-realcheck`
  - sha256: `67ad8eecdc6d165b456d4e6f66fb61df264e5bcdacf6921f1619d858e3321b65`

## Board smoke result

Board smoke output directory:

- `/home/data/vivado-risc-v/workspace/from-scratch-kit-r1/board-smoke-clean`

Summary:

- `stopped_autoboot=True`
- `sent_booti=True`
- `markers=U-Boot,Starting kernel,Run /init as init process,REALCHECK: READY`

Observed runtime path:

- JTAG programming succeeded
- Boot ROM printed on UART
- OpenSBI printed on UART
- U-Boot printed on UART
- Linux booted
- `REALCHECK: READY` observed

## Vivado note

Implementation produced a valid bitstream, but timing was not clean. `write_bitstream` still succeeded.

This kit is therefore validated for:

- clean Rocket quick iteration
- compile/synth/impl/bit generation
- board smoke over JTAG + UART

It is not a statement that the routed design is timing-clean.
