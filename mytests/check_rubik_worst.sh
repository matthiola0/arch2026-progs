#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
cp build/rubik/worst_probe.h build/rubik/rubik_probe_states.h
for opt in O1 O2 O3 Os; do
    OPT="$opt" bash mytests/run_rubik_probe.sh > "../rubik-worst-$opt.log"
    python3 mytests/analyze_rubik_probe.py --log "../rubik-worst-$opt.log" \
        --states build/rubik/worst_states.csv > "../rubik-worst-$opt.json"
    "${CROSS_COMPILE:-riscv-none-elf-}gcc" -"$opt" -march=rv32i_zicsr -mabi=ilp32 \
        -ffreestanding -fno-pic -fstack-usage -c src/rubik/rubik.c \
        -o "build/rubik/stack-$opt.o"
done
