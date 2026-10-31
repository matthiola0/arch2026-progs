# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li      t0, 0
    beqz    a1, .Lop1_done
.Lop1_loop:
    and     t1, a0, a1
    xor     a0, a0, a1
    slli    a1, t1, 1
    addi    t0, t0, 1
    bnez    a1, .Lop1_loop
.Lop1_done:
    sw      t0, 0(a2)
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and     t0, a0, a1
    xor     a0, a0, a1
    srli    a0, a0, 1
    add     a0, a0, t0
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    # Multiply signed a by unsigned b in a register pair, then correct
    # the high word by -a when b was negative. Include rounding once.
    srai    a2, a0, 31
    srai    a5, a1, 31
    and     a5, a5, a0
    li      a3, 0x80000
    li      a4, 0
    beqz    a1, .Lq_done
.Lq_loop:
    andi    t0, a1, 1
    beqz    t0, .Lq_next
    add     a3, a3, a0
    sltu    a6, a3, a0
    add     a4, a4, a2
    add     a4, a4, a6
.Lq_next:
    srli    a1, a1, 1
    beqz    a1, .Lq_done
    srli    a6, a0, 31
    slli    a2, a2, 1
    or      a2, a2, a6
    slli    a0, a0, 1
    j       .Lq_loop
.Lq_done:
    sub     a4, a4, a5
    srli    a0, a3, 20
    slli    a4, a4, 12
    or      a0, a0, a4
    ret
    .size   q_mul_asm, .-q_mul_asm
