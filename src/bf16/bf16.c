#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    if ((f32bits & 0x7F800000u) == 0x7F800000u)
        return (uint16_t) (f32bits >> 16);
    return (uint16_t) ((f32bits + 0x7FFFu + ((f32bits >> 16) & 1u)) >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    unsigned sign = (a ^ b) & 0x8000u;
    int ea = (a >> 7) & 0xFF, eb = (b >> 7) & 0xFF;
    unsigned ma = a & 0x7Fu, mb = b & 0x7Fu;
    /* Operand order is part of the contract, including Inf times NaN. */
    if (ea == 255) {
        if (ma)
            return a;
        return (b & 0x7FFFu) == 0 ? 0x7FC0u : sign | 0x7F80u;
    }
    if (eb == 255) {
        if (mb)
            return b;
        return (a & 0x7FFFu) == 0 ? 0x7FC0u : sign | 0x7F80u;
    }
    if ((a & 0x7FFFu) == 0 || (b & 0x7FFFu) == 0)
        return (uint16_t) sign;

    if (ea) {
        ma |= 128u;
    } else {
        ea = 1;
        while (ma < 128u) {
            ma <<= 1;
            ea--;
        }
    }
    if (eb) {
        mb |= 128u;
    } else {
        eb = 1;
        while (mb < 128u) {
            mb <<= 1;
            eb--;
        }
    }
    unsigned product = ma * mb;
    int exponent = ea + eb - 127;
    if (product >= 0x8000u) {
        product >>= 1;
        exponent++;
    }
    /* The quiz shifts the stored fraction on underflow, without its hidden
     * leading bit. Preserve that specified behavior rather than IEEE gradual
     * underflow (for example 0x0080 times 0x3F00 gives zero).
     */
    unsigned mantissa = (product >> 7) & 0x7Fu;
    if (exponent >= 255)
        return (uint16_t) (sign | 0x7F80u);
    if (exponent <= 0) {
        if (exponent < -6)
            return (uint16_t) sign;
        return (uint16_t) (sign | (mantissa >> (1 - exponent)));
    }
    return (uint16_t) (sign | ((unsigned) exponent << 7) | (mantissa & 0x7Fu));
}

uint16_t bf16_sqrt(uint16_t a)
{
    unsigned exponent = (a >> 7) & 0xFFu;
    unsigned fraction = a & 0x7Fu;
    if (exponent == 255u) {
        if (fraction || (a & 0x8000u) == 0)
            return a;
        return 0x7FC0u;
    }
    if ((a & 0x7FFFu) == 0)
        return 0;
    if (a & 0x8000u)
        return 0x7FC0u;
    if (!exponent)
        return 0;

    int e = (int) exponent - 127;
    unsigned m = fraction | 128u;
    if (e % 2 != 0) {
        m <<= 1;
        e--;
    }
    unsigned lo = 90, hi = 256, root = 0;
    while (lo <= hi) {
        unsigned mid = (lo + hi) >> 1;
        if ((mid * mid) >> 7 <= m) {
            root = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return (uint16_t) (((unsigned) (e / 2 + 127) << 7) | (root & 0x7Fu));
}
