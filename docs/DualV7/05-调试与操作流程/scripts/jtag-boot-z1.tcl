connect -url tcp:localhost:3121
targets 1
fpga -file /home/data/vivado-risc-v/workspace/experiments/dualv7-test/035x/rocket64z1.bit
after 10000
targets 1
targets -set -filter {name =~ "Hart #0*"}
stop
dow -clear /home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
after 3000
exit
