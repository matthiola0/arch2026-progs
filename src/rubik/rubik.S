# rubik_solve_asm: optimal 2x2x2 cube solver, hand-written RV32I.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
#                                   a0 = state, a1 = out, a2 = cap; result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions, no heap, no recursion. Tests: tests/trubik.c.

    .include "src/rubik/rubik_tables.inc"
    .balign 4
rb_rows:
    .word 0, 0, 10080, 1458, 20160, 2916
rb_weights:
    .half 0,720,1440,2160,2880,3600,4320,0
    .half 0,120,240,360,480,600,0,0
    .half 0,24,48,72,96,0,0,0
    .half 0,6,12,18,0,0,0,0
    .half 0,2,4,0,0,0,0,0
    .half 0,1,0,0,0,0,0,0
rb_names:
    .byte 82,0,0, 82,50,0, 82,39,0, 66,0,0, 66,50,0, 66,39,0
    .byte 68,0,0, 68,50,0, 68,39,0

    # Result in t0. a5 = distances, a7 = subset ranks, t5 = row offsets.
    .macro pattern_distance
    .if RB_STRONG
    add     t0, a7, s5
    lbu     t0, 0(t0)
    andi    t1, t0, 1
    slli    t1, t1, 2
    srli    t0, t0, 1
    slli    t2, s6, 2
    add     t2, t5, t2
    lw      t2, 0(t2)
    add     t0, t0, t2
    add     t0, a5, t0
    lbu     t0, 0(t0)
    srl     t0, t0, t1
    andi    t0, t0, 15
    .else
    add     t0, a5, s6
    lbu     t0, 0(t0)
    .endif
    .endm
    .text

    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
    # Saved registers 0..48; output 52; capacity 56; root ranks 60,64;
    # length 68; path 72..82; cubies 84..90; frames 96..315.
    addi    sp, sp, -352
    sw      s0, 0(sp)
    sw      s1, 4(sp)
    sw      s2, 8(sp)
    sw      s3, 12(sp)
    sw      s4, 16(sp)
    sw      s5, 20(sp)
    sw      s6, 24(sp)
    sw      s7, 28(sp)
    sw      s8, 32(sp)
    sw      s9, 36(sp)
    sw      s10, 40(sp)
    sw      s11, 44(sp)
    sw      ra, 48(sp)
    sw      a1, 52(sp)
    sw      a2, 56(sp)
    mv      t0, a0
    addi    t1, sp, 84
    li      t2, 0
    li      t3, 7
    li      t6, 7
.Lparse_p:
    lbu     t4, 0(t0)
    addi    t4, t4, -49
    bgeu    t4, t6, .Linvalid
    li      t5, 1
    sll     t5, t5, t4
    and     a3, t2, t5
    bnez    a3, .Linvalid
    or      t2, t2, t5
    sb      t4, 0(t1)
    addi    t0, t0, 1
    addi    t1, t1, 1
    addi    t3, t3, -1
    bnez    t3, .Lparse_p
    li      t2, 0
    li      t3, 7
    li      t6, 3
    li      s4, 0
.Lparse_o:
    lbu     t4, 0(t0)
    addi    t4, t4, -49
    bgeu    t4, t6, .Linvalid
    add     t2, t2, t4
    li      t5, 1
    beq     t3, t5, .Llast_o
    slli    t5, s4, 1
    add     s4, s4, t5
    add     s4, s4, t4
.Llast_o:
    addi    t0, t0, 1
    addi    t3, t3, -1
    bnez    t3, .Lparse_o
    lbu     t4, 0(t0)
    bnez    t4, .Linvalid
.Lreduce_sum:
    bltu    t2, t6, .Lsum_ready
    addi    t2, t2, -3
    j       .Lreduce_sum
.Lsum_ready:
    bnez    t2, .Linvalid
    li      s3, 0
    addi    t0, sp, 84
    la      t1, rb_weights
    addi    t2, sp, 91
.Lrank_position:
    lbu     t3, 0(t0)
    addi    t4, t0, 1
    li      t5, 0
.Lrank_smaller:
    lbu     t6, 0(t4)
    sltu    t6, t6, t3
    add     t5, t5, t6
    addi    t4, t4, 1
    bltu    t4, t2, .Lrank_smaller
    slli    t5, t5, 1
    add     t5, t1, t5
    lhu     t5, 0(t5)
    add     s3, s3, t5
    addi    t0, t0, 1
    addi    t1, t1, 16
    addi    t3, t0, 1
    bltu    t3, t2, .Lrank_position
    sw      s3, 60(sp)
    sw      s4, 64(sp)
    addi    a0, sp, 72
    li      a6, 0
    or      t0, s3, s4
    beqz    t0, .Lformat
    li      t6, 3
    la      a1, rb_rows
    la      a2, rb_perm
    la      a3, rb_orient
    la      a4, rb_pdist
    .if RB_STRONG
    la      a5, rb_pdb
    la      a7, rb_subset
    la      t5, rb_ooffset
    .else
    la      a5, rb_odist
    .endif
    add     t0, a4, s3
    lbu     s2, 0(t0)
    mv      s5, s3
    mv      s6, s4
    pattern_distance
    bgeu    s2, t0, .Lnew_bound
    mv      s2, t0
.Lnew_bound:
    li      t0, 11
    bgtu    s2, t0, .Linvalid
    lw      s3, 60(sp)
    lw      s4, 64(sp)
    addi    s0, sp, 96
    li      a6, 0
    addi    s1, s2, -1
    li      s7, 0
    li      s9, 255
.Lnext_face:
    bne     s7, s9, .Lface_allowed
    addi    s7, s7, 1
.Lface_allowed:
    beq     s7, t6, .Lbacktrack
    slli    t0, s7, 3
    add     t0, t0, a1
    lw      s10, 0(t0)
    add     s10, s10, a2
    lw      s11, 4(t0)
    add     s11, s11, a3
    mv      s5, s3
    mv      s6, s4
    li      s8, 0
.Lnext_turn:
    beq     s8, t6, .Ladvance_face
    slli    t0, s5, 1
    add     t0, s10, t0
    lhu     s5, 0(t0)
    slli    t0, s6, 1
    add     t0, s11, t0
    lhu     s6, 0(t0)
    addi    s8, s8, 1
    add     t0, a4, s5
    lbu     t0, 0(t0)
    bgtu    t0, s1, .Lnext_turn
    pattern_distance
    bgtu    t0, s1, .Lnext_turn
    slli    t0, s7, 1
    add     t0, t0, s7
    add     t0, t0, s8
    addi    t0, t0, -1
    add     t1, a0, a6
    sb      t0, 0(t1)
    or      t0, s5, s6
    beqz    t0, .Lfound
    sh      s3, 0(s0)
    sh      s4, 2(s0)
    sh      s5, 4(s0)
    sh      s6, 6(s0)
    sb      s7, 8(s0)
    sb      s8, 9(s0)
    sb      s9, 10(s0)
    sw      s10, 12(s0)
    sw      s11, 16(s0)
    addi    s0, s0, 20
    addi    a6, a6, 1
    addi    s1, s1, -1
    mv      s3, s5
    mv      s4, s6
    mv      s9, s7
    li      s7, 0
    j       .Lnext_face
.Ladvance_face:
    addi    s7, s7, 1
    j       .Lnext_face
.Lbacktrack:
    beqz    a6, .Lraise_bound
    addi    s0, s0, -20
    addi    a6, a6, -1
    addi    s1, s1, 1
    lhu     s3, 0(s0)
    lhu     s4, 2(s0)
    lhu     s5, 4(s0)
    lhu     s6, 6(s0)
    lbu     s7, 8(s0)
    lbu     s8, 9(s0)
    lbu     s9, 10(s0)
    lw      s10, 12(s0)
    lw      s11, 16(s0)
    j       .Lnext_turn
.Lraise_bound:
    addi    s2, s2, 1
    j       .Lnew_bound
.Lfound:
    addi    a6, a6, 1
.Lformat:
    sw      a6, 68(sp)
    addi    t0, sp, 72
    mv      t1, a6
    slli    t2, a6, 1
    la      t3, rb_names
    bnez    t1, .Lsize_move
    li      t2, 1
    j       .Lcheck_capacity
.Lsize_move:
    lbu     t4, 0(t0)
    slli    t5, t4, 1
    add     t4, t4, t5
    add     t4, t3, t4
    lbu     t4, 1(t4)
    snez    t4, t4
    add     t2, t2, t4
    addi    t0, t0, 1
    addi    t1, t1, -1
    bnez    t1, .Lsize_move
.Lcheck_capacity:
    lw      t4, 56(sp)
    bltu    t4, t2, .Lsmall_buffer
    lw      a1, 52(sp)
    addi    t0, sp, 72
    mv      t1, a6
    li      t2, 0
.Lwrite_move:
    beqz    t1, .Lterminate
    beqz    t2, .Lwrite_name
    li      t4, 32
    sb      t4, 0(a1)
    addi    a1, a1, 1
.Lwrite_name:
    lbu     t4, 0(t0)
    slli    t5, t4, 1
    add     t4, t4, t5
    add     t4, t3, t4
    lbu     t5, 0(t4)
    sb      t5, 0(a1)
    addi    a1, a1, 1
    lbu     t5, 1(t4)
    beqz    t5, .Lname_done
    sb      t5, 0(a1)
    addi    a1, a1, 1
.Lname_done:
    li      t2, 1
    addi    t0, t0, 1
    addi    t1, t1, -1
    j       .Lwrite_move
.Lterminate:
    sb      zero, 0(a1)
    lw      a0, 68(sp)
    j       .Lreturn
.Lsmall_buffer:
    beqz    t4, .Lbuffer_empty
    lw      t0, 52(sp)
    sb      zero, 0(t0)
.Lbuffer_empty:
    li      a0, -2
    j       .Lreturn
.Linvalid:
    li      a0, -1
.Lreturn:
    lw      s0, 0(sp)
    lw      s1, 4(sp)
    lw      s2, 8(sp)
    lw      s3, 12(sp)
    lw      s4, 16(sp)
    lw      s5, 20(sp)
    lw      s6, 24(sp)
    lw      s7, 28(sp)
    lw      s8, 32(sp)
    lw      s9, 36(sp)
    lw      s10, 40(sp)
    lw      s11, 44(sp)
    lw      ra, 48(sp)
    addi    sp, sp, 352
    ret
    .size   rubik_solve_asm, .-rubik_solve_asm
