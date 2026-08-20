#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST=${REMOTE_HOST:-zzx@192.168.200.202}
REMOTE_DST=${REMOTE_DST:-/home/zzx/dualv7-from-scratch-r1}
BOARD=${BOARD:-dualv7}
CONFIG=${CONFIG:-rocket64b2}
MAX_THREADS=${MAX_THREADS:-1}

ssh -o BatchMode=yes "$REMOTE_HOST" \
    "bash -s" -- "$REMOTE_DST" "$BOARD" "$CONFIG" "$MAX_THREADS" <<'EOF'
set -euo pipefail

repo=$1
board=$2
config=$3
max_threads=$4
log_dir="$repo/logs"

run_step() {
    local name=$1
    shift
    echo "[run] $name"
    bash -lc "set -euo pipefail; $* 2>&1 | tee '$log_dir/$name.log'"
}

run_manual_step() {
    local name=$1
    echo "[run] $name"
    {
        set -euo pipefail
        manual_verilog
    } 2>&1 | tee "$log_dir/$name.log"
}

manual_verilog() {
    local config_scala
    local rocket_freq_mhz
    local rocket_clock_freq
    local rocket_timebase_freq
    local system_jar

    config_scala=${config/rocket/Rocket}
    rocket_freq_mhz=$(
        awk '$3 != "" && "'"$board"'" ~ $1 && "'"$config_scala"'" \
            ~ ("^" $2 "$") {print $3; exit}' board/rocket-freq
    )
    if [[ -z "$rocket_freq_mhz" ]]; then
        echo "failed to resolve ROCKET_FREQ_MHZ for $board/$config_scala" >&2
        exit 1
    fi
    rocket_clock_freq=$(
        awk -v mhz="$rocket_freq_mhz" 'BEGIN {printf("%.0f\n", mhz * 1000000)}'
    )
    rocket_timebase_freq=$(
        awk -v mhz="$rocket_freq_mhz" 'BEGIN {printf("%.0f\n", mhz * 10000)}'
    )
    system_jar=$(find target -path '*/system.jar' | head -n 1)
    if [[ -z "$system_jar" ]]; then
        echo "unable to locate seeded system.jar under target/" >&2
        exit 1
    fi
    system_jar=$(realpath "$system_jar")

    rm -rf "workspace/$config/tmp" "workspace/$config/system-$board"
    mkdir -p "workspace/$config/tmp" "workspace/$config/system-$board"

    cp rocket-chip/bootrom/bootrom.img workspace/bootrom.img

    "$JAVA_HOME/bin/java" -Xmx12G -Xss8M -cp "$system_jar" \
        freechips.rocketchip.diplomacy.Main \
        --dir "$(realpath workspace/$config/tmp)" \
        --top Vivado.RocketSystem \
        --config "Vivado.$config_scala"

    mv "workspace/$config/tmp/Vivado.$config_scala.dts" \
       "workspace/$config/system.dts"
    rm -rf "workspace/$config/tmp"

    cat "workspace/$config/system.dts" "board/$board/bootrom.dts" \
        >bootrom/system.dts

    sed -i \
        "s#reg = <0x80000000 *0x.*>#reg = <0x80000000 0x40000000>#g" \
        bootrom/system.dts
    sed -i \
        "s#reg = <0x0 0x80000000 *0x.*>#reg = <0x0 0x80000000 0x0 0x40000000>#g" \
        bootrom/system.dts
    sed -i \
        "s#clock-frequency = <[0-9]*>#clock-frequency = <$rocket_clock_freq>#g" \
        bootrom/system.dts
    sed -i \
        "s#timebase-frequency = <[0-9]*>#timebase-frequency = <$rocket_timebase_freq>#g" \
        bootrom/system.dts
    sed -i "/interrupts-extended = <&.* 65535>;/d" bootrom/system.dts

    make -C bootrom \
        CROSS_COMPILE="$(realpath workspace/gcc/riscv/bin)/riscv64-unknown-elf-" \
        CFLAGS="-march=rv64imac -mabi=lp64" \
        BOARD="$board" \
        clean bootrom.img

    mv bootrom/system.dts "workspace/$config/system-$board.dts"
    mv bootrom/bootrom.img workspace/bootrom.img

    "$JAVA_HOME/bin/java" -Xmx12G -Xss8M -cp "$system_jar" \
        freechips.rocketchip.diplomacy.Main \
        --dir "$(realpath workspace/$config/system-$board)" \
        --top Vivado.RocketSystem \
        --config "Vivado.$config_scala"

    "$JAVA_HOME/bin/java" -Xmx12G -Xss8M -cp "$system_jar" \
        firrtl.stage.FirrtlMain \
        -i "workspace/$config/system-$board/RocketSystem.fir" \
        -o RocketSystem.v \
        --compiler verilog \
        --annotation-file \
        "workspace/$config/system-$board/RocketSystem.anno.json" \
        --custom-transforms firrtl.passes.InlineInstances \
        --target:fpga

    cp "workspace/$config/system-$board/RocketSystem.v" \
       "workspace/$config/system-$board.v"
}

source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

mkdir -p "$log_dir"
cd "$repo"

rm -rf "workspace/$config"
rm -rf "workspace/$config/vivado-$board-riscv"

if ! run_step 01_verilog \
    "make -j\$(nproc) BOARD=$board CONFIG=$config \
    workspace/$config/system-$board.v"; then
    run_manual_step 01b_verilog_seeded_jar
fi

run_step 02_wrapper \
    "make BOARD=$board CONFIG=$config workspace/$config/rocket.vhdl"

run_step 03_vivado_project \
    "make BOARD=$board CONFIG=$config vivado-project"

run_step 04_bit \
    "make BOARD=$board CONFIG=$config MAX_THREADS=$max_threads \
    workspace/$config/vivado-$board-riscv/$board-riscv.runs/impl_1/\
riscv_wrapper.bit"

run_step 05_bootloader \
    "make -j\$(nproc) JTAG_BOOT=1 BOARD=$board CONFIG=$config bootloader"

sha256sum \
    "workspace/$config/vivado-$board-riscv/$board-riscv.runs/impl_1/\
riscv_wrapper.bit" \
    "workspace/boot.elf" \
    >"$log_dir/artifacts.sha256"

echo "build complete"
EOF
