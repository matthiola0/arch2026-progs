# Cycle analysis

- compiler: riscv-none-elf-gcc 15.2.0, -march=rv32i_zicsr -mabi=ilp32 -ffreestanding
- rv32emu: 158b57e (system emulation, ELF_LOADER, interpreter)
- timed region: n calls on identical inputs; loop baseline subtracted

rv32emu has no timing model: `cycle` and `instret` are one counter of executed guest instructions. The figures below are instruction counts per call, with the loop control, input load and counter reads removed.

## Cycles per call

| Function | -O1 | -O2 | -O3 | -Os | asm | best C | asm vs best C |
|---|---|---|---|---|---|---|---|
| bf16.from_f32 | 11.1 | 12.2 | 13.8 | 12.2 | 8.5 | 11.1 | 1.30x |
| bf16.mul | 94.3 | 87.2 | 88.6 | 91.3 | 59.1 | 87.2 | 1.48x |
| bf16.sqrt | 327.4 | 324.4 | 325.9 | 333.4 | 42.5 | 324.4 | 7.63x |
| fixed.op1 | 27.2 | 24.7 | 26.8 | 24.7 | 22.1 | 24.7 | 1.12x |
| fixed.op2 | 4.0 | 4.0 | 5.9 | 4.0 | 4.0 | 4.0 | 1.00x |
| fixed.op3 | 7.0 | 7.0 | 8.9 | 7.0 | 7.0 | 7.0 | 1.00x |
| fixed.q_mul | 329.9 | 318.9 | 320.8 | 322.4 | 225.2 | 318.9 | 1.42x |
| gcd.gcd | 101.6 | 116.6 | 118.8 | 119.7 | 88.4 | 101.6 | 1.15x |
| rubik.solve | 8066.7 | 6655.8 | 6356.5 | 16113.2 | 5771.2 | 6356.5 | 1.10x |

## Ratio to -O2

| Function | -O1 | -O2 | -O3 | -Os | asm |
|---|---|---|---|---|---|
| bf16.from_f32 | 0.91 | 1.00 | 1.13 | 1.00 | 0.70 |
| bf16.mul | 1.08 | 1.00 | 1.02 | 1.05 | 0.68 |
| bf16.sqrt | 1.01 | 1.00 | 1.00 | 1.03 | 0.13 |
| fixed.op1 | 1.10 | 1.00 | 1.09 | 1.00 | 0.90 |
| fixed.op2 | 1.00 | 1.00 | 1.48 | 1.00 | 1.00 |
| fixed.op3 | 1.00 | 1.00 | 1.28 | 1.00 | 1.00 |
| fixed.q_mul | 1.03 | 1.00 | 1.01 | 1.01 | 0.71 |
| gcd.gcd | 0.87 | 1.00 | 1.02 | 1.03 | 0.76 |
| rubik.solve | 1.21 | 1.00 | 0.96 | 2.42 | 0.87 |

## Footprint (bytes, `size -A`, harness excluded)

| Program | Variant | .text | .rodata | .data | .bss |
|---|---|---|---|---|---|
| rubik | asm | 1104 | 124307 | 0 | 0 |
| rubik | -O1 | 1564 | 124272 | 0 | 0 |
| rubik | -O2 | 1392 | 124272 | 0 | 0 |
| rubik | -O3 | 2760 | 124272 | 0 | 0 |
| rubik | -Os | 1276 | 124272 | 0 | 0 |
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
