# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    lui     t0, 0x7f800
    and     t1, a0, t0
    slli    t2, a0, 16
    srli    a0, a0, 16
    beq     t1, t0, .Lf32_done
    # Below the midpoint, the retained half already is the rounded result.
    bgez    t2, .Lf32_done
    # Above it, increment; exactly at it, increment only an odd retained half.
    slli    t2, t2, 1
    snez    t2, t2
    andi    t1, a0, 1
    or      t2, t2, t1
    add     a0, a0, t2
.Lf32_done:
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    xor     t0, a0, a1
    li      t5, 0x8000
    and     t0, t0, t5
    srli    t1, a0, 7
    andi    t1, t1, 255
    srli    t2, a1, 7
    andi    t2, t2, 255
    andi    t3, a0, 127
    andi    t4, a1, 127
    li      t5, 255
    beq     t1, t5, .Lmul_special_a
    beq     t2, t5, .Lmul_special_b
    slli    t5, a0, 17
    beqz    t5, .Lmul_zero
    slli    t5, a1, 17
    beqz    t5, .Lmul_zero
    beqz    t1, .Lmul_denorm_a
    ori     t3, t3, 128
    j       .Lmul_b
.Lmul_denorm_a:
    li      t1, 1
.Lmul_normalize_a:
    slli    t3, t3, 1
    addi    t1, t1, -1
    sltiu   t5, t3, 128
    bnez    t5, .Lmul_normalize_a
.Lmul_b:
    beqz    t2, .Lmul_denorm_b
    ori     t4, t4, 128
    j       .Lmul_product
.Lmul_denorm_b:
    li      t2, 1
.Lmul_normalize_b:
    slli    t4, t4, 1
    addi    t2, t2, -1
    sltiu   t5, t4, 128
    bnez    t5, .Lmul_normalize_b
.Lmul_product:
    add     t1, t1, t2
    addi    t1, t1, -127
    li      t6, 0
    # Seven low bits plus the known leading one: exactly eight-bit operands.
    .rept 7
    andi    t5, t4, 1
    beqz    t5, 1f
    add     t6, t6, t3
1:
    srli    t4, t4, 1
    slli    t3, t3, 1
    .endr
    add     t6, t6, t3
    srli    t5, t6, 15
    beqz    t5, .Lmul_fraction
    srli    t6, t6, 1
    addi    t1, t1, 1
.Lmul_fraction:
    srli    t6, t6, 7
    andi    t6, t6, 127
    li      t5, 255
    bge     t1, t5, .Lmul_inf
    blez    t1, .Lmul_underflow
    slli    t1, t1, 7
    or      a0, t1, t6
    or      a0, a0, t0
    ret
.Lmul_underflow:
    li      t5, -6
    blt     t1, t5, .Lmul_zero
    li      t5, 1
    sub     t5, t5, t1
    srl     t6, t6, t5
    or      a0, t0, t6
    ret
.Lmul_special_a:
    bnez    t3, .Lmul_return
    slli    t5, a1, 17
    beqz    t5, .Lmul_nan
    j       .Lmul_inf
.Lmul_special_b:
    mv      a0, a1
    bnez    t4, .Lmul_return
    # Original a is finite, and a zero has exponent and fraction both zero.
    or      t5, t1, t3
    beqz    t5, .Lmul_nan
.Lmul_inf:
    li      a0, 0x7f80
    or      a0, a0, t0
    ret
.Lmul_zero:
    mv      a0, t0
    ret
.Lmul_nan:
    li      a0, 0x7fc0
.Lmul_return:
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    srli    t0, a0, 7
    andi    t0, t0, 255
    andi    t1, a0, 127
    li      t2, 255
    beq     t0, t2, .Lsqrt_special
    slli    t2, a0, 17
    beqz    t2, .Lsqrt_zero
    # Sign is bit 15; use a shift because 0x8000 is not an AND immediate.
    srli    t2, a0, 15
    bnez    t2, .Lsqrt_nan
    beqz    t0, .Lsqrt_zero
    ori     t1, t1, 128
    andi    t2, t0, 1
    bnez    t2, .Lsqrt_radicand
    slli    t1, t1, 1
.Lsqrt_radicand:
    # floor(mid^2 / 128) <= m iff mid^2 <= 128 * (m + 1) - 1.
    addi    t1, t1, 1
    slli    t1, t1, 7
    addi    t1, t1, -1
    li      t2, 16384
    sub     t1, t1, t2
    li      t3, 4096
    # Restoring integer square root. The leading root bit is always one.
.Lsqrt_bit:
    add     t4, t2, t3
    srli    t2, t2, 1
    bltu    t1, t4, 1f
    sub     t1, t1, t4
    add     t2, t2, t3
1:
    srli    t3, t3, 2
    bnez    t3, .Lsqrt_bit
    addi    t0, t0, 127
    srli    t0, t0, 1
    slli    t0, t0, 7
    andi    t2, t2, 127
    or      a0, t0, t2
    ret
.Lsqrt_special:
    bnez    t1, .Lsqrt_return
    srli    t2, a0, 15
    beqz    t2, .Lsqrt_return
.Lsqrt_nan:
    li      a0, 0x7fc0
    ret
.Lsqrt_zero:
    li      a0, 0
.Lsqrt_return:
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
