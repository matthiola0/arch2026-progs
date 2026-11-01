# Development record

## Status on 2026-11-02

The BFloat16, binary GCD, and fixed-point C and hand-written RV32I
implementations pass all four target builds (`-O1`, `-O2`, `-O3`, `-Os`).
The C implementations pass the supplied host tests under AddressSanitizer
and UndefinedBehaviorSanitizer. A fresh instructor checkout also grades
these three programs as passing. The complete score is currently **75/100**:
Rubik remains the original dummy, pending a search-design decision.

The instructor harness, contracts, tests, budgets, and workflows have not
been changed. Local setup uses Ubuntu 26.04 under WSL2, xPack RISC-V GCC
15.2.0-1 (the archive checksum was verified), GNU binutils 2.45, host GCC
15.2.0, Python 3.14.4, clang-format 20.1.8, and rv32emu revision `158b57e`.
The emulator uses system interpretation and ELF loading, with M, A, F,
and C disabled. The working tree was normalized to LF before building.

The Lab2 playground passes at both `-O0` and `-O2`, with a clean rebuild
between the two. At `-O0`, ChaCha20 takes 6797 cycles/instructions and the
five BFloat16 checks take 432, 373, 464, 624, and 239, matching the handout.
At `-O2`, the corresponding figures are 4322/4323 for ChaCha20 and
162, 112, 111, 211, and 117 for BFloat16. The ChaCha20 reads occur at
different instructions, which accounts for the one-count difference.

## Measured target costs

The harness measures identical inputs, subtracts the loop and counter-read
baseline, and retains a checksum. rv32emu's cycle and instret counters
count executed guest instructions; these are not hardware latency figures.
The table shows assembly measured in the `-O2` ELF. Speed ratios compare
C and assembly in the same ELF at the best C optimization level, so a
ratio can differ slightly from dividing the rounded columns below.

| Function | C O1 | C O2 | C O3 | C Os | Assembly | Speed ratio |
|---|---:|---:|---:|---:|---:|---:|
| bf16_from_f32 | 11.1 | 12.2 | 13.8 | 12.2 | 8.5 | 1.30 |
| bf16_mul | 94.3 | 87.2 | 88.6 | 91.3 | 59.1 | 1.48 |
| bf16_sqrt | 327.4 | 324.4 | 325.9 | 333.4 | 42.5 | 7.63 |
| gcd_u32 | 101.6 | 116.6 | 118.8 | 119.7 | 88.4 | 1.15 |
| op1 | 27.2 | 24.7 | 26.8 | 24.7 | 22.1 | 1.12 |
| op2 | 4.0 | 4.0 | 5.9 | 4.0 | 4.0 | 1.00 |
| op3 | 7.0 | 7.0 | 8.9 | 7.0 | 7.0 | 1.00 |
| q_mul | 329.9 | 318.9 | 320.8 | 322.4 | 225.2 | 1.42 |

`op2` already needs only a subtraction and return; `op3` needs four data
operations and return. The assembly matches those minimal compiler
sequences. The additional cost in the table comes from the call site and
the harness's baseline convention, not extra operations in the functions.

| Program | Assembly .text | Smallest C .text | .rodata / .data / .bss |
|---|---:|---:|---|
| bf16 | 644 | 688 | 0 / 0 / 0 for each implementation |
| gcd | 132 | 120 | 0 / 0 / 0 for each implementation |
| fixed | 160 | 352 | 0 / 0 / 0 for each implementation |

These sizes exclude the test harness and runtime. All assembly routines
are leaf functions and use caller-saved registers only, with no stack
allocation or external helper calls.

## Binary GCD

Stein's algorithm uses `gcd(2a, 2b) = 2 gcd(a, b)`, removes factors of two
from an operand when the other is odd, and replaces two distinct odd
operands by the smaller operand and their positive, even difference.
The difference strictly decreases an operand, so the reduction terminates.
Zero inputs return the other operand before any shift loop.

The C baseline uses an explicit swap. The assembly instead keeps two
reduction paths, avoiding the swap. An initial version rechecked the
other operand's parity after reducing a difference. That operand was
already odd. Removing the redundant check reduces the measured cost
from 93.9 to 88.4 instructions per call, at a cost of 12 extra code bytes.
This is a measured speed/size tradeoff; assembly is larger than C `-Os`.

The supplied tests include all 65,536 pairs below 256, powers of two,
shared factors of two, Fibonacci pairs, random inputs, and assembly/C
cross-checks. All target builds also pass the worst-call instruction
budget checks. No multiplication, division, remainder, or ctz extension
is used by either implementation.

## Logic and Q11.20 arithmetic

`op1` propagates carries with `(a & b) << 1` and accumulates non-carry
bits with XOR until no carry remains. Its pass count is observable and
must be retained. `op2` is unsigned subtraction, with modulo-2^32 wrap.
For `op3`, the identity

    floor((a + b) / 2) = (a & b) + ((a ^ b) >> 1)

avoids intermediate overflow for unsigned inputs.

A Q11.20 stored integer A represents A / 2^20. Its range is -2048 through
2048 - 2^-20 and its resolution is 2^-20. The stored product is the low
32 bits of floor((A * B + 2^19) / 2^20); ties round toward positive
infinity, and overflow wraps rather than saturating.

The C implementation forms four 16-bit partial products, combines their
middle-word carries, and corrects the high word for signed operands.
It uses the provided 32-bit multiplier but needs no 64-bit helper.
All intermediate operations on bit patterns are unsigned. Conversion
back to signed C avoids an out-of-range unsigned-to-signed cast.

Assembly shifts a signed multiplicand held in a low/high register pair
and accumulates the set bits of an unsigned multiplier. A negative
multiplier requires subtracting the original multiplicand from the high
word. Initializing the accumulator to 2^19 incorporates rounding exactly
once, including any carry. This uses 225.2 instructions per call against
318.9 in the best C build.

An explicit carry-threshold comparison replaced the equivalent
`rounded < lo` test because Cppcheck 2.19 incorrectly treated that
unsigned wraparound condition as always false. The first experimental
C benchmark was 317.9 instructions per call; the committed expression
measures 318.9. Current tables use the committed expression.

The independent Python integer reference checks 20,121 directed and
seeded random operand pairs with zero mismatches. For the 10,149 cases
whose rounded result fits the signed format, maximum absolute rounding
error is 2^-21, or 0.000000476837158203125. The error bound applies before
wraparound; wrapped results are checked against the exact modulo rule.

## BFloat16

The representation has one sign bit, eight exponent bits with bias 127,
and seven stored fraction bits. Normal precision is eight significant
binary bits. Positive normals range from 2^-126 to (2 - 2^-7) * 2^127;
subnormal resolution is 2^-133.

Narrowing from binary32 uses round-to-nearest, ties-to-even for finite
inputs, and preserves the upper half unchanged for exponent 255. The
assembly rounding path observes that discarded halves below 0x8000
never increment the retained half. Above the midpoint it increments;
at the midpoint it increments only an odd retained half. This changes
the measured cost from 12.2 to 8.5 instructions per call, while passing
the supplied exhaustive retained/discarded-half sweeps.

Multiplication normalizes nonzero subnormal operands, multiplies two
eight-bit significands, renormalizes, and truncates the stored fraction.
Assembly unrolls seven low-bit shift/add steps and adds the known leading
one for the eighth bit. Operand-order rules are preserved: an infinite
first operand can swallow a NaN second operand. Underflow shifts the
stored fraction without restoring its hidden bit. Consequently,
`0x0080 * 0x3F00` is zero, and even multiplication by one need not preserve
a subnormal. The first host run caught this difference from ordinary
gradual underflow; the contract and golden vectors determine the result.

For normal finite products without underflow or overflow, all 16,384
positive significand pairs were measured against exact host arithmetic.
The largest relative truncation error is 0.7691841802434741%, below
2^-7. Exponent scaling and sign do not change this relative error in
that regime. There is no such global bound across underflow: the example
above has 100% relative error. These distinctions belong in the report.

The square root must preserve the quiz's truncating comparison:

    floor(mid^2 / 128) <= m
    mid^2 <= 128 * (m + 1) - 1

Thus the assembly computes the integer square root of `128*(m+1)-1`,
not `128*m`. Normalization makes the leading result bit known, leaving
seven restoring steps with only shifts, additions, comparisons, and
subtractions. A fully unrolled version measured 38.6 instructions per
call. Keeping those seven steps in a loop measures 42.5 but reduces the
whole assembly implementation from 784 to 644 bytes. It remains 7.63
times faster than the best C baseline's binary search with software
multiplication, and is smaller than C `-Os`.

The supplied target tests enumerate all 65,536 square-root inputs.
Independent host error analysis covers all 32,512 positive normals:
maximum relative error is 0.38835098164954423%, first reached at 0x0081.
NaNs, infinities, negative nonzero values, zeros, and denormals follow
their separate contract branches and are not part of that normal bound.

## Observed worst calls

The O2 test output reports the following maximum calls, including the
performance helper's measured overhead. These maxima cover the supplied
directed cases and samples; only the square-root test exhausts its entire
input space. They are not claims of exhaustive coverage of all GCD or
multiply operand pairs. Every optimization level passes its own check.

| Function | C maximum | Assembly maximum | Assembly budget |
|---|---:|---:|---:|
| bf16_from_f32 | 15 | 15 | 60 |
| bf16_mul | 160 | 125 | 400 |
| bf16_sqrt | 619 | 79 | 1500 |
| gcd_u32 | 457 | 328 | 1500 |
| op1 | 201 | 169 | 600 |
| op2 | 6 | 6 | 40 |
| op3 | 9 | 9 | 40 |
| q_mul | 533 | 426 | 1200 |

## Rubik decision still pending

Homework 1's nonrecursive IDA* uses the maximum of permutation and
orientation distances. Its Ripes distance-11 sweep passed all 2,644
cases, with a maximum of 15,104,505 instructions and 86 cases above the
new 7,500,000 limit. Its code and static data total about 42 KB.
These historical Ripes counts are not new rv32emu measurements.

The current decision is whether to retain IDA* and strengthen its
heuristic tables, or keep the state model and validation tools while
changing the search to meet a reverse table within five moves, with a
distance-11 classification table as suggested by the assignment.
No Rubik implementation has been changed before this decision.

## Reproduction and evidence

From the Ubuntu shell, source `../env-wsl.sh` and run:

```sh
make -j4 elfs neg dump
make sanitize
python3 scripts/driver.py --prog gcd --prog fixed --prog bf16 --out results/current
cc -O2 -shared -fPIC src/bf16/bf16.c src/fixed/fixed.c -o build/host/libnumeric.so
python3 mytests/analyze_error.py
```

Host test summaries must be read: `tests/host.c` intentionally returns
zero even when assertions fail, reserving nonzero exit codes for the
sanitizers. The current summaries are 13/13 for GCD, 15/15 for fixed,
and 17/17 for BFloat16, including the six shared host tests each time.

`mytests/measurements/2026-11-02/` preserves raw cycle and footprint CSVs,
the fresh-harness grade log, playground output, numerical error results,
and the O2 target test output. The data includes Rubik's dummy entries
only to preserve the framework's original output; those entries are
not valid solver performance measurements.

The final English HackMD, pinned code excerpts, mock interview, and
submission are still outstanding. This file is a development record,
not the completed report.
