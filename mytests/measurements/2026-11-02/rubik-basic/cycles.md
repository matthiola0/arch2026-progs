# Cycle analysis

- compiler: riscv-none-elf-gcc 15.2.0, -march=rv32i_zicsr -mabi=ilp32 -ffreestanding
- rv32emu: 158b57e (system emulation, ELF_LOADER, interpreter)
- timed region: n calls on identical inputs; loop baseline subtracted

rv32emu has no timing model: `cycle` and `instret` are one counter of executed guest instructions. The figures below are instruction counts per call, with the loop control, input load and counter reads removed.

## Cycles per call

| Function | -O1 | -O2 | -O3 | -Os | asm | best C | asm vs best C |
|---|---|---|---|---|---|---|---|
| rubik.solve | 91163.7 | 90111.3 | 89384.2 | 241639.0 | 73678.3 | 89384.2 | 1.21x |

## Ratio to -O2

| Function | -O1 | -O2 | -O3 | -Os | asm |
|---|---|---|---|---|---|
| rubik.solve | 1.01 | 1.00 | 0.99 | 2.68 | 0.82 |

## Footprint (bytes, `size -A`, harness excluded)

| Program | Variant | .text | .rodata | .data | .bss |
|---|---|---|---|---|---|
| rubik | asm | 1000 | 40531 | 0 | 0 |
| rubik | -O1 | 1272 | 40500 | 0 | 0 |
| rubik | -O2 | 1156 | 40500 | 0 | 0 |
| rubik | -O3 | 2580 | 40500 | 0 | 0 |
| rubik | -Os | 1156 | 40500 | 0 | 0 |
| bf16 | asm | 644 | 0 | 0 | 0 |
| bf16 | -O1 | 808 | 0 | 0 | 0 |
| bf16 | -O2 | 752 | 0 | 0 | 0 |
| bf16 | -O3 | 752 | 0 | 0 | 0 |
| bf16 | -Os | 688 | 0 | 0 | 0 |
| gcd | asm | 132 | 0 | 0 | 0 |
| gcd | -O1 | 140 | 0 | 0 | 0 |
| gcd | -O2 | 140 | 0 | 0 | 0 |
| gcd | -O3 | 140 | 0 | 0 | 0 |
| gcd | -Os | 120 | 0 | 0 | 0 |
| fixed | asm | 160 | 0 | 0 | 0 |
| fixed | -O1 | 404 | 0 | 0 | 0 |
| fixed | -O2 | 352 | 0 | 0 | 0 |
| fixed | -O3 | 352 | 0 | 0 | 0 |
| fixed | -Os | 352 | 0 | 0 | 0 |
