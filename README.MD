Copyright © 2026 HeartWare. All rights reserved.

These UNITs are released under the **HeartWare FreeWare License**.

You may freely use, copy, modify, and redistribute this software and its
source code for private, hobby, educational, and other non-commercial
purposes.

You may not use, sell, distribute, include, publish, bundle, or otherwise
make this software, or any modified or derivative version of it, available
in any commercial context without prior permission from HeartWare. This
includes direct or indirect commercial use or distribution, including paid
download sites, subscription services, commercial software collections,
magazines, books, paid media, or products or services for which money is
charged.

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

`HeartWare.PRNG` is a small Delphi utility UNIT providing fast, deterministic
32-bit and 64-bit pseudo-random number generators with explicit seed state.

The UNIT contains two independent generators:

- a 64-bit generator using SplitMix64;
- a 32-bit generator using a SplitMix-style 32-bit generator.

Both generators provide:

- an externally visible seed/state variable;
- automatic seeding from a newly generated `TGUID`;
- explicit deterministic seeding;
- generation of values in the range `0..Range-1`;
- generation of values in an inclusive `Min..Max` range;
- rejection sampling to avoid modulo bias.

The generators are intended for general-purpose pseudo-random number
generation where speed, reproducibility, and good statistical distribution
are desirable.

They are **not cryptographically secure** and must not be used where
unpredictability against an attacker is required.

## Interface

```pascal
VAR
  RandSeed64 : UInt64 = 0;
  RandSeed32 : UInt32 = 0;

PROCEDURE RANDOMIZE64; OVERLOAD;
PROCEDURE RANDOMIZE64(Seed : UInt64); OVERLOAD;
FUNCTION RANDOM64(Range : UInt64) : UInt64;
FUNCTION RND64(Min,Max : UInt64) : UInt64;

PROCEDURE RANDOMIZE32; OVERLOAD;
PROCEDURE RANDOMIZE32(Seed : UInt32); OVERLOAD;
FUNCTION RANDOM32(Range : UInt32) : UInt32;
FUNCTION RND32(Min,Max : UInt32) : UInt32;
```

The 32-bit and 64-bit generators are completely independent. Calling a
32-bit function changes only `RandSeed32`; calling a 64-bit function changes
only `RandSeed64`.

## 64-bit generator

### `RandSeed64`

```pascal
VAR
  RandSeed64 : UInt64;
```

`RandSeed64` contains the complete state of the 64-bit generator.

Because the state is publicly accessible, it may also be saved and restored
when reproducible sequences are required.

For example:

```pascal
VAR
  SavedSeed : UInt64;

SavedSeed:=RandSeed64;

// Generate some values...

RandSeed64:=SavedSeed;
```

Restoring the seed restores the generator to exactly the same point in the
sequence.

All `UInt64` values, including zero, are valid states.

### `RANDOMIZE64`

```pascal
PROCEDURE RANDOMIZE64;
```

Initializes the 64-bit generator from a newly created `TGUID`.

The GUID contains 128 bits. The implementation treats those bits as two
`UInt64` values and folds them into the 64-bit generator state using XOR:

```pascal
RANDOMIZE64(Parts[0] XOR Parts[1]);
```

This is intended as a convenient way of obtaining a fresh starting state.
It does not make the generator cryptographically secure.

### `RANDOMIZE64(Seed)`

```pascal
PROCEDURE RANDOMIZE64(Seed : UInt64);
```

Explicitly initializes the 64-bit generator:

```pascal
RandSeed64:=Seed;
```

Using the same seed produces the same sequence of pseudo-random values. This
is useful for repeatable tests, simulations, procedural generation, and
debugging.

Example:

```pascal
RANDOMIZE64(123456789);

A:=RANDOM64(1000);
B:=RANDOM64(1000);
C:=RANDOM64(1000);
```

Repeating the same initialization produces the same values for `A`, `B`,
and `C`.

### SplitMix64

The internal 64-bit generator advances its state by adding the fixed Weyl
increment:

```pascal
$9E3779B97F4A7C15
```

The resulting state is then passed through the SplitMix64 mixing function.

The state transition visits every possible 64-bit state before repeating,
giving the generator a period of `2^64`.

The internal raw generator is intentionally kept in the implementation
section as `NextRandom64`; callers normally use `RANDOM64` or `RND64`
instead.

### `RANDOM64`

```pascal
FUNCTION RANDOM64(Range : UInt64) : UInt64;
```

Returns a pseudo-random value in:

```text
0 .. Range-1
```

For example:

```pascal
X:=RANDOM64(10);
```

returns a value from 0 through 9.

`Range` must be greater than zero. Passing zero raises `ERangeError`.

#### Avoiding modulo bias

A simple implementation such as:

```pascal
NextRandom64 MOD Range
```

would produce a small statistical bias whenever `Range` is not an exact
divisor of `2^64`.

`HeartWare.PRNG` avoids this by using rejection sampling.

It calculates:

```pascal
Threshold:=(UInt64(0)-Range) MOD Range;
```

The unsigned subtraction deliberately wraps around, effectively allowing
the remainder of `2^64` divided by `Range` to be determined without needing
an integer type wider than 64 bits.

Raw random values below `Threshold` are discarded. The remaining number of
possible input values is therefore an exact multiple of `Range`, making the
final:

```pascal
R MOD Range
```

unbiased.

### `RND64`

```pascal
FUNCTION RND64(Min,Max : UInt64) : UInt64;
```

Returns a pseudo-random value in the inclusive range:

```text
Min .. Max
```

For example:

```pascal
Die:=RND64(1,6);
```

returns a value from 1 through 6.

If `Max` is smaller than `Min`, `ERangeError` is raised.

The range width is calculated as:

```pascal
Range:=SUCC(Max-Min);
```

and the normal case is then implemented as:

```pascal
Result:=Min+RANDOM64(Range);
```

#### Complete UInt64 range

The expression:

```pascal
SUCC(High(UInt64))
```

wraps to zero.

Consequently:

```pascal
RND64(0,High(UInt64))
```

requires special handling. A calculated range of zero represents the entire
`UInt64` domain rather than an empty range.

In that case `RND64` returns the raw `NextRandom64` result directly.

This permits every possible `UInt64` value to be returned.

## 32-bit generator

The 32-bit API mirrors the 64-bit API.

### `RandSeed32`

```pascal
VAR
  RandSeed32 : UInt32;
```

Contains the complete state of the 32-bit generator.

All `UInt32` values, including zero, are valid states.

As with `RandSeed64`, saving and restoring this value saves and restores the
exact position in the pseudo-random sequence.

### `RANDOMIZE32`

```pascal
PROCEDURE RANDOMIZE32;
```

Creates a new `TGUID`, treats its 128 bits as four `UInt32` values, and folds
them into a single 32-bit state using XOR:

```pascal
RANDOMIZE32(Parts[0] XOR Parts[1] XOR Parts[2] XOR Parts[3]);
```

### `RANDOMIZE32(Seed)`

```pascal
PROCEDURE RANDOMIZE32(Seed : UInt32);
```

Explicitly initializes the 32-bit state:

```pascal
RandSeed32:=Seed;
```

The same seed always produces the same pseudo-random sequence.

### 32-bit SplitMix-style generator

The internal 32-bit generator advances the state by:

```pascal
$9E3779B9
```

and applies a sequence of XOR-shifts and multiplications to mix the bits.

The odd state increment causes every possible 32-bit state to be visited
before the state repeats, giving a period of `2^32`.

The internal raw generator is `NextRandom32` and is not exported through the
UNIT interface.

### `RANDOM32`

```pascal
FUNCTION RANDOM32(Range : UInt32) : UInt32;
```

Returns a pseudo-random value in:

```text
0 .. Range-1
```

`Range` must be greater than zero. Passing zero raises `ERangeError`.

As with `RANDOM64`, rejection sampling is used to avoid modulo bias:

```pascal
Threshold:=(UInt32(0)-Range) MOD Range;
```

### `RND32`

```pascal
FUNCTION RND32(Min,Max : UInt32) : UInt32;
```

Returns a pseudo-random value in the inclusive range:

```text
Min .. Max
```

If `Max` is smaller than `Min`, `ERangeError` is raised.

The complete 32-bit domain is also supported:

```pascal
RND32(0,High(UInt32))
```

When the calculated range wraps to zero, `RND32` returns `NextRandom32`
directly.

## Examples

### Automatic initialization

```pascal
RANDOMIZE64;

Value:=RANDOM64(100);
```

`Value` is in the range 0 through 99.

For the 32-bit generator:

```pascal
RANDOMIZE32;

Value:=RANDOM32(100);
```

### Inclusive range

```pascal
RANDOMIZE64;

Die:=RND64(1,6);
```

For the 32-bit version:

```pascal
RANDOMIZE32;

Card:=RND32(1,52);
```

### Repeatable sequence

```pascal
RANDOMIZE64($123456789ABCDEF0);

FOR I:=1 TO 100 DO
  Values[I]:=RANDOM64(1000000);
```

Using the same seed later reproduces the same sequence:

```pascal
RANDOMIZE64($123456789ABCDEF0);
```

This makes deterministic random sequences straightforward to reproduce.

### Independent generators

```pascal
RANDOMIZE32($12345678);
RANDOMIZE64($123456789ABCDEF0);

A:=RANDOM32(100);
B:=RANDOM64(100);
```

The calls do not affect each other's state.

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

## Thread safety

`RandSeed32` and `RandSeed64` are global mutable variables.

The generators are therefore **not thread-safe when the same generator is
used concurrently by multiple threads**.

Applications using the generator from multiple threads should either:

- serialize access to the global generator state; or
- maintain independent PRNG state for each thread.

The 32-bit and 64-bit generators use separate state variables, but that does
not make concurrent access to the same state variable safe.

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

`HeartWare.PRNG` provides a compact pair of unsigned pseudo-random generators
for Delphi:

┌───────────────────────┬────────────────────────────────────────────────────┐
│ Function              │ Result                                             │
├───────────────────────┼────────────────────────────────────────────────────┤
│ RANDOMIZE32           │ Seeds the 32-bit generator from a TGUID            │
│ RANDOMIZE32(Seed)     │ Sets an explicit 32-bit seed                       │
│ RANDOM32(Range)       │ Returns 0..Range-1 without modulo bias             │
│ RND32(Min,Max)        │ Returns inclusive Min..Max                         │
├───────────────────────┼────────────────────────────────────────────────────┤
│ RANDOMIZE64           │ Seeds the 64-bit generator from a TGUID            │
│ RANDOMIZE64(Seed)     │ Sets an explicit 64-bit seed                       │
│ RANDOM64(Range)       │ Returns 0..Range-1 without modulo bias             │
│ RND64(Min,Max)        │ Returns inclusive Min..Max                         │
└───────────────────────┴────────────────────────────────────────────────────┘

The complete generator state is held in `RandSeed32` and `RandSeed64`,
making deterministic sequences easy to reproduce, save, and restore.
