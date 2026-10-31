# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beqz    a0, .Lreturn_b
    beqz    a1, .Lreturn
    li      t0, 0

.Lcommon:
    or      t1, a0, a1
    andi    t1, t1, 1
    bnez    t1, .Lodd_a
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    t0, t0, 1
    j       .Lcommon

.Lodd_a:
    andi    t1, a0, 1
    bnez    t1, .Lodd_b
.Lshift_a:
    srli    a0, a0, 1
    andi    t1, a0, 1
    beqz    t1, .Lshift_a

.Lodd_b:
    andi    t1, a1, 1
    bnez    t1, .Lcompare
.Lshift_b:
    srli    a1, a1, 1
    andi    t1, a1, 1
    beqz    t1, .Lshift_b

.Lcompare:
    beq     a0, a1, .Ldone
    bltu    a0, a1, .Lb_larger
    sub     a0, a0, a1
    j       .Lshift_a
.Lb_larger:
    sub     a1, a1, a0
    j       .Lshift_b

.Ldone:
    sll     a0, a0, t0
.Lreturn:
    ret
.Lreturn_b:
    mv      a0, a1
    ret
    .size   gcd_u32_asm, .-gcd_u32_asm
