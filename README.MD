Copyright © 2026 HeartWare. All rights reserved.

This UNIT is released under the **HeartWare FreeWare License**.

You may freely use, copy, modify, and redistribute this software and its
source code for private, hobby, educational, and other non-commercial
purposes.

You may not use, sell, distribute, include, publish, bundle, or otherwise
make this software, or any modified or derivative version of it, available
in any commercial context without prior permission from HeartWare. This
includes direct or indirect commercial use or distribution, including paid
download sites, subscription services, commercial software collections,
magazines, books, paid media, or products or services for which money is
charged. It also includes putting this software or links to it on sites
that are supported by ads.

If you redistribute a modified or derivative version, it must be released
under this **exact same license**. You may neither add nor remove
permissions, restrictions, or licensing terms.

The copyright notice and this license must remain with all redistributed
copies and derivative versions.

**Commercial use requires separate permission from HeartWare.**

The software is provided "as is", without warranty of any kind.

If you are not completely satisfied, return it to where you obtained it for
a full monetary refund of the price you paid for it.

# HeartWare.PRNG

`HeartWare.PRNG` is a small Delphi utility UNIT providing fast,
deterministic 32-bit and 64-bit pseudo-random number generators.

The UNIT provides two ways of using each generator:

- independent RECORD-based generators, suitable for maintaining separate
  PRNG state in different objects, routines, or threads;
- stand-alone global functions compatible with the traditional
  `RANDOMIZE`/`RANDOM` style of use.

The 64-bit implementation uses SplitMix64. The 32-bit implementation uses
the corresponding 32-bit SplitMix-style generator.

Both implementations support:

- automatic seeding from a newly generated `TGUID`;
- explicit deterministic seeding;
- externally accessible generator state;
- generation of values in the range `0..Range-1`;
- generation of values in an inclusive `Min..Max` range;
- rejection sampling to avoid modulo bias.

The generators are intended for general-purpose pseudo-random number
generation where speed, reproducibility, and good statistical distribution
are desirable.

They are **not cryptographically secure** and must not be used where
unpredictability against an attacker is required.

## 64-bit interface

The 64-bit interface consists of the `TPRNG64` RECORD and the global
64-bit generator functions:

```pascal
TYPE
  TPRNG64       = RECORD
                  PRIVATE
                    FSeed       : UInt64;
                    FUNCTION    NextRandom : UInt64;
                  PUBLIC
                    CLASS FUNCTION Create : TPRNG64; OVERLOAD; STATIC;
                    CLASS FUNCTION Create(Seed : UInt64) : TPRNG64; OVERLOAD; STATIC;
                    FUNCTION    RANDOM(Range : UInt64) : UInt64;
                    FUNCTION    RND(Min,Max : UInt64) : UInt64;
                    PROCEDURE   RANDOMIZE; OVERLOAD;
                    PROCEDURE   RANDOMIZE(Seed : UInt64); OVERLOAD;
                    PROPERTY    Seed : UInt64 READ FSeed WRITE FSeed;
                  END;

VAR
  RandSeed64 : UInt64 = 0;

PROCEDURE RANDOMIZE64; OVERLOAD;
PROCEDURE RANDOMIZE64(Seed : UInt64); OVERLOAD;
FUNCTION RANDOM64(Range : UInt64) : UInt64;
FUNCTION RND64(Min,Max : UInt64) : UInt64;
```

The RECORD-based and global interfaces use the same underlying PRNG
implementation. The difference is where the generator state is stored.

A `TPRNG64` instance stores its state in its own private `FSeed` field,
exposed through the public `Seed` property.

The global functions store their state in the global `RandSeed64`
variable.

## `TPRNG64`

`TPRNG64` represents an independent 64-bit pseudo-random number generator.

Each RECORD instance maintains its own state, allowing multiple unrelated
random sequences to exist at the same time.

For example:

```pascal
VAR
  RNG1,RNG2 : TPRNG64;

RNG1:=TPRNG64.Create;
RNG2:=TPRNG64.Create;

A:=RNG1.RANDOM(1000);
B:=RNG2.RANDOM(1000);
```

`RNG1` and `RNG2` are completely independent.

### `TPRNG64.Create`

```pascal
CLASS FUNCTION Create : TPRNG64;
```

Creates a new generator and initializes its seed from a newly created
`TGUID`.

Example:

```pascal
VAR
  RNG : TPRNG64;

RNG:=TPRNG64.Create;
```

The GUID contains 128 bits. The implementation treats those bits as two
`UInt64` values and folds them into a 64-bit state using XOR.

This is intended as a convenient way of obtaining a fresh initial state.
It does not make the generator cryptographically secure.

### `TPRNG64.Create(Seed)`

```pascal
CLASS FUNCTION Create(Seed : UInt64) : TPRNG64;
```

Creates a generator with an explicitly supplied seed.

Example:

```pascal
RNG:=TPRNG64.Create($123456789ABCDEF0);
```

Using the same seed always produces the same pseudo-random sequence.

This is useful for:

- repeatable tests;
- simulations;
- procedural generation;
- debugging;
- saving and replaying deterministic sequences.

All `UInt64` values, including zero, are valid seeds.

## `TPRNG64.Seed`

```pascal
PROPERTY Seed : UInt64 READ FSeed WRITE FSeed;
```

The `Seed` property exposes the complete current state of the generator.

The value may be read to save the current generator position:

```pascal
SavedSeed:=RNG.Seed;
```

and written later to restore that exact position:

```pascal
RNG.Seed:=SavedSeed;
```

The sequence produced after restoring the seed will be identical to the
sequence that originally followed that state.

The property may also be used directly to assign a new deterministic seed:

```pascal
RNG.Seed:=$0123456789ABCDEF;
```

This is equivalent to calling:

```pascal
RNG.RANDOMIZE($0123456789ABCDEF);
```

## `TPRNG64.RANDOMIZE`

```pascal
PROCEDURE RANDOMIZE;
```

Re-initializes the generator from a newly created `TGUID`.

Example:

```pascal
RNG.RANDOMIZE;
```

The existing sequence is discarded and a new seed is installed.

## `TPRNG64.RANDOMIZE(Seed)`

```pascal
PROCEDURE RANDOMIZE(Seed : UInt64);
```

Re-initializes the generator with a specific seed:

```pascal
RNG.RANDOMIZE($123456789ABCDEF0);
```

This is useful when a previously known sequence must be reproduced.

## `TPRNG64.RANDOM`

```pascal
FUNCTION RANDOM(Range : UInt64) : UInt64;
```

Returns a pseudo-random value in:

```text
0 .. Range-1
```

For example:

```pascal
X:=RNG.RANDOM(10);
```

returns a value from 0 through 9.

`Range` must be greater than zero.

Passing zero raises `ERangeError`.

### Avoiding modulo bias

A simple implementation such as:

```pascal
NextRandom MOD Range
```

would introduce a small statistical bias whenever `Range` is not an exact
divisor of `2^64`.

`HeartWare.PRNG` avoids this by using rejection sampling.

The implementation calculates:

```pascal
Threshold:=(UInt64(0)-Range) MOD Range;
```

The unsigned subtraction deliberately wraps around, allowing the remainder
of `2^64` divided by `Range` to be determined without requiring an integer
type wider than 64 bits.

Raw values below `Threshold` are discarded.

The remaining number of possible source values is therefore an exact
multiple of `Range`, making the final:

```pascal
R MOD Range
```

unbiased.

## `TPRNG64.RND`

```pascal
FUNCTION RND(Min,Max : UInt64) : UInt64;
```

Returns a pseudo-random value in the inclusive range:

```text
Min .. Max
```

For example:

```pascal
Die:=RNG.RND(1,6);
```

returns a value from 1 through 6.

If `Max` is smaller than `Min`, `ERangeError` is raised.

The range width is calculated as:

```pascal
Range:=SUCC(Max-Min);
```

and the normal case is equivalent to:

```pascal
Result:=Min+RANDOM(Range);
```

### Complete UInt64 range

The expression:

```pascal
SUCC(High(UInt64))
```

wraps to zero.

Consequently:

```pascal
RNG.RND(0,High(UInt64))
```

requires special handling.

In this case a calculated range of zero represents the complete `UInt64`
domain rather than an empty range.

The implementation therefore returns the raw PRNG result directly, allowing
every possible `UInt64` value to be returned.

## SplitMix64 implementation

The internal 64-bit generator advances its state by adding the fixed Weyl
increment:

```pascal
$9E3779B97F4A7C15
```

The resulting state is then passed through the SplitMix64 mixing function.

The state transition visits every possible 64-bit state before repeating,
giving the generator a period of `2^64`.

The low-level implementation is hidden inside the UNIT implementation
section and operates on a seed passed by reference:

```pascal
FUNCTION PRNG64Next(VAR Seed : UInt64) : UInt64;
FUNCTION PRNG64Random(VAR Seed : UInt64; Range : UInt64) : UInt64;
FUNCTION PRNG64Rnd(VAR Seed : UInt64; Min,Max : UInt64) : UInt64;
PROCEDURE PRNG64Randomize(VAR Seed : UInt64);
```

Both the `TPRNG64` methods and the global 64-bit functions call these same
internal routines.

This ensures that both interfaces produce identical results when operating
from the same seed.

## Global 64-bit generator

For applications that do not require independent generator instances, the
UNIT also provides a traditional global interface.

The global generator state is stored in:

```pascal
VAR
  RandSeed64 : UInt64;
```

### `RANDOMIZE64`

```pascal
PROCEDURE RANDOMIZE64;
```

Initializes `RandSeed64` from a newly created `TGUID`.

Example:

```pascal
RANDOMIZE64;
```

### `RANDOMIZE64(Seed)`

```pascal
PROCEDURE RANDOMIZE64(Seed : UInt64);
```

Explicitly sets the global generator state:

```pascal
RANDOMIZE64($123456789ABCDEF0);
```

This is equivalent to assigning:

```pascal
RandSeed64:=$123456789ABCDEF0;
```

### `RANDOM64`

```pascal
FUNCTION RANDOM64(Range : UInt64) : UInt64;
```

Returns a pseudo-random value in:

```text
0 .. Range-1
```

and advances `RandSeed64`.

It uses the same rejection-sampling implementation as
`TPRNG64.RANDOM`.

Example:

```pascal
X:=RANDOM64(100);
```

returns a value from 0 through 99.

### `RND64`

```pascal
FUNCTION RND64(Min,Max : UInt64) : UInt64;
```

Returns a pseudo-random value in the inclusive range:

```text
Min .. Max
```

and advances `RandSeed64`.

It uses the same implementation and edge-case handling as `TPRNG64.RND`.

Example:

```pascal
Die:=RND64(1,6);
```

## RECORD versus global interface

The two 64-bit interfaces are functionally equivalent.

For example:

```pascal
RandSeed64:=$123456789ABCDEF0;
RNG:=TPRNG64.Create($123456789ABCDEF0);

A:=RANDOM64(1000000);
B:=RNG.RANDOM(1000000);
```

`A` and `B` will be identical because both calls operate on the same
underlying algorithm from the same initial state.

The difference is state ownership.

The global interface stores one shared state:

```pascal
RandSeed64
```

while every `TPRNG64` value stores its own private state.

This makes the RECORD form preferable whenever multiple independent random
sequences are required.

## Thread safety

The global functions are **not thread-safe** when multiple threads access
the same global state concurrently.

For example, concurrent calls to:

```pascal
RANDOM64(...)
```

all modify `RandSeed64`.

Applications that use the global interface from multiple threads must
serialize access themselves.

`TPRNG64` provides a simple thread-safe alternative when each thread owns
its own RECORD instance:

```pascal
PROCEDURE Worker;
VAR
  RNG : TPRNG64;
BEGIN
  RNG:=TPRNG64.Create;

  // This thread now has its own independent PRNG state.
END;
```

No shared mutable generator state is involved.

A `TPRNG64` instance is not inherently safe if the **same instance** is
shared and modified concurrently by multiple threads. In that situation,
normal synchronization is still required.

The intended thread-safe usage is therefore one PRNG instance per thread,
task, object, or other independent execution context.

## Saving and restoring generator state

Both interfaces allow the complete PRNG state to be saved and restored.

For a RECORD:

```pascal
SavedSeed:=RNG.Seed;

// Generate values...

RNG.Seed:=SavedSeed;
```

For the global interface:

```pascal
SavedSeed:=RandSeed64;

// Generate values...

RandSeed64:=SavedSeed;
```

Both approaches restore the generator to exactly the same position in its
pseudo-random sequence.

## Overflow and range checking

The UNIT explicitly uses:

```pascal
{$Q-,R-}
```

Overflow and range checking are disabled because unsigned arithmetic
wraparound is an intentional part of the implementation.

Examples include:

```pascal
UInt64(0)-Range
```

and:

```pascal
SUCC(Max-Min)
```

for the complete unsigned integer range.

Enabling overflow or range checking for these calculations would change the
required semantics and may cause runtime errors.

## 32-bit implementation

The 32-bit implementation is the exact functional equivalent of the 64-bit
implementation described above, but uses `UInt32` values and maintains a
32-bit generator state.

It provides both an independent RECORD:

```pascal
TYPE
  TPRNG32       = RECORD
                  PRIVATE
                    FSeed       : UInt32;
                    FUNCTION    NextRandom : UInt32;
                  PUBLIC
                    CLASS FUNCTION Create : TPRNG32; OVERLOAD; STATIC;
                    CLASS FUNCTION Create(Seed : UInt32) : TPRNG32; OVERLOAD; STATIC;
                    FUNCTION    RANDOM(Range : UInt32) : UInt32;
                    FUNCTION    RND(Min,Max : UInt32) : UInt32;
                    PROCEDURE   RANDOMIZE; OVERLOAD;
                    PROCEDURE   RANDOMIZE(Seed : UInt32); OVERLOAD;
                    PROPERTY    Seed : UInt32 READ FSeed WRITE FSeed;
                  END;
```

and the corresponding global interface:

```pascal
VAR
  RandSeed32 : UInt32 = 0;

PROCEDURE RANDOMIZE32; OVERLOAD;
PROCEDURE RANDOMIZE32(Seed : UInt32); OVERLOAD;
FUNCTION RANDOM32(Range : UInt32) : UInt32;
FUNCTION RND32(Min,Max : UInt32) : UInt32;
```

The parameters, behaviour, error handling, deterministic seeding,
save/restore semantics, rejection sampling, inclusive `RND` ranges, RECORD
state ownership, and thread-safety considerations are identical to the
64-bit versions described above.

The only differences are:

- `UInt32` is used instead of `UInt64`;
- the internal state has 32 bits;
- the full state period is `2^32`;
- the full-range special case is
  `RND32(0,High(UInt32))` or
  `TPRNG32.RND(0,High(UInt32))`;
- GUID seeding folds the 128-bit GUID into four `UInt32` parts instead of
  two `UInt64` parts;
- the 32-bit SplitMix-style generator uses its corresponding 32-bit mixing
  constants and state increment.

The 32-bit and 64-bit generators are completely independent.

Calling a 32-bit global function changes only `RandSeed32`, while calling a
64-bit global function changes only `RandSeed64`.

Likewise, every `TPRNG32` and `TPRNG64` RECORD maintains its own independent
state.

## Statistical and security considerations

These generators are suitable for uses such as:

- games;
- simulations;
- randomized algorithms;
- procedural generation;
- test data;
- randomized ordering;
- repeatable pseudo-random test scenarios.

They are not intended for cryptographic purposes.

Do **not** use them to generate:

- passwords;
- cryptographic keys;
- security tokens;
- authentication secrets;
- session identifiers that must be unpredictable;
- cryptographic nonces;
- values whose unpredictability is security-sensitive.

For such applications, use an operating-system cryptographic random-number
generator instead.

## Summary

The 64-bit API consists of the following operations:

```text
┌───────────────────────┬────────────────────────────────────────────────────┐
│ Function              │ Result                                             │
├───────────────────────┼────────────────────────────────────────────────────┤
│ TPRNG64.Create        │ Creates a GUID-seeded independent generator        │
│ TPRNG64.Create(Seed)  │ Creates an explicitly seeded generator             │
│ RNG.RANDOMIZE         │ Re-seeds a RECORD instance from a TGUID            │
│ RNG.RANDOMIZE(Seed)   │ Sets the RECORD instance seed                      │
│ RNG.RANDOM(Range)     │ Returns 0..Range-1 without modulo bias             │
│ RNG.RND(Min,Max)      │ Returns inclusive Min..Max                         │
│ RNG.Seed              │ Reads or writes the complete RECORD state          │
├───────────────────────┼────────────────────────────────────────────────────┤
│ RANDOMIZE64           │ Seeds the global generator from a TGUID            │
│ RANDOMIZE64(Seed)     │ Sets an explicit global seed                       │
│ RANDOM64(Range)       │ Returns 0..Range-1 without modulo bias             │
│ RND64(Min,Max)        │ Returns inclusive Min..Max                         │
│ RandSeed64            │ Reads or writes the complete global state          │
└───────────────────────┴────────────────────────────────────────────────────┘
```

The 32-bit API provides the same operations with `TPRNG32`, `UInt32`,
`RandSeed32`, `RANDOMIZE32`, `RANDOM32`, and `RND32`.
