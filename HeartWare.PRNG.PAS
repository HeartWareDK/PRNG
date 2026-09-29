UNIT HeartWare.PRNG;

INTERFACE

TYPE
  TPRNG32       = RECORD
                  PRIVATE
                    FSeed               : UInt32;
                    FUNCTION            NextRandom : UInt32;
                  PUBLIC
                    CLASS FUNCTION      Create : TPRNG32;                       OVERLOAD; static;
                    CLASS FUNCTION      Create(Seed : UInt32) : TPRNG32;        OVERLOAD; static;
                    FUNCTION            RANDOM(Range : UInt32) : UInt32;
                    FUNCTION            RND(Min,Max : UInt32) : UInt32;
                    PROCEDURE           RANDOMIZE;                              OVERLOAD;
                    PROCEDURE           RANDOMIZE(Seed : UInt32);               OVERLOAD;
                    PROPERTY            Seed : UInt32 Read FSeed Write FSeed;
                  END;
  TPRNG64       = RECORD
                  PRIVATE
                    FSeed               : UInt64;
                    FUNCTION            NextRandom : UInt64;
                  PUBLIC
                    CLASS FUNCTION      Create : TPRNG64;                       OVERLOAD; static;
                    CLASS FUNCTION      Create(Seed : UInt64) : TPRNG64;        OVERLOAD; static;
                    FUNCTION            RANDOM(Range : UInt64) : UInt64;
                    FUNCTION            RND(Min,Max : UInt64) : UInt64;
                    PROCEDURE           RANDOMIZE;                              OVERLOAD;
                    PROCEDURE           RANDOMIZE(Seed : UInt64);               OVERLOAD;
                    PROPERTY            Seed : UInt64 Read FSeed Write FSeed;
                  END;

VAR
  RandSeed64    : UInt64 = 0;
  RandSeed32    : UInt32 = 0;

PROCEDURE RANDOMIZE64; OVERLOAD;
PROCEDURE RANDOMIZE64(Seed : UInt64); OVERLOAD;
FUNCTION RANDOM64(Range : UInt64) : UInt64;
FUNCTION RND64(Min,Max : UInt64) : UInt64;

PROCEDURE RANDOMIZE32; OVERLOAD;
PROCEDURE RANDOMIZE32(Seed : UInt32); OVERLOAD;
FUNCTION RANDOM32(Range : UInt32) : UInt32;
FUNCTION RND32(Min,Max : UInt32) : UInt32;

IMPLEMENTATION

{$Q-,R-} // No Overflow or Range checking - Calculations are supposed to wrap around

FUNCTION PRNG64Next(VAR Seed : UInt64) : UInt64;
  VAR
    Z : UInt64;

  BEGIN
    // SplitMix64
    INC(Seed,$9E3779B97F4A7C15);
    Z:=Seed;
    Z:=(Z XOR (Z SHR 30))*UInt64($BF58476D1CE4E5B9);
    Z:=(Z XOR (Z SHR 27))*UInt64($94D049BB133111EB);
    Result:=Z XOR (Z SHR 31)
  END;

FUNCTION PRNG64Random(VAR Seed : UInt64; Range : UInt64) : UInt64;
  VAR
    R         : UInt64;
    Threshold : UInt64;

  BEGIN
    IF Range=0 THEN RAISE ERangeError.Create('RANDOM64 range must be greater than zero');
    // 2^64 MOD Range, calculated using unsigned wraparound.
    //
    // Values below Threshold are rejected so that the number of possible
    // source values is an exact multiple of Range. This avoids modulo bias.
    Threshold:=(UInt64(0)-Range) MOD Range;
    REPEAT
      R:=PRNG64Next(Seed)
    UNTIL R>=Threshold;
    Result:=R MOD Range
  END;

FUNCTION PRNG64Rnd(VAR Seed : UInt64; Min,Max : UInt64) : UInt64;
  VAR
    Range : UInt64;

  BEGIN
    IF Max<Min THEN RAISE ERangeError.CreateFmt('RND64: Max (%d) must be greater than or equal to Min (%d)',[Max,Min]);
    Range:=SUCC(Max-Min);
    // Range=0 means that the requested range contains all 2^64 possible
    // UInt64 values, i.e. Min=0 and Max=High(UInt64).
    IF Range=0 THEN
      Result:=PRNG64Next(Seed)
    ELSE
      Result:=Min+PRNG64Random(Seed,Range)
  END;

PROCEDURE PRNG64Randomize(VAR Seed : UInt64);
  VAR
    GUID  : TGUID;
    Parts : ARRAY[0..1] OF UInt64;

  BEGIN
    CreateGUID(GUID);
    Move(GUID,Parts,SizeOf(Parts));
    // Fold the GUID's 128 bits into 64 bits.
    Seed:=Parts[0] XOR Parts[1]
  END;

FUNCTION PRNG32Next(VAR Seed : UInt32) : UInt32;
  VAR
    Z : UInt32;

  BEGIN
    // SplitMix32
    INC(Seed,$9E3779B9);
    Z:=Seed;
    Z:=Z XOR (Z SHR 16);
    Z:=Z*UInt32($21F0AAAD);
    Z:=Z XOR (Z SHR 15);
    Z:=Z*UInt32($735A2D97);
    Result:=Z XOR (Z SHR 15)
  END;

FUNCTION PRNG32Random(VAR Seed : UInt32; Range : UInt32) : UInt32;
  VAR
    R         : UInt32;
    Threshold : UInt32;

  BEGIN
    IF Range=0 THEN RAISE ERangeError.Create('RANDOM32 range must be greater than zero');
    // 2^32 MOD Range, calculated using unsigned wraparound.
    //
    // Values below Threshold are rejected so that the number of possible
    // source values is an exact multiple of Range. This avoids modulo bias.
    Threshold:=(UInt32(0)-Range) MOD Range;
    REPEAT
      R:=PRNG32Next(Seed)
    UNTIL R>=Threshold;
    Result:=R MOD Range
  END;

FUNCTION PRNG32Rnd(VAR Seed : UInt32; Min,Max : UInt32) : UInt32;
  VAR
    Range : UInt32;

  BEGIN
    IF Max<Min THEN RAISE ERangeError.CreateFmt('RND32: Max (%d) must be greater than or equal to Min (%d)',[Max,Min]);
    Range:=SUCC(Max-Min);
    // Range=0 means that the requested range contains all 2^32 possible
    // UInt32 values, i.e. Min=0 and Max=High(UInt32).
    IF Range=0 THEN
      Result:=PRNG32Next(Seed)
    ELSE
      Result:=Min+PRNG32Random(Seed,Range)
  END;

PROCEDURE PRNG32Randomize(VAR Seed : UInt32);
  VAR
    GUID  : TGUID;
    Parts : ARRAY[0..3] OF UInt32;

  BEGIN
    CreateGUID(GUID);
    Move(GUID,Parts,SizeOf(Parts));
    // Fold the GUID's 128 bits into 32 bits.
    Seed:=Parts[0] XOR Parts[1] XOR Parts[2] XOR Parts[3]
  END;

PROCEDURE RANDOMIZE64;
  BEGIN
    PRNG64Randomize(RandSeed64)
  END;

PROCEDURE RANDOMIZE64(Seed : UInt64);
  BEGIN
    RandSeed64:=Seed
  END;

FUNCTION RANDOM64(Range : UInt64) : UInt64;
  BEGIN
    Result:=PRNG64Random(RandSeed64,Range)
  END;

FUNCTION RND64(Min,Max : UInt64) : UInt64;
  BEGIN
    Result:=PRNG64Rnd(RandSeed64,Min,Max)
  END;

PROCEDURE RANDOMIZE32;
  BEGIN
    PRNG32Randomize(RandSeed32)
  END;

PROCEDURE RANDOMIZE32(Seed : UInt32);
  BEGIN
    RandSeed32:=Seed
  END;

FUNCTION RANDOM32(Range : UInt32) : UInt32;
  BEGIN
    Result:=PRNG32Random(RandSeed32,Range)
  END;

FUNCTION RND32(Min,Max : UInt32) : UInt32;
  BEGIN
    Result:=PRNG32Rnd(RandSeed32,Min,Max)
  END;

{ TPRNG32 }

CLASS FUNCTION TPRNG32.Create : TPRNG32;
  BEGIN
    PRNG32Randomize(Result.FSeed)
  END;

CLASS FUNCTION TPRNG32.Create(Seed : UInt32) : TPRNG32;
  BEGIN
    Result.FSeed:=Seed
  END;

FUNCTION TPRNG32.NextRandom : UInt32;
  BEGIN
    Result:=PRNG32Next(FSeed)
  END;

FUNCTION TPRNG32.RANDOM(Range : UInt32) : UInt32;
  BEGIN
    Result:=PRNG32Random(FSeed,Range)
  END;

FUNCTION TPRNG32.RND(Min,Max : UInt32) : UInt32;
  BEGIN
    Result:=PRNG32Rnd(FSeed,Min,Max)
  END;

PROCEDURE TPRNG32.RANDOMIZE;
  BEGIN
    PRNG32Randomize(FSeed)
  END;

PROCEDURE TPRNG32.RANDOMIZE(Seed : UInt32);
  BEGIN
    FSeed:=Seed
  END;

{ TPRNG64 }

CLASS FUNCTION TPRNG64.Create : TPRNG64;
  BEGIN
    PRNG64Randomize(Result.FSeed)
  END;

CLASS FUNCTION TPRNG64.Create(Seed : UInt64) : TPRNG64;
  BEGIN
    Result.FSeed:=Seed
  END;

FUNCTION TPRNG64.NextRandom : UInt64;
  BEGIN
    Result:=PRNG64Next(FSeed)
  END;

FUNCTION TPRNG64.RANDOM(Range : UInt64) : UInt64;
  BEGIN
    Result:=PRNG64Random(FSeed,Range)
  END;

FUNCTION TPRNG64.RND(Min,Max : UInt64) : UInt64;
  BEGIN
    Result:=PRNG64Rnd(FSeed,Min,Max)
  END;

PROCEDURE TPRNG64.RANDOMIZE;
  BEGIN
    PRNG64Randomize(FSeed)
  END;

PROCEDURE TPRNG64.RANDOMIZE(Seed : UInt64);
  BEGIN
    FSeed:=Seed
  END;

END.
