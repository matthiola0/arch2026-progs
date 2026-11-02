#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
prefix=${CROSS_COMPILE:-riscv-none-elf-}
opt=${OPT:-O2}
mkdir -p build/rubik
if [ ! -f build/rubik/rubik_probe_states.h ]; then
    cp mytests/rubik_probe_states.h build/rubik/rubik_probe_states.h
fi
"${prefix}gcc" -march=rv32i_zicsr -mabi=ilp32 -ffreestanding -fno-pic \
    -fno-stack-protector -Wall -Wextra -Werror -"$opt" -Icommon -Itests \
    -Ibuild/rubik -iquote . -c mytests/rubik_probe.c -o build/rubik/probe.o
"${prefix}ld" -T common/linker.ld --no-warn-rwx-segments -o build/rubik/probe.elf \
    build/rubik/probe.o "build/rubik/$opt/impl.o" build/rubik/impl_asm.o \
    build/common/{start,perf,rt,print}.o
third_party/rv32emu/build/rv32emu build/rubik/probe.elf
