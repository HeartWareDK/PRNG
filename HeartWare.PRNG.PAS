UNIT HeartWare.PRNG;

INTERFACE

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

IMPLEMENTATION

{$Q-,R-} // No Overflow or Range checking - Calculations are supposed to wrap around

PROCEDURE RANDOMIZE64;
  VAR
    GUID  : TGUID;
    Parts : ARRAY[0..1] OF UInt64;
	
  BEGIN
    CreateGUID(GUID);
    Move(GUID,Parts,SizeOf(Parts));
    // Fold the GUID's 128 bits into 64 bits.
    RANDOMIZE64(Parts[0] XOR Parts[1])
  END;

PROCEDURE RANDOMIZE64(Seed : UInt64);
  BEGIN
    RandSeed64:=Seed
  END;

FUNCTION NextRandom64 : UInt64;
  VAR
    Z : UInt64;

  BEGIN
    // SplitMix64
    INC(RandSeed64,$9E3779B97F4A7C15);
    Z:=RandSeed64;
    Z:=(Z XOR (Z SHR 30))*UInt64($BF58476D1CE4E5B9);
    Z:=(Z XOR (Z SHR 27))*UInt64($94D049BB133111EB);
    Result:=Z XOR (Z SHR 31);
  END;

FUNCTION RANDOM64(Range : UInt64) : UInt64;
  VAR
    R         : UInt64;
    Threshold : UInt64;
	
  BEGIN
    IF Range=0 THEN       RAISE ERangeError.Create('RANDOM64 range must be greater than zero');

    // 2^64 MOD Range, calculated using unsigned wraparound.
    //
    // Values below Threshold are rejected so that the number of possible
    // source values is an exact multiple of Range. This avoids modulo bias.
    Threshold:=(UInt64(0)-Range) MOD Range;
    REPEAT
      R:=NextRandom64
    UNTIL R>=Threshold;

    Result:=R MOD Range
  END;

FUNCTION RND64(Min,Max : UInt64) : UInt64;
  VAR
    Range : UInt64;

  BEGIN
    IF Max<Min THEN RAISE ERangeError.CreatefMT('RND64: Max (%d) must be greater than or equal to Min (%d)',[Max,Min]);
    Range:=SUCC(Max-Min);
    // Range=0 means that the requested range contains all 2^64 possible
    // UInt64 values, i.e. Min=0 and Max=High(UInt64).
    IF Range=0 THEN
      Result:=NextRandom64
    ELSE
      Result:=Min+RANDOM64(Range);
  END;

PROCEDURE RANDOMIZE32;
  VAR
    GUID  : TGUID;
    Parts : ARRAY[0..3] OF UInt32;
	
  BEGIN
    CreateGUID(GUID);
    Move(GUID,Parts,SizeOf(Parts));
    // Fold the GUID's 128 bits into 32 bits.
    RANDOMIZE32(Parts[0] XOR Parts[1] XOR Parts[2] XOR Parts[3])
  END;

PROCEDURE RANDOMIZE32(Seed : UInt32);
  BEGIN
    RandSeed32:=Seed
  END;

FUNCTION NextRandom32 : UInt32;
  VAR
    Z : UInt32;

  BEGIN
    // SplitMix32
    INC(RandSeed32,$9E3779B9);
    Z:=RandSeed32;
    Z:=Z XOR (Z SHR 16);
    Z:=Z*UInt32($21F0AAAD);
    Z:=Z XOR (Z SHR 15);
    Z:=Z*UInt32($735A2D97);
    Result:=Z XOR (Z SHR 15);
  END;

FUNCTION RANDOM32(Range : UInt32) : UInt32;
  VAR
    R         : UInt32;
    Threshold : UInt32;
	
  BEGIN
    IF Range=0 THEN RAISE ERangeError.Create('RANDOM32 range must be greater than zero');
    // 2^32 MOD Range, computed using unsigned wraparound.
    Threshold:=(UInt32(0)-Range) MOD Range;
    REPEAT
      R:=NextRandom32
    UNTIL R>=Threshold;
    Result:=R MOD Range
  END;

FUNCTION RND32(Min,Max : UInt32) : UInt32;
  VAR
    Range : UInt32;

  BEGIN
    IF Max<Min THEN RAISE ERangeError.CreateFmt('RND32: Max (%d) must be greater than or equal to Min (%d)',[Max,Min]);
    Range:=SUCC(Max-Min);
    // Range=0 represents the complete UInt32 domain:
    // 0 .. $FFFFFFFF.
    IF Range=0 THEN
      Result:=NextRandom32
    ELSE
      Result:=Min+RANDOM32(Range)
  END;

END.
