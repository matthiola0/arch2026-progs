#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    *n = 0;
    while (b) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        (*n)++;
    }
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    /* Four 16-bit partial products avoid a compiler call to __muldi3. */
    uint32_t ua = (uint32_t) a, ub = (uint32_t) b;
    uint32_t a0 = ua & 0xFFFFu, a1 = ua >> 16;
    uint32_t b0 = ub & 0xFFFFu, b1 = ub >> 16;
    uint32_t p0 = a0 * b0, p1 = a0 * b1;
    uint32_t p2 = a1 * b0, p3 = a1 * b1;
    uint32_t middle = (p0 >> 16) + (p1 & 0xFFFFu) + (p2 & 0xFFFFu);
    uint32_t lo = (p0 & 0xFFFFu) | (middle << 16);
    uint32_t hi = p3 + (p1 >> 16) + (p2 >> 16) + (middle >> 16);
    if (a < 0)
        hi -= ub;
    if (b < 0)
        hi -= ua;

    uint32_t rounded = lo + (1u << (Q - 1));
    hi += lo > UINT32_MAX - (1u << (Q - 1));
    uint32_t result = (rounded >> Q) | (hi << (32 - Q));
    /* Express the signed bit pattern without an out-of-range conversion. */
    return result <= INT32_MAX ? (int32_t) result : -1 - (int32_t) ~result;
}
