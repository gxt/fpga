connect -url tcp:localhost:3121
targets 1
fpga -file /home/data/vivado-risc-v/workspace/release-r2/rocket64b2-r2.bit
targets -set -filter {name =~ "Hart #0*"}
stop
dow -clear /home/data/vivado-risc-v/workspace/release-r2/boot-r2.elf
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
exit
