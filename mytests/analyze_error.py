#!/usr/bin/env python3
"""Measure numerical error against host mathematics, outside the timed region."""

import argparse
import ctypes
import json
import math
import random
from pathlib import Path


def decode(bits):
    exponent = (bits >> 7) & 255
    fraction = bits & 127
    if exponent == 255:
        return math.nan if fraction else math.copysign(math.inf, -1 if bits & 32768 else 1)
    value = math.ldexp(fraction if exponent == 0 else fraction + 128,
                       -133 if exponent == 0 else exponent - 134)
    return -value if bits & 32768 else value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lib", default="build/host/libnumeric.so")
    args = parser.parse_args()
    lib = ctypes.CDLL(str(Path(args.lib).resolve()))
    lib.bf16_sqrt.argtypes = [ctypes.c_uint16]
    lib.bf16_sqrt.restype = ctypes.c_uint16
    lib.bf16_mul.argtypes = [ctypes.c_uint16, ctypes.c_uint16]
    lib.bf16_mul.restype = ctypes.c_uint16
    lib.q_mul.argtypes = [ctypes.c_int32, ctypes.c_int32]
    lib.q_mul.restype = ctypes.c_int32

    sqrt_worst = {"relative_error": -1}
    for bits in range(0x0080, 0x7F80):
        result = lib.bf16_sqrt(bits)
        reference = math.sqrt(decode(bits))
        error = abs(decode(result) - reference) / reference
        if error > sqrt_worst["relative_error"]:
            sqrt_worst = {"relative_error": error, "input": hex(bits),
                          "output": hex(result), "reference": reference}
    assert sqrt_worst["relative_error"] < 0.01

    mul_worst = {"relative_error": -1}
    for ma in range(128):
        for mb in range(128):
            a, b = 0x3F80 | ma, 0x3F80 | mb
            result = lib.bf16_mul(a, b)
            reference = decode(a) * decode(b)
            error = abs(decode(result) - reference) / reference
            if error > mul_worst["relative_error"]:
                mul_worst = {"relative_error": error, "a": hex(a),
                             "b": hex(b), "output": hex(result)}
    assert mul_worst["relative_error"] < 1 / 128
    underflow = lib.bf16_mul(0x0080, 0x3F00)
    assert underflow == 0

    points = [-2147483648, 2147483647, -1048576, -524288, -3, -1,
              0, 1, 3, 524288, 1048576]
    pairs = [(a, b) for a in points for b in points]
    rng = random.Random(20261102)
    pairs.extend((rng.randrange(-2**31, 2**31), rng.randrange(-2**31, 2**31))
                 for _ in range(10000))
    pairs.extend((rng.randrange(-32 * 2**20, 32 * 2**20),
                  rng.randrange(-32 * 2**20, 32 * 2**20)) for _ in range(10000))
    max_rounding_numerator = 0
    unwrapped = 0
    for a, b in pairs:
        exact_product = a * b
        rounded = (exact_product + 2**19) // 2**20
        expected = (rounded + 2**31) % 2**32 - 2**31
        result = lib.q_mul(a, b)
        assert result == expected, (a, b, result, expected)
        if -2**31 <= rounded < 2**31:
            unwrapped += 1
            max_rounding_numerator = max(max_rounding_numerator,
                                         abs((result << 20) - exact_product))
    assert max_rounding_numerator <= 2**19

    print(json.dumps({
        "sqrt_positive_normals_checked": 254 * 128,
        "sqrt_worst": sqrt_worst,
        "mul_normal_significand_pairs_checked": 128 * 128,
        "mul_worst": mul_worst,
        "mul_underflow_example": {"a": "0x0080", "b": "0x3f00",
                                  "output": hex(underflow), "relative_error": 1.0},
        "q_mul_pairs_checked": len(pairs),
        "q_mul_pairs_without_wrap": unwrapped,
        "q_mul_max_absolute_error_without_wrap": max_rounding_numerator / 2**40,
        "q_mul_contract_mismatches": 0,
    }, indent=2))


if __name__ == "__main__":
    main()
