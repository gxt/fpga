connect -url tcp:localhost:3121
targets 1
fpga -file /home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/rocket64z2m-r3.bit
targets -set -filter {name =~ "Hart #0*"}
stop
dow -clear /home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/boot-r3.elf
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
exit
