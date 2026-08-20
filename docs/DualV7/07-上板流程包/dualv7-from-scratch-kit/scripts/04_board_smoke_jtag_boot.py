#!/usr/bin/env python3
import argparse
import os
import select
import subprocess
import termios
import time
from pathlib import Path

VIVADO_SETTINGS = "/tools/Xilinx/2025.1/Vivado/settings64.sh"
VIVADO_BIN = "/tools/Xilinx/2025.1/Vivado/bin"


def configure_uart(fd: int) -> None:
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] |= termios.CLOCAL | termios.CREAD | termios.CS8
    attrs[2] &= ~(termios.PARENB | termios.CSTOPB | termios.CRTSCTS)
    attrs[3] = 0
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIOFLUSH)


def write_tcl(path: Path, bit: Path, image: Path,
              ramdisk: Path, bootelf: Path) -> None:
    path.write_text(
        "\n".join(
            [
                "connect -url tcp:localhost:3121",
                "targets 1",
                f"fpga -file {bit}",
                'targets -set -filter {name =~ "Hart #0*"}',
                "stop",
                'targets -set -filter {name =~ "RISC-V*"}',
                f"dow -data {image} 0x81000000",
                f"dow -data {ramdisk} 0x85000000",
                'targets -set -filter {name =~ "Hart #0*"}',
                f"dow -clear {bootelf}",
                "rwr a0 0",
                "rwr a1 0x10080",
                "rwr s0 0x80000000",
                "con",
                "exit",
                "",
            ]
        ),
        encoding="utf-8",
    )


def run_smoke(args: argparse.Namespace) -> int:
    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    tcl = out_dir / "jtag-boot.tcl"
    uart_log = out_dir / "uart.log"
    xsdb_log = out_dir / "xsdb.log"
    summary = out_dir / "summary.txt"

    write_tcl(tcl, args.bit, args.image, args.ramdisk, args.bootelf)

    fd = os.open(str(args.uart), os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    configure_uart(fd)

    with uart_log.open("wb") as uartf, xsdb_log.open("wb") as xsdbf:
        xsdb = subprocess.Popen(
            [
                "/bin/bash",
                "-lc",
                f"source {VIVADO_SETTINGS} >/dev/null 2>&1; "
                f'pgrep -f "{VIVADO_BIN}/hw_server" >/dev/null || '
                f'"{VIVADO_BIN}/hw_server" -d >/tmp/from-scratch-hw-server.log 2>&1 & '
                f'sleep 2; "{VIVADO_BIN}/xsdb" -eval "source {tcl}"',
            ],
            stdout=xsdbf,
            stderr=subprocess.STDOUT,
        )

        buf = b""
        sent_booti = False
        stopped_autoboot = False
        deadline = time.time() + args.timeout_sec
        while time.time() < deadline:
            r, _, _ = select.select([fd], [], [], 0.2)
            if r:
                data = os.read(fd, 4096)
                if data:
                    uartf.write(data)
                    uartf.flush()
                    buf = (buf + data)[-262144:]

            if b"Hit any key to stop autoboot:" in buf and not stopped_autoboot:
                os.write(fd, b"\r")
                stopped_autoboot = True

            if b"=> " in buf and not sent_booti:
                os.write(fd, b"booti 0x81000000 0x85000000 0x10080\r")
                sent_booti = True

            if b"REALCHECK: READY" in buf:
                break

        if xsdb.poll() is None:
            xsdb.terminate()
            xsdb.wait(timeout=5)

    os.close(fd)

    text = uart_log.read_text(encoding="utf-8", errors="ignore")
    markers = [
        "U-Boot",
        "Starting kernel",
        "Run /init as init process",
        "REALCHECK: READY",
    ]
    hit = [m for m in markers if m in text]
    summary.write_text(
        "\n".join(
            [
                f"bit={args.bit}",
                f"bootelf={args.bootelf}",
                f"image={args.image}",
                f"ramdisk={args.ramdisk}",
                f"uart={args.uart}",
                f"sent_booti={sent_booti}",
                f"stopped_autoboot={stopped_autoboot}",
                "markers=" + ",".join(hit),
            ]
        ) + "\n",
        encoding="utf-8",
    )

    return 0 if "REALCHECK: READY" in text else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bit", type=Path, required=True)
    parser.add_argument("--bootelf", type=Path, required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--ramdisk", type=Path, required=True)
    parser.add_argument(
        "--uart",
        type=Path,
        default=Path("/dev/serial/by-id/usb-1a86_5523-if00-port0"),
    )
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--timeout-sec", type=int, default=180)
    args = parser.parse_args()
    return run_smoke(args)


if __name__ == "__main__":
    raise SystemExit(main())
