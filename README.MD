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

`HeartWare.PRNG` is a Delphi UNIT providing independent, deterministic 32-bit and 64-bit pseudo-random number generators. RECORD instances can select either **SplitMix** or **PCG** at construction; the standalone global functions continue to use SplitMix.

The generator families are:

| Interface | SplitMix state | PCG variant | PCG state |
|---|---|---|---|
| `TPRNG32` | 32 bits, SplitMix-style | PCG XSH-RR 64/32 | Two `UInt32` words (64 bits) |
| `TPRNG64` | 64 bits, SplitMix64 | PCG XSL-RR 128/64 | Two `UInt64` words (128 bits) |
| Global `RANDOM32` / `RND32` | 32 bits | Not available | — |
| Global `RANDOM64` / `RND64` | 64 bits | Not available | — |

All algorithms are **non-cryptographic**. Do not use them for passwords, secrets, security tokens, cryptographic keys or nonces.

## Requirements and usage models

The unit uses `System.SysUtils` and `System.Generics.Collections` (`TStack<T>`). The RECORDs use custom managed-record operators (`Initialize`, `Finalize`, `Assign`), requiring a Delphi compiler supporting managed records (Delphi 10.4 or later).

Use one RECORD per independent sequence, task or thread. Distinct RECORDs have their own state and their own stacks; concurrently accessing the *same* RECORD requires external synchronization. Global `RandSeed32` and `RandSeed64` are shared mutable state and are **not thread-safe**.

## Public API

The declarations below summarize the public members in the current Pascal source (implementation and private fields omitted):

```pascal
TYPE
  TPRNGMethod = (SplitMix,PCG);

  TPRNG32State = RECORD
                   Seed      : UInt32;
                   SeedExtra : UInt32;
                 END;
  TPRNG64State = RECORD
                   Seed      : UInt64;
                   SeedExtra : UInt64;
                 END;

  TPRNG32Stack = TStack<TPRNG32State>;
  TPRNG64Stack = TStack<TPRNG64State>;

  TPRNG32 = RECORD
             PUBLIC
               CLASS OPERATOR Initialize(OUT Dest : TPRNG32);
               CLASS OPERATOR Finalize(VAR Dest : TPRNG32);
               CLASS OPERATOR Assign(VAR Dest : TPRNG32; CONST [ref] Src : TPRNG32);
               CLASS FUNCTION Create(Seed : UInt32 = 0; Method : TPRNGMethod = TPRNGMethod.SplitMix) : TPRNG32; OVERLOAD; static;
               CLASS FUNCTION Create(Method : TPRNGMethod; Seed : UInt32 = 0) : TPRNG32; OVERLOAD; static;
               FUNCTION RANDOM(Range : UInt32) : UInt32;
               FUNCTION RND(Min,Max : UInt32) : UInt32;
               PROCEDURE RANDOMIZE; OVERLOAD;
               PROCEDURE RANDOMIZE(Seed : UInt32); OVERLOAD;
               FUNCTION PUSH : TPRNG32State;
               FUNCTION POP : TPRNG32State;
               PROPERTY Seed : UInt32 Read FSeed Write SetSeed;
               PROPERTY FullSeed : TGUID Read GetFullSeed Write SetFullSeed;
               PROPERTY Method : TPRNGMethod Read FMethod;
             END;

  TPRNG64 = RECORD
             PUBLIC
               CLASS OPERATOR Initialize(OUT Dest : TPRNG64);
               CLASS OPERATOR Finalize(VAR Dest : TPRNG64);
               CLASS OPERATOR Assign(VAR Dest : TPRNG64; CONST [ref] Src : TPRNG64);
               CLASS FUNCTION Create(Seed : UInt64 = 0; Method : TPRNGMethod = TPRNGMethod.SplitMix) : TPRNG64; OVERLOAD; static;
               CLASS FUNCTION Create(Method : TPRNGMethod; Seed : UInt64 = 0) : TPRNG64; OVERLOAD; static;
               FUNCTION NextRandom : UInt64;
               FUNCTION RANDOM(Range : UInt64) : UInt64;
               FUNCTION RND(Min,Max : UInt64) : UInt64;
               PROCEDURE RANDOMIZE; OVERLOAD;
               PROCEDURE RANDOMIZE(Seed : UInt64); OVERLOAD;
               FUNCTION PUSH : TPRNG64State;
               FUNCTION POP : TPRNG64State;
               PROPERTY Seed : UInt64 Read FSeed Write SetSeed;
               PROPERTY FullSeed : TGUID Read GetFullSeed Write SetFullSeed;
               PROPERTY Method : TPRNGMethod Read FMethod;
             END;

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

PROCEDURE UnitTest;
```

`TPRNG32.NextRandom` is private; `TPRNG64.NextRandom` is public in this revision. Both advance the current generator by one raw output.

## Creating RECORD generators

Both overloads support seed-first and method-first argument ordering:

```pascal
VAR
  A,B,C,D,E : TPRNG64;

A:=TPRNG64.Create;              // SplitMix, GUID-seeded
B:=TPRNG64.Create(12345);       // SplitMix, reproducible seed
C:=TPRNG64.Create(12345,PCG);   // PCG, reproducible seed
D:=TPRNG64.Create(PCG);         // PCG, GUID-seeded
E:=TPRNG64.Create(PCG,12345);   // Same sequence as C
```

The same overloads exist for `TPRNG32`, using `UInt32` seeds. `Method` is read-only after initialization. Its default is `SplitMix`.

**Zero is special for RECORD initialization.** `Create()`, `Create(0)`, `Create(PCG,0)` and `RANDOMIZE(0)` all request a fresh `TGUID`-derived seed, rather than the deterministic numeric state zero. For deterministic initialization, supply a **nonzero** numeric seed or assign `FullSeed` explicitly.

Explicit nonzero SplitMix seeds are placed directly in `FSeed`. For PCG32, an explicit nonzero numeric seed is expanded with SplitMix64 into a 64-bit state. For PCG64, two successive SplitMix64 outputs derive the two 64-bit state words.

## Selecting and saving state

### `Method`

```pascal
IF RNG.Method=PCG THEN ...;
```

`Method` reports the algorithm selected when the RECORD was created. There is no public setter; construct a new RECORD to select a different algorithm.

### `Seed`

`Seed` reads the low state word (`UInt32` or `UInt64`). **It represents the complete state only in SplitMix mode.**

```pascal
RNG:=TPRNG64.Create(12345,SplitMix);
Saved:=RNG.Seed;
RNG.Seed:=Saved;  // Allowed in SplitMix mode
```

Writing `Seed` in `PCG` mode raises `EInvalidOpException`, because a single output-width integer cannot contain the full PCG state. Reading it is allowed but does **not** constitute a complete checkpoint. In SplitMix mode, assignment to `Seed` also clears the unused extra state word.

### `FullSeed : TGUID`

Both RECORDs expose `FullSeed` as a readable/writable `TGUID` representing their full internal state:

```pascal
VAR
  RNG : TPRNG64;
  Saved : TGUID;

RNG:=TPRNG64.Create(PCG,12345);
Saved:=RNG.FullSeed;
// Generate some values...
RNG.FullSeed:=Saved;   // Restore the complete state
```

The **getter** stores the current state in the low bytes of the GUID and zero-fills unused bytes:

| Method | `TPRNG32.FullSeed` getter | `TPRNG64.FullSeed` getter |
|---|---|---|
| SplitMix | 32-bit state + 96 zero bits | 64-bit state + 64 zero bits |
| PCG | 64-bit state + 64 zero bits | Full 128-bit state |

The **setter** handles the supplied GUID as follows:

| Method | `TPRNG32.FullSeed` setter | `TPRNG64.FullSeed` setter |
|---|---|---|
| SplitMix | XOR all four `UInt32` words into a 32-bit state | XOR both `UInt64` words into a 64-bit state |
| PCG | XOR word 0 with 2, and word 1 with 3, making a 64-bit state | Copy both `UInt64` words unchanged (128 bits) |

As a result, `RNG.FullSeed:=RNG.FullSeed` preserves state for any mode, but **an arbitrary 128-bit GUID may be folded** when assigned to a 32-bit generator or a 64-bit SplitMix generator. When you need reproducibility, save both the `Method` selection and `FullSeed`.

`FullSeed` restores the generator state, **not** its saved PUSH/POP history. Use RECORD assignment when you want to copy both.

### `RANDOMIZE`

```pascal
RNG.RANDOMIZE;          // New GUID seed
RNG.RANDOMIZE(12345);   // Reproducible (nonzero) numeric seed
RNG.RANDOMIZE(0);       // New GUID seed
```

For `TPRNG32`, the parameterless overload calls `TGUID.NewGuid` and assigns it to `FullSeed`. For `TPRNG64`, it calls `CreateGUID`, checks the result, and assigns `FullSeed`. Either way, GUID seeding is intended for convenience, not cryptographic security.

`RANDOMIZE` replaces the current state. It does not empty a previously populated PUSH/POP stack.

## Generating bounded values

`RANDOM(Range)` returns `0..Range-1`; `Range=0` raises `ERangeError`.

`RND(Min,Max)` returns the inclusive range `Min..Max`; `Max<Min` raises `ERangeError`.

```pascal
RNG:=TPRNG32.Create(PCG,12345);
Index:=RNG.RANDOM(100);   // 0..99
Die:=RNG.RND(1,6);       // 1..6
```

Both use rejection sampling to prevent modulo bias. The threshold is computed with deliberate unsigned wraparound:

```pascal
Threshold:=(UInt32(0)-Range) MOD Range;  // TPRNG32
Threshold:=(UInt64(0)-Range) MOD Range;  // TPRNG64
```

Raw values less than `Threshold` are discarded before `R MOD Range`. This remains necessary for both SplitMix and PCG. `RND(0,High(UInt32))` or `RND(0,High(UInt64))` bypasses bounded sampling and returns one raw result, handling the full unsigned domain correctly. A singleton range returns its only possible value and still advances the generator.

## PUSH, POP and managed-record assignment

`PUSH` lazily creates a `TStack<TPRNGXXState>` and saves **both** internal state words. `POP` restores both words. The state record returned by either function exposes `Seed` and `SeedExtra`. An empty stack raises `EInvalidOpException` on `POP`.

```pascal
VAR
  RNG : TPRNG64;
  SavedState : TPRNG64State;
  X,Y : UInt64;

RNG:=TPRNG64.Create(PCG,12345);
SavedState:=RNG.PUSH;
X:=RNG.RANDOM(1000000);
RNG.POP;
Y:=RNG.RANDOM(1000000);
ASSERT(X=Y);
```

`PUSH`/`POP` are nested, last-in-first-out operations. Save as many levels as required:

```pascal
A:=TPRNG32.Create(12345,PCG);
A.PUSH;
A.RANDOM(1000);
A.PUSH;
A.RANDOM(1000);
B:=A;                // Copy state and saved stack contents
A.POP;
B.POP;              // Both return to the same saved state
```

The custom `Assign` operator is intended to deep-copy the entire saved stack as well as current state and method, so subsequently pushing or popping one RECORD does not modify the other's stack. `Initialize` starts the stack pointer at `NIL`. `Finalize` asserts that a non-`NIL` stack is empty and then frees it (when assertions are enabled, pending saved states trigger an assertion). **Balance each `PUSH` with a `POP` before the RECORD goes out of scope** if you want that assertion to pass.

A zero-initialized stack is allocated on the first `PUSH`; you don't need to create or destroy the stack yourself.

## Global SplitMix interface

The old global API is preserved, and **does not provide PCG selection**:

```pascal
RANDOMIZE32;             // Seed shared 32-bit SplitMix from GUID
RANDOMIZE32(12345);      // Assign shared 32-bit seed directly
A:=RANDOM32(100);        // 0..99
B:=RND32(1,6);          // 1..6

RANDOMIZE64;             // Seed shared 64-bit SplitMix from GUID
RANDOMIZE64(12345);      // Assign shared 64-bit seed directly
C:=RANDOM64(100);        // 0..99
D:=RND64(1,6);          // 1..6
```

`RandSeed32` and `RandSeed64` are public global variables and may be read or written directly. Unlike RECORD constructors, **global `RANDOMIZE32(0)` and `RANDOMIZE64(0)` set the state to numeric zero**; they do not request GUID seeding. Use the parameterless global overload for a GUID-derived seed.

Global calls are based on the same internal SplitMix generator functions as RECORDs in SplitMix mode. The global and RECORD sequences agree when initialized with the same nonzero seed; the global state and each RECORD's state are otherwise independent.

## Algorithms and implementation

- **SplitMix32-style:** 32-bit Weyl increment `$9E3779B9`, followed by XOR/shift/multiply mixing. Its state transition has period `2^32`.
- **SplitMix64:** 64-bit Weyl increment `$9E3779B97F4A7C15`, followed by the SplitMix64 mixing steps. Its state transition has period `2^64`.
- **PCG32:** XSH-RR 64/32, using a 64-bit LCG state, fixed odd stream increment and 32-bit rotated output. Its state period is `2^64`.
- **PCG64:** XSL-RR 128/64, using a 128-bit LCG state, fixed odd stream increment and 64-bit rotated output. Its state period is `2^128`.

The PCG64 implementation operates on two `UInt64` halves and uses `MultiplyHigh64`; no native `UInt128` compiler type is needed. Both PCG output permutations use private `RotateRight32`/`RotateRight64` helpers; rotation counts are reduced modulo the corresponding word width. These are **rotations**, not ordinary shifts, so bits shifted off one end wrap around to the other.

The unit contains:

```pascal
{$Q-,R-}
```

Unsigned arithmetic is deliberately modulo `2^32` or `2^64` where appropriate, including state advancement, range-width overflow for full-domain `RND`, and rejection thresholds. Do not enable overflow/range checks around these operations without auditing their semantics.

## UnitTest regression tests

The public procedure:

```pascal
HeartWare.PRNG.UnitTest;
```

raises `EInvalidOpException` with the failing check's description when a regression is detected. It includes:

- exact expected-output vectors for SplitMix32/64 and PCG32/64;
- 32/64-bit rotations, including zero rotations, width-size and larger counts, edge bits and modular counts;
- `MultiplyHigh64` boundary cases;
- both constructor overloads, method selection and zero-seed creation;
- `FullSeed` round-trips, PCG64's 128-bit state, and `Seed` write restrictions;
- bounded values, full-domain ranges, exception cases and preservation of state after invalid requests;
- rejection-sampling comparisons with explicit raw-output loops;
- nested `PUSH`/`POP`, copied-stack restoration, transitive assignment, self-assignment and stack independence;
- global SplitMix reference values, restoring the global state when finished.

A normal return means every assertion in `UnitTest` completed without raising. It is a deterministic regression suite, **not** a statistical randomness or cryptographic-security certification.

## Version History

```text
┌─────────────┬─────────────────────────────────────────────────────────────────┐
│ 13 Oct 2026 │ Added PCG XSH-RR 64/32 and XSL-RR 128/64 alongside SplitMix,    │
│             │ selectable by TPRNGMethod and two Create overloads. Added       │
│             │ GUID-based zero seeding, FullSeed state access, PCG Seed-write  │
│             │ protection, PUSH/POP state stacks, managed-record lifetime      │
│             │ handling, deep-copy assignment and comprehensive UnitTest       │
│             │ regression checks. Global functions remain SplitMix-only.       │
├─────────────┼─────────────────────────────────────────────────────────────────┤
│ 02 Oct 2026 │ Initial release. SplitMix32 and SplitMix64 generators with      │
│             │ independent RECORDs and global APIs, GUID- or user-supplied     │
│             │  seeding, unbiased RANDOM ranges and inclusive RND ranges.      │
└─────────────┴─────────────────────────────────────────────────────────────────┘
```
