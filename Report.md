# Assignment 2: Complete Applications
contributed by < [`matthiola0`](https://github.com/matthiola0) >

## 1. Scope and measurement

The Rubik solver, BFloat16 routines, binary GCD, and logic/Q11.20 operations each have a portable C implementation and a hand-written RV32I version. All four optimization levels and the host sanitizer checks pass, giving a score of 100/100 in the instructor's automated harness.

The implementation and verification sources are pinned at [`1468b09ff2285baab9f8808c4e1c087150840809`](https://github.com/matthiola0/arch2026-progs/tree/1468b09ff2285baab9f8808c4e1c087150840809). The contracts in `src/<program>/<program>.h` define special cases and rounding. Several BFloat16 rules differ from ordinary floating-point arithmetic, as discussed in Section 4.

### 1.1 Execution environment

Measurements were made on 2026-11-02 in Ubuntu 26.04 under WSL2. The target compiler is xPack GNU RISC-V Embedded GCC 15.2.0-1, with binutils 2.45. The downloaded compiler archive passed its published SHA-256 check. Host verification uses GCC 15.2.0 and Python 3.14.4. Formatting uses clang-format 20.1.8.

The target flags are `-march=rv32i_zicsr -mabi=ilp32 -ffreestanding -fno-pic -fno-stack-protector`, with `-O1`, `-O2`, `-O3`, and `-Os` measured separately. The shared harness is compiled at `-O2`. The emulator revision is `158b57e`, configured for system interpretation and ELF loading, with the M, A, F, and C extensions disabled. The implementations contain no environment calls or CSR instructions. The harness alone performs output and counter reads.

The bare-metal image starts at 0x10000 and has a shared 4 KiB stack. There is no allocator, libc, or general libgcc. C fixed-point multiplication uses the supplied `__mulsi3`; no implementation needs a 64-bit multiplication or division helper. The hand-written assembly calls no external helper.

### 1.2 What the counters mean

In rv32emu, `cycle` and `instret` both count executed guest instructions. The emulator has no hardware timing model for pipeline stalls or cache misses, so these counts measure guest work without predicting those effects.

The harness reads each 64-bit counter with a high/low/high retry. It times C and assembly on the same input arrays, then subtracts a baseline loop whose call is replaced by the input value. A checksum keeps the results observable to the compiler. Initialization and printing lie outside the timed region. Per-call cost is `(total - overhead) / n`, which can be fractional because several calls share one loop. Counts are deterministic, so each input needs one run.

The assembly column uses the `-O2` ELF. Speed ratios compare C and assembly within the same ELF at the fastest C level. The caller changes across optimization levels, which can shift the measured cost of a small routine by a fraction of an instruction. Footprint comparisons use the smallest C build.

### 1.3 Lab2 check

The [Lab2 playground](https://hackmd.io/@sysprog/Sko2Ja5pel) was cloned into the emulator's `tests/system/playground`, built and run at `-O0`, cleaned, and rebuilt at `-O2`. All tests pass. At `-O0`, ChaCha20 reports 6797 cycles/instructions; BFloat16 addition, subtraction, multiplication, division, and special-case tests report 432, 373, 464, 624, and 239. At `-O2`, those BFloat16 figures become 162, 112, 111, 211, and 117. ChaCha20 reports 4322 cycles and 4323 instructions because the two reads occur at different guest instructions. These are exercise measurements, separate from the four implementations below.

## 2. Rubik: retaining IDA* under a tighter budget

### 2.1 Representation and shortest paths

The 14-character input contains seven distinct corner digits followed by seven orientation digits. Internally, digits are reduced to zero-based values. A valid orientation vector satisfies

$$\sum_{i=0}^{6} o_i \equiv 0 \pmod 3.$$

The seventh orientation is determined by the other six. A state therefore has a permutation coordinate $p<7!=5040$ and an orientation coordinate $o<3^6=729$, giving $5040\cdot729=3{,}674{,}160$ legal states. The move set is `R R2 R' B B2 B' D D2 D'`, with each move costing one. Host BFS verifies diameter 11 and exactly 2644 states at distance 11.

Homework 1 used nonrecursive iterative deepening A* with

$$h_0(p,o)=\max(d_P(p),d_O(o)).$$

Both coordinates have separate quarter-turn tables. Three successive lookups enumerate a face's quarter, half, and inverse turns. The search skips adjacent moves of the same face: any such pair combines into one allowed move or cancels, so a shortest solution cannot require it.

The direct callable port passes the public tests. On the known hard case `54721631111111`, however, it retires 15,099,218 assembly instructions, exceeding the 7.5-million limit.

### 2.2 A stronger admissible heuristic

The search keeps IDA* and uses a database over all orientations and the positions of three labeled corners, numbered 2, 3, and 5 in the input convention:

$$h(p,o)=\max\bigl(d_P(p),d_{235}(o,s(p))\bigr).$$

Three distinct positions have $7\cdot6\cdot5=210$ arrangements. The combined pattern graph has $729\cdot210=153{,}090$ states. Every move has a well-defined projection into that graph. Projecting a full solution gives an abstract solution of the same length, so the abstract shortest distance cannot exceed the full distance. The maximum of the two lower bounds remains admissible.

IDA* begins with bound $h$ and increases it one move at a time. With an admissible heuristic, no shorter solution is cut off. The first bound that yields a solution therefore gives the exact distance. The search carries an explicit array of frames, without recursion or dynamic allocation.

For positions $x_0,x_1,x_2\in\{0,\ldots,6\}$, a dense coordinate is

$$s=30x_0+5\bigl(x_1-[x_1>x_0]\bigr)+x_2-[x_2>x_0]-[x_2>x_1],$$

where brackets are 0 or 1. Removing already selected positions leaves six choices for the second position and five for the third. A 5040-byte table maps a permutation rank directly to $s$, so no extra coordinate is updated in the hot loop.

The pattern's maximum distance is nine. Packing two distances into each byte reduces the database to 76,545 bytes. Each orientation row contains 210 nibbles, or 105 bytes:

```c
unsigned s = rb_subset[p];
return (rb_pdb[rb_ooffset[o] + (s >> 1)] >> ((s & 1u) << 2)) & 15u;
```

[`pattern_distance`](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/rubik/rubik.c#L27) uses a precomputed row offset instead of multiplying by 105. The parity of $s$ selects the low or high nibble. The generator verifies every packed value against its unpacked BFS distance.

| Table | Bytes |
|---|---:|
| Permutation quarter turns | 30240 |
| Orientation quarter turns | 4374 |
| Permutation distances | 5040 |
| Permutation-to-pattern coordinate | 5040 |
| Orientation row offsets | 2916 |
| Packed pattern distances | 76545 |
| Alignment | 2 |
| Total | 124157 |

The database stores distances in the projected graph; the target searches for each full-cube solution. C and assembly each have their own copy of the constants because their implementation objects link separately.

### 2.3 RV32I assembly and the callable interface

The [assembly search](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/rubik/rubik.S) follows the same move order and pruning. It keeps coordinates, the remaining depth, current face, and transition-row pointers in registers. The permutation bound is tested first, avoiding the more expensive packed lookup when that cheaper test already rejects a move. Backtracking restores row pointers from a 20-byte frame instead of reconstructing them.

The assembly entry saves the callee-saved registers it uses and reserves 352 bytes, including eleven search frames. GCC reports at most 272 bytes for the C entry; its optional out-of-line pattern helper needs no stack. Both fit within the shared 4 KiB limit.

[`rubik_solve`](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/rubik/rubik.c#L117) validates all digits, uniqueness, orientation sum, and the exact string length before writing output. Invalid input returns -1 with output untouched. After solving, it computes the complete text length, including separators and NUL. Insufficient capacity returns -2, clearing only `out[0]` when capacity is nonzero. Exact-fit buffers succeed. The solved cube needs one byte for its empty string. Ripes input, printing, replay animation, and exit calls are absent from the implementation.

### 2.4 Verification and measured changes

The [host verifier](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/mytests/rubik_verify.c) checks every transition entry against an independently written cubie model. It then builds a full BFS oracle, checks both heuristics against the exact distances, and runs the C solver on all 3,674,160 states. Every returned length equals BFS, and every path solves the independent model. The run took 26.49 host CPU seconds.

All 2644 distance-11 states were also run on rv32emu for C O2 and assembly. A separate Python model replays all 5288 printed paths. Their maxima occur at `47265312313211`: 3,854,613 instructions for C and 3,243,708 for assembly. Means are 671,141.05 and 568,214.09. The host scan selects 64 high-cost states from the entire legal domain. These states are measured at all four optimization levels; the largest C call is 9,933,547 at `-Os`, below its 50-million limit.

The host scan counts candidates $C$, candidates passing the permutation check $P$, accepted children $A$, and depth rounds $R$. Counting the hand-written instruction blocks gives the conservative bound

$$11C+14P+90A+100R+2048.$$

The first two coefficients cover the candidate prefix and packed lookup. An accepted child needs at most 25 instructions for recording/descent and at most 62 for its node's face setup, exhausted-turn checks, and backtracking; charging 90 covers both. Charging 100 covers a root round, and 2048 covers bounded parsing, ranking, formatting, and register saves. This structural bound reaches a maximum of 3,610,490 over all legal states in the host scan. Target measurements cover the distance-11 set and the selected high-cost states.

| Measurement | Original heuristic | Three-corner heuristic |
|---|---:|---:|
| Assembly instructions at `54721631111111` | 15099218 | 1670656 |
| Assembly mean on six harness inputs | 73678.3 | 5771.2 |
| Best C mean on the same inputs | 89384.2 | 6356.5 |
| Assembly code and constants, bytes | 41531 | 125411 |

The larger database rejects enough branches to offset its more expensive lookup. Assembly uses 125,411 allocated bytes; the largest C build uses 127,032, both below 131,072. The exhaustive host check found zero shortest-path or replay mismatches.

### 2.5 Where the technique applies

An embedded planner with enough ROM for a partial abstraction can use IDA* when RAM cannot hold a large search frontier. IDA* bounds working memory by repeating the search, while a pattern database cuts branches within those searches. The abstraction must preserve move costs to remain admissible. Its usefulness also depends on packing and lookup costs, as well as the worst-case search it leaves behind.

## 3. Binary GCD without a divider

### 3.1 Identities and termination

Inputs and output are unsigned 32-bit integers. Zero is handled first: $\gcd(a,0)=a$, including $\gcd(0,0)=0$. The remaining algorithm uses Stein's identities:

$$\gcd(2a,2b)=2\gcd(a,b),$$
$$\gcd(2a,b)=\gcd(a,b)\quad\text{when }b\text{ is odd},$$
$$\gcd(a,b)=\gcd(a-b,b)\quad\text{when }a>b.$$

Remove common factors of two and remember their exponent. Make the operands odd, subtract the smaller from the larger, and remove the even difference's factors of two. For distinct positive odd operands, the difference is positive and smaller than the larger operand. The process therefore terminates at equal operands. Restoring the common power of two gives the original GCD.

All arithmetic stays within the unsigned input domain. Subtraction takes the nonnegative difference, and the exact result divides the original inputs. The algorithm needs no rounding or software divider. The [C implementation](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/gcd/gcd.c) uses a swap to maintain ordering; the [assembly](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/gcd/gcd.S) has separate reduction paths.

### 3.2 Removing a redundant test

After subtracting two odd values, the unchanged operand is still odd. The first assembly version tested its parity again after reducing the difference. Returning directly to comparison removes that repeated work:

```asm
sub     a0, a0, a1
.Lreduce_a:
srli    a0, a0, 1
andi    t1, a0, 1
beqz    t1, .Lreduce_a
j       .Lcompare
```

The [reduction path](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/gcd/gcd.S#L47) improves the harness mean from 93.9 to 88.4 instructions per call. The fastest C build is O1 at 101.6. Code grows from 120 to 132 bytes; C `-Os` is 120 bytes.

### 3.3 Verification and applications

The supplied suite checks all 65,536 pairs below 256 against an independent Euclidean reference. It also covers zero/equality identities, all powers-of-two pairs, shared powers of two, Fibonacci pairs, random operands, and assembly/C agreement. In the O2 worst-call tests, C reaches 457 instructions and assembly 328, below budgets 4000 and 1500. Beyond the exhaustive below-256 grid, the $2^{64}$ operand pairs are sampled.

Firmware can use GCD to reduce rational values or normalize integer ratios. Binary GCD is useful on a core without a divider because it avoids the remainder operation used by the Euclidean algorithm. Its invariants can be checked directly from the shifts and positive differences.

## 4. BFloat16 arithmetic

### 4.1 Format and conversion

BFloat16 has one sign bit, eight exponent bits with bias 127, and seven stored fraction bits. For exponent field $1\le E\le254$ and fraction $f$,

$$x=(-1)^s(128+f)2^{E-134}.$$

Normal precision is eight significant binary bits. The smallest positive normal is $2^{-126}$ and the largest finite magnitude is $(2-2^{-7})2^{127}$. Subnormals use $(-1)^s f2^{-133}$. Exponent 255 encodes infinities and NaNs.

The interface takes a binary32 bit pattern as `uint32_t`, so converting it needs no floating-point operation. Write the bits as $2^{16}H+L$. The finite conversion adds `0x7FFF + (H & 1)` and keeps the upper half. For $L<0x8000$ the retained half stays unchanged; for $L>0x8000$ it increments; at the midpoint it increments exactly when $H$ is odd. This is nearest rounding with ties to even. A carry can produce infinity. Exponent-255 inputs bypass rounding and return their original upper half, preserving the specified NaN bits.

The [assembly conversion](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/bf16/bf16.S#L15) uses that comparison directly. It returns early below the midpoint, then combines a nonzero discarded remainder with retained parity to decide an increment. This improves the measured cost from 12.2 to 8.5 instructions per call, against 11.1 in the best C build. The supplied retained/discarded-half sweeps cover midpoint decisions and carry boundaries independently of that implementation.

### 4.2 Multiplication and its nonstandard cases

Normalize each nonzero operand to an eight-bit significand $M\in[128,255]$. A subnormal shifts its fraction left and lowers its working exponent until the leading one reaches bit seven. The product $P=M_aM_b\le65025$ fits in 16 bits. Its tentative exponent is $E_a+E_b-127$. If bit 15 of $P$ is set, shift $P$ right once and increment that exponent. The result keeps the upper significand bits by truncation, not nearest rounding.

RV32I lacks multiplication. C calls the supplied software multiplier; [hand-written assembly](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/bf16/bf16.S#L36) specializes the operand width. It unrolls seven shift/add steps and adds the known leading-one contribution for the eighth bit. It needs no call, stack save, or generic 32-bit multiply loop. The harness mean is 59.1 instructions, compared with 87.2 for the fastest C build.

A NaN first operand is returned unchanged. An infinite first operand times a zero produces quiet NaN; otherwise that infinity takes precedence, even over a NaN second operand. The second operand is examined afterward. Zero times a finite value preserves the product sign.

On underflow, the stored fraction is shifted without restoring its hidden leading one. Thus `0x0080 * 0x3F00` returns zero rather than `0x0040`, and some subnormal values do not survive multiplication by one. The first host tests caught this difference from ordinary gradual underflow. The [C implementation](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/bf16/bf16.c#L10) preserves the behavior in the contract and golden vectors.

For finite normal results without underflow or overflow, truncating a significand loses less than one unit, giving relative error below $1/128=0.78125\%$. Measuring all $128^2=16384$ positive significand pairs gives a maximum of 0.7691841802434741%, at `0x3F9E * 0x3FD1`, with output `0x4000`. Power-of-two scaling and sign leave the relative error unchanged in this range. The underflow example above has 100% relative error. Overflow to infinity also falls outside the normal-result bound.

### 4.3 Square root without multiplication

For a positive normal input, write $x=2^e m/128$. If $e$ is odd, double $m$ and decrement $e$, making the exponent even. The quiz then searches for the largest integer `mid` satisfying

$$\left\lfloor\frac{mid^2}{128}\right\rfloor\le m.$$

Since $mid^2$ is integral, this is equivalent to

$$mid^2\le128(m+1)-1.$$

The exact replacement is therefore $\operatorname{isqrt}(128(m+1)-1)$. Using $\operatorname{isqrt}(128m)$ changes results: for $m=130$, the specified root is 129, while the latter expression gives 128.

Normalization makes $128\le m\le510$, so the radicand is below $2^{16}$ and the root lies in $[128,255]$. Its leading bit is known. The [assembly](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/bf16/bf16.S#L137) takes that first restoring step directly and performs the remaining seven steps with additions, comparisons, shifts, and subtractions. It removes the binary search's repeated software multiplication while preserving the exact truncating result.

The fully unrolled version costs 38.6 instructions per call. Using a seven-pass loop raises that to 42.5 and reduces the entire BFloat16 assembly from 784 to 644 bytes, below the smallest C build's 688. The compact version is still 7.63 times faster than the best C square-root baseline at 324.4 instructions per call.

NaNs retain their bits; positive infinity returns unchanged; negative nonzero values, including negative subnormals, produce quiet NaN. Both signed zeros produce positive zero, and positive subnormals produce zero. These branches precede normal arithmetic.

### 4.4 Verification and applications

The target suite covers conversion boundaries, a 256-by-256 multiplication grid, columns over every 16-bit operand, special-value classes, and all 65,536 square-root inputs. Independent host mathematics checks all 32,512 positive normals for square-root error. The maximum relative error is 0.38835098164954423%, first reached at `0x0081`. The truncating rule can differ from a correctly rounded mathematical square root.

The O2 worst-call tests report assembly maxima of 15, 125, and 79 instructions for conversion, multiplication, and square root, below budgets 60, 400, and 1500. The multiplication maximum covers the tested pairs; the square-root maximum covers the full input space.

Reduced-precision formats can save storage and bandwidth in numerical pipelines. The course's [BF16 sine study](https://hackmd.io/@sysprog/bf16-sine) examines the resulting range and error limits. These routines reduce instruction counts by specializing the eight-bit significand and removing multiplication from square root. A general arithmetic library would also need to review the ordered NaN and underflow rules used here.

## 5. Logic and Q11.20 arithmetic

### 5.1 Addition, subtraction, and average

For a bit position, XOR forms the sum without incoming carry and AND identifies a carry into the next position. Consequently,

$$a+b=(a\mathbin{\mathrm{xor}}b)+2(a\mathbin{\&}b).$$

`op1` repeats this decomposition until the carry word becomes zero. Its pass count is part of the result, so replacing it with a plain `add` would violate the contract. Zero carry needs zero passes; `op1(0xFFFF,1)` needs 17. Unsigned shifts and XOR preserve modulo-$2^{32}$ behavior without signed overflow.

The [assembly loop](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/fixed/fixed.S#L17) increments one counter from zero and stores it once. C O2's listing maintains a second count temporary with an extra `mv` in each pass. Assembly measures 22.1 instructions per call against 24.7 for the best C build.

`op2` is subtraction modulo $2^{32}$. Its assembly is a `sub` and `ret`, matching the compiler. `op3` computes the floor of the exact unsigned average. Dividing the identity above by two gives:

```c
return (a & b) + ((a ^ b) >> 1);
```

The [`op3` expression](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/fixed/fixed.c#L20) stays within the input range and avoids forming the potentially 33-bit sum. Its four data operations and return match the compiler's sequence. The measured means are 4.0 for `op2` and 7.0 for `op3`, including the harness's call-site accounting.

### 5.2 Scaling, rounding, and wraparound

Q11.20 stores a signed integer $A$ representing $a=A2^{-20}$. One sign bit, eleven integer bits, and twenty fraction bits give range

$$[-2048,2048-2^{-20}]$$

and resolution $2^{-20}$. Multiplying two represented values gives $AB2^{-40}$. Returning to the original scale requires

$$C=\left\lfloor\frac{AB+2^{19}}{2^{20}}\right\rfloor.$$

The added half-unit rounds to nearest with ties toward positive infinity. For stored operands $3$ and $524288$, the result is 2; for $-3$ and $524288$, it is -1. The final stored result keeps the low 32 bits, so out-of-range products wrap instead of saturating. The [fixed-point line-drawing reference](https://hackmd.io/@sysprog/line-draw-fixed-point) derives the range and rounding of this format; the wrap rule comes from this function's contract.

### 5.3 A product without `__muldi3`

Write unsigned operand patterns as $U=A_0+2^{16}A_1$ and $V=B_0+2^{16}B_1$. Four 16-bit partial products suffice:

$$UV=A_0B_0+2^{16}(A_0B_1+A_1B_0)+2^{32}A_1B_1.$$

The [C implementation](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/fixed/fixed.c#L25) combines the lower product's upper half and the cross-products' lower halves into a middle word, carries its upper bits into the high word, and keeps every intermediate unsigned. Each partial product fits 32 bits and can use `__mulsi3`.

Signed correction follows by writing $A=U-\alpha2^{32}$ and $B=V-\beta2^{32}$, where $\alpha,\beta$ indicate negative operands. Modulo $2^{64}$,

$$AB\equiv UV-\alpha V2^{32}-\beta U2^{32}.$$

The high word therefore subtracts $V$ when $A<0$ and $U$ when $B<0$. Adding $2^{19}$ to the low word and carrying into the high word incorporates rounding. Combining bits 20 through 51 gives the low 32 bits of the arithmetic-shifted result. The final signed conversion is expressed without an out-of-range unsigned-to-signed cast.

The [assembly](https://github.com/matthiola0/arch2026-progs/blob/1468b09ff2285baab9f8808c4e1c087150840809/src/fixed/fixed.S#L53) instead shifts a signed multiplicand held in a register pair and adds its value for each set multiplier bit. It interprets the multiplier as unsigned during the loop, then subtracts the original multiplicand from the high word if that multiplier was negative. Starting the accumulator at $2^{19}$ applies rounding once, including any carry. This avoids four helper calls and their register saves. It measures 225.2 instructions per call against 318.9 for the fastest C build, and the whole fixed assembly occupies 160 bytes against C's smallest 352.

### 5.4 Error and verification

Before wraparound, nearest rounding gives

$$|C2^{-20}-ab|\le2^{-21}=0.000000476837158203125.$$

The bound applies to the exact represented inputs when the rounded result fits the format. Prior input quantization and error accumulated through repeated operations need separate bounds. Independent Python integers check 20,121 directed and seeded random pairs with zero contract mismatches. Among 10,149 results whose rounded value fits the format, the maximum absolute error reaches exactly $2^{-21}$. Wrapped results are checked against the exact modulo rule.

The supplied suite covers directed cases, grids, random pairs, carry-pass hashes, average checks against a wider sum, signed-product references, and positive/negative ties. O2 assembly worst-call maxima are 169 (`op1`), 6 (`op2`), 9 (`op3`), and 426 (`q_mul`), below budgets 600, 40, 40, and 1200.

Rasterization and signal-processing kernels can use fixed-point arithmetic when their scale and intermediate ranges are known in advance. On RV32I, partial products or a register-pair shift/add loop implement the widened product exactly, despite the cost of software multiplication. A kernel that needs saturation would require a different overflow rule and additional checks.

## 6. Compiler comparison and footprint

### 6.1 Same inputs and timed regions

| Function | C O1 | C O2 | C O3 | C Os | Assembly | Best C / assembly |
|---|---:|---:|---:|---:|---:|---:|
| rubik_solve | 8066.7 | 6655.8 | 6356.5 | 16113.2 | 5771.2 | 1.10 |
| bf16_from_f32 | 11.1 | 12.2 | 13.8 | 12.2 | 8.5 | 1.30 |
| bf16_mul | 94.3 | 87.2 | 88.6 | 91.3 | 59.1 | 1.48 |
| bf16_sqrt | 327.4 | 324.4 | 325.9 | 333.4 | 42.5 | 7.63 |
| gcd_u32 | 101.6 | 116.6 | 118.8 | 119.7 | 88.4 | 1.15 |
| op1 | 27.2 | 24.7 | 26.8 | 24.7 | 22.1 | 1.12 |
| op2 | 4.0 | 4.0 | 5.9 | 4.0 | 4.0 | 1.00 |
| op3 | 7.0 | 7.0 | 8.9 | 7.0 | 7.0 | 1.00 |
| q_mul | 329.9 | 318.9 | 320.8 | 322.4 | 225.2 | 1.42 |

GCD O1 is fastest on this input set. Its parity-reduction loop shifts, tests, and branches; O2's corresponding path also jumps back to the parity-test block. The extra control work increases the executed instruction count even though both builds occupy 140 code bytes.

Rubik O3 is fastest among the C builds and uses 2760 code bytes against O2's 1392. C `-Os` reduces that to 1276 while substantially increasing dynamic work. The assembly keeps transition-row pointers in registers and uses 1104 bytes for the search and callable interface.

The largest RV32I-specific gain is in BFloat16 square root. Removing multiplication from the algorithm saves more instructions than tuning the generic multiply loop. Subtraction and the average already compile to the same short sequences used in the hand-written versions.

### 6.2 Section sizes, excluding the shared harness

| Program | Version | .text | .rodata | .data | .bss |
|---|---|---:|---:|---:|---:|
| rubik | C O1 | 1564 | 124272 | 0 | 0 |
| rubik | C O2 | 1392 | 124272 | 0 | 0 |
| rubik | C O3 | 2760 | 124272 | 0 | 0 |
| rubik | C Os | 1276 | 124272 | 0 | 0 |
| rubik | assembly | 1104 | 124307 | 0 | 0 |
| bf16 | C O1 | 808 | 0 | 0 | 0 |
| bf16 | C O2 | 752 | 0 | 0 | 0 |
| bf16 | C O3 | 752 | 0 | 0 | 0 |
| bf16 | C Os | 688 | 0 | 0 | 0 |
| bf16 | assembly | 644 | 0 | 0 | 0 |
| gcd | C O1 | 140 | 0 | 0 | 0 |
| gcd | C O2 | 140 | 0 | 0 | 0 |
| gcd | C O3 | 140 | 0 | 0 | 0 |
| gcd | C Os | 120 | 0 | 0 | 0 |
| gcd | assembly | 132 | 0 | 0 | 0 |
| fixed | C O1 | 404 | 0 | 0 | 0 |
| fixed | C O2 | 352 | 0 | 0 | 0 |
| fixed | C O3 | 352 | 0 | 0 | 0 |
| fixed | C Os | 352 | 0 | 0 | 0 |
| fixed | assembly | 160 | 0 | 0 | 0 |

`size -A` reports the allocated sections of each implementation object. Rubik assembly is smaller in total than the smallest C build, with slightly more read-only metadata. GCD spends 12 bytes to remove repeated parity tests. The numeric routines allocate no static working memory; Rubik stores its path and frames on the stack.

## 7. Reproducing the measurements

After activating the cross toolchain in Ubuntu:

```sh
make
make test
make sanitize
make dump
make size
make cycles
```

`make test` includes history and repository checks. The Git hooks are installed; every development commit carries a chained `Change-Id`. No instructor test, budget, contract header, Makefile, or grading script has been changed. A fresh instructor checkout's `scripts/grade.sh --submission <fork>` independently runs the host sanitizers and four target levels and reports 100/100.

Additional checks are reproducible from the [verification tools](https://github.com/matthiola0/arch2026-progs/tree/1468b09ff2285baab9f8808c4e1c087150840809/mytests):

```sh
cc -O3 -Wall -Wextra -Werror mytests/rubik_verify.c -o build/host/rubik_verify
build/host/rubik_verify
cp build/rubik/all_d11_probe.h build/rubik/rubik_probe_states.h
bash mytests/run_rubik_probe.sh > build/rubik/all-d11.log
python3 mytests/analyze_rubik_probe.py --log build/rubik/all-d11.log \
    --states build/rubik/states_d11.txt
bash mytests/check_rubik_worst.sh
cc -O2 -shared -fPIC src/bf16/bf16.c src/fixed/fixed.c -o build/host/libnumeric.so
python3 mytests/analyze_error.py
```

Host test summaries need to be checked explicitly. The harness's host runner returns zero after assertion failures and reserves nonzero status for sanitizer reports.

AI assistance covered requirements review, implementation, code review, verification tools, measurements, and report drafting. The CodeTrial interview and its complete recording are pending; outside AI assistance is prohibited during the interview.
