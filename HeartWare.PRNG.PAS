UNIT HeartWare.PRNG;

INTERFACE

USES System.Generics.Collections;

TYPE
  TPRNGMethod = (SplitMix,PCG);

  TPRNG32State  = RECORD
                    Seed      : UInt32;
                    SeedExtra : UInt32;
                  END;
  TPRNG32Stack  = TStack<TPRNG32State>;
  TPRNG64State  = RECORD
                    Seed      : UInt64;
                    SeedExtra : UInt64;
                  END;
  TPRNG64Stack  = TStack<TPRNG64State>;
  TPRNG32       = RECORD
                  PRIVATE
                    FSeed               : UInt32;
                    FSeedExtra          : UInt32;
                    FMethod             : TPRNGMethod;
                    FStack              : TPRNG32Stack;
                    PROCEDURE           SetSeed(Value : UInt32);
                    FUNCTION            NextRandom : UInt32;
                    FUNCTION            GetFullSeed : TGUID;                       OVERLOAD;
                    PROCEDURE           SetFullSeed(CONST Value : TGUID);          OVERLOAD;
                  PUBLIC
                    CLASS OPERATOR      Initialize(OUT Dest : TPRNG32);
                    CLASS OPERATOR      Finalize(VAR Dest : TPRNG32);
                    CLASS OPERATOR      Assign(VAR Dest : TPRNG32; CONST [ref] Src : TPRNG32);
                    CLASS FUNCTION      Create(Seed : UInt32 = 0; Method : TPRNGMethod = TPRNGMethod.SplitMix) : TPRNG32; OVERLOAD; static;
                    CLASS FUNCTION      Create(Method : TPRNGMethod; Seed : UInt32 = 0) : TPRNG32; OVERLOAD; static;
                    FUNCTION            RANDOM(Range : UInt32) : UInt32;
                    FUNCTION            RND(Min,Max : UInt32) : UInt32;
                    PROCEDURE           RANDOMIZE;                              OVERLOAD;
                    PROCEDURE           RANDOMIZE(Seed : UInt32);               OVERLOAD;
                    FUNCTION            PUSH : TPRNG32State;
                    FUNCTION            POP : TPRNG32State;
                    PROPERTY            Seed : UInt32 Read FSeed Write SetSeed;
                    PROPERTY            FullSeed : TGUID Read GetFullSeed Write SetFullSeed;
                    PROPERTY            Method : TPRNGMethod Read FMethod;
                  END;
  TPRNG64       = RECORD
                  PRIVATE
                    FSeed               : UInt64;
                    FSeedExtra          : UInt64;
                    FMethod             : TPRNGMethod;
                    FStack              : TPRNG64Stack;
                    PROCEDURE           SetSeed(Value : UInt64);
                    FUNCTION            GetFullSeed : TGUID;                    OVERLOAD;
                    PROCEDURE           SetFullSeed(CONST Value : TGUID);       OVERLOAD;
                  PUBLIC
                    CLASS OPERATOR      Initialize(OUT Dest : TPRNG64);
                    CLASS OPERATOR      Finalize(VAR Dest : TPRNG64);
                    CLASS OPERATOR      Assign(VAR Dest : TPRNG64; CONST [ref] Src : TPRNG64);
                    CLASS FUNCTION      Create(Seed : UInt64 = 0; Method : TPRNGMethod = TPRNGMethod.SplitMix) : TPRNG64; OVERLOAD; static;
                    CLASS FUNCTION      Create(Method : TPRNGMethod; Seed : UInt64 = 0) : TPRNG64; OVERLOAD; static;
                    FUNCTION            NextRandom : UInt64;
                    FUNCTION            RANDOM(Range : UInt64) : UInt64;
                    FUNCTION            RND(Min,Max : UInt64) : UInt64;
                    PROCEDURE           RANDOMIZE;                              OVERLOAD;
                    PROCEDURE           RANDOMIZE(Seed : UInt64);               OVERLOAD;
                    FUNCTION            PUSH : TPRNG64State;
                    FUNCTION            POP : TPRNG64State;
                    PROPERTY            FullSeed : TGUID Read GetFullSeed Write SetFullSeed;
                    PROPERTY            Seed : UInt64 Read FSeed Write SetSeed;
                    PROPERTY            Method : TPRNGMethod Read FMethod;
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

PROCEDURE UnitTest;

IMPLEMENTATION

USES System.SysUtils;

PROCEDURE CopyStack32(CONST Source : TPRNG32Stack ; VAR Target : TPRNG32Stack);
  BEGIN
    FreeAndNil(Target);
    IF Source=NIL THEN EXIT;
    Target:=TPRNG32Stack.Create(Source)
  END;

PROCEDURE CopyStack64(CONST Source : TPRNG64Stack ; VAR Target : TPRNG64Stack);
  BEGIN
    FreeAndNil(Target);
    IF Source=NIL THEN EXIT;
    Target:=TPRNG64Stack.Create(Source)
  END;

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
    Result:=IF Range=0 THEN PRNG64Next(Seed) ELSE Min+PRNG64Random(Seed,Range)
  END;

PROCEDURE PRNG64Randomize(VAR Seed : UInt64);
  VAR
    GUID  : TGUID;
    Parts : ARRAY[0..1] OF UInt64 ABSOLUTE GUID;

  BEGIN
    GUID:=TGUID.NewGuid;
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
    Result:=IF Range=0 THEN PRNG32Next(Seed) ELSE Min+PRNG32Random(Seed,Range)
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

// PCG uses a fixed (odd) stream increment. The two UIntXX seed words
// hold the full 64/128-bit state; no UInt128 compiler type is required.

FUNCTION RotateRight32(Value : UInt32; Count : UInt32) : UInt32;
  BEGIN
    Count:=Count AND 31;
    Result:=(Value SHR Count) OR (Value SHL ((UInt32(0)-Count) AND 31))
  END;

FUNCTION RotateRight64(Value : UInt64; Count : UInt32) : UInt64;
  BEGIN
    Count:=Count AND 63;
    Result:=(Value SHR Count) OR (Value SHL ((UInt32(0)-Count) AND 63))
  END;

FUNCTION PCG32Next(VAR Seed,SeedExtra : UInt32) : UInt32;
  VAR
    OldState : UInt64;
    NewState : UInt64;
    X        : UInt32;
    Rotation : UInt32;

  BEGIN
    // PCG XSH-RR 64/32, fixed stream; Seed is the low 32 bits.
    OldState:=(UInt64(SeedExtra) SHL 32) OR UInt64(Seed);
    NewState:=OldState*UInt64($5851F42D4C957F2D)+UInt64($14057B7EF767814F);
    Seed:=UInt32(NewState AND $FFFFFFFF);
    SeedExtra:=UInt32(NewState SHR 32);
    X:=UInt32(((OldState SHR 18) XOR OldState) SHR 27);
    Rotation:=UInt32(OldState SHR 59);
    Result:=RotateRight32(X,Rotation)
  END;

FUNCTION MultiplyHigh64(A,B : UInt64) : UInt64;
  CONST
    Mask                = UInt64($FFFFFFFF);

  VAR
    P0,P1,P2,P3,Carry   : UInt64;

  BEGIN
    // Upper half of the 64x64 => 128-bit unsigned product.
    P0:=(A AND Mask)*(B AND Mask);
    P1:=(A SHR 32)*(B AND Mask);
    P2:=(A AND Mask)*(B SHR 32);
    P3:=(A SHR 32)*(B SHR 32);
    Carry:=(P0 SHR 32)+(P1 AND Mask)+(P2 AND Mask);
    Result:=P3+(P1 SHR 32)+(P2 SHR 32)+(Carry SHR 32)
  END;

FUNCTION PCG64Next(VAR Seed,SeedExtra : UInt64) : UInt64;
  CONST
    MultLow             = UInt64($4385DF649FCCF645);
    MultHigh            = UInt64($2360ED051FC65DA4);
    IncLow              = UInt64($14057B7EF767814F);
    IncHigh             = UInt64($5851F42D4C957F2D);

  VAR
    OldLow,OldHigh      : UInt64;
    ProductLow          : UInt64;
    Rotation            : UInt32;

  BEGIN
    // PCG XSL-RR 128/64, fixed stream; Seed is the low 64 bits.
    OldLow:=Seed;
    OldHigh:=SeedExtra;
    ProductLow:=OldLow*MultLow;
    Seed:=ProductLow+IncLow;
    SeedExtra:=OldHigh*MultLow+OldLow*MultHigh+MultiplyHigh64(OldLow,MultLow)+IncHigh;
    IF Seed<ProductLow THEN INC(SeedExtra);
    Rotation:=UInt32(OldHigh SHR 58);
    Result:=RotateRight64(OldHigh XOR OldLow,Rotation)
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

CLASS OPERATOR TPRNG32.Initialize(OUT Dest : TPRNG32);
  BEGIN
    FillChar(Dest,SizeOf(TPRNG32),0)
  END;

CLASS OPERATOR TPRNG32.Finalize(VAR Dest : TPRNG32);
  BEGIN
    IF Assigned(Dest.FStack) THEN BEGIN
      ASSERT(Dest.FStack.IsEmpty,'PRNG32 state stack if not empty!');
      FreeAndNIL(Dest.FStack)
    END
  END;

CLASS OPERATOR TPRNG32.Assign(VAR Dest : TPRNG32; CONST [ref] Src : TPRNG32);
  BEGIN
    IF @Dest=@Src THEN EXIT;
    // Copy the entire history before committing the new current state.
    CopyStack32(Src.FStack,Dest.FStack);
    Dest.FMethod:=Src.FMethod;
    Dest.FullSeed:=Src.FullSeed
  END;

CLASS FUNCTION TPRNG32.Create(Seed : UInt32 = 0 ; Method : TPRNGMethod = TPRNGMethod.SplitMix) : TPRNG32;
  BEGIN
    Result.FMethod:=Method;
    Result.RANDOMIZE(Seed)
  END;

CLASS FUNCTION TPRNG32.Create(Method : TPRNGMethod; Seed : UInt32 = 0) : TPRNG32;
  BEGIN
    Result:=TPRNG32.Create(Seed,Method)
  END;

PROCEDURE TPRNG32.SetSeed(Value : UInt32);
  BEGIN
    IF FMethod=PCG THEN
      RAISE EInvalidOpException.Create('Seed cannot be assigned in PCG mode; use FullSeed or RANDOMIZE');
    FSeed:=Value; FSeedExtra:=0
  END;

FUNCTION TPRNG32.NextRandom : UInt32;
  BEGIN
    CASE FMethod OF
      SplitMix : Result:=PRNG32Next(FSeed);
      PCG      : Result:=PCG32Next(FSeed,FSeedExtra);
    ELSE // OTHERWISE //
      RAISE ERangeError.Create('Unknown PRNG method')
    END
  END;

FUNCTION TPRNG32.RANDOM(Range : UInt32) : UInt32;
  VAR
    R         : UInt32;
    Threshold : UInt32;

  BEGIN
    IF Range=0 THEN RAISE ERangeError.Create('RANDOM32 range must be greater than zero');
    Threshold:=(UInt32(0)-Range) MOD Range;
    REPEAT
      R:=NextRandom
    UNTIL R>=Threshold;
    Result:=R MOD Range
  END;

FUNCTION TPRNG32.RND(Min,Max : UInt32) : UInt32;
  VAR
    Range : UInt32;

  BEGIN
    IF Max<Min THEN RAISE ERangeError.CreateFmt('RND32: Max (%d) must be greater than or equal to Min (%d)',[Max,Min]);
    Range:=SUCC(Max-Min);
    Result:=IF Range=0 THEN NextRandom ELSE Min+RANDOM(Range)
  END;

PROCEDURE TPRNG32.RANDOMIZE;
  BEGIN
    FullSeed:=TGUID.NewGuid
  END;

PROCEDURE TPRNG32.RANDOMIZE(Seed : UInt32);
  VAR
    State : UInt64;

  BEGIN
    IF Seed=0 THEN
      RANDOMIZE
    ELSE IF FMethod=SplitMix THEN
      SetSeed(Seed)
    ELSE BEGIN
      State:=UInt64(Seed);
      State:=PRNG64Next(State);
      FSeed:=UInt32(State);
      FSeedExtra:=UInt32(State SHR 32)
    END
  END;

FUNCTION TPRNG32.GetFullSeed : TGUID;
  VAR
    State : UInt64;

  BEGIN
    FillChar(Result,SizeOf(Result),0);
    IF FMethod<>PCG THEN
      Move(FSeed,Result,SizeOf(FSeed))
    ELSE BEGIN
      State:=(UInt64(FSeedExtra) SHL 32) OR FSeed;
      Move(State,Result,SizeOf(State))
    END
  END;

PROCEDURE TPRNG32.SetFullSeed(CONST Value : TGUID);
  VAR
    Words : ARRAY[0..3] OF UInt32 ABSOLUTE Value;

  BEGIN
    IF FMethod=SplitMix THEN BEGIN
      FSeed:=Words[0] XOR Words[1] XOR Words[2] XOR Words[3];
      FSeedExtra:=0
    END ELSE BEGIN
      // Fold 128 GUID bits into the full 64-bit PCG32 state.
      FSeed:=Words[0] XOR Words[2];
      FSeedExtra:=Words[1] XOR Words[3]
    END
  END;

FUNCTION TPRNG32.PUSH : TPRNG32State;
  BEGIN
    IF FStack=NIL THEN FStack:=TPRNG32Stack.Create;
    Result.Seed:=FSeed;
    Result.SeedExtra:=FSeedExtra;
    FStack.Push(Result)
  END;

FUNCTION TPRNG32.POP : TPRNG32State;
  BEGIN
    IF (FStack=NIL) OR (FStack.Count=0) THEN
      RAISE EInvalidOpException.Create('PRNG32 state stack is empty');
    Result:=FStack.Pop;
    FSeed:=Result.Seed;
    FSeedExtra:=Result.SeedExtra
  END;

{ TPRNG64 }

CLASS OPERATOR TPRNG64.Initialize(OUT Dest : TPRNG64);
  BEGIN
    FillChar(Dest,SizeOf(TPRNG64),0)
  END;

CLASS OPERATOR TPRNG64.Finalize(VAR Dest : TPRNG64);
  BEGIN
    IF Assigned(Dest.FStack) THEN BEGIN
      ASSERT(Dest.FStack.IsEmpty,'PRNG64 state stack if not empty!');
      FreeAndNIL(Dest.FStack)
    END
  END;

CLASS OPERATOR TPRNG64.Assign(VAR Dest : TPRNG64; CONST [ref] Src : TPRNG64);
  BEGIN
    IF @Dest=@Src THEN EXIT;
    // Copy the entire history before committing the new current state.
    CopyStack64(Src.FStack,Dest.FStack);
    Dest.FMethod:=Src.FMethod;
    Dest.FullSeed:=Src.FullSeed
  END;

CLASS FUNCTION TPRNG64.Create(Seed : UInt64; Method : TPRNGMethod) : TPRNG64;
  BEGIN
    Result.FMethod:=Method;
    Result.RANDOMIZE(Seed)
  END;

CLASS FUNCTION TPRNG64.Create(Method : TPRNGMethod; Seed : UInt64) : TPRNG64;
  BEGIN
    Result:=TPRNG64.Create(Seed,Method)
  END;

PROCEDURE TPRNG64.SetSeed(Value : UInt64);
  BEGIN
    IF FMethod=PCG THEN
      RAISE EInvalidOpException.Create('Seed cannot be assigned in PCG mode; use FullSeed or RANDOMIZE');
    FSeed:=Value; FSeedExtra:=0
  END;

FUNCTION TPRNG64.NextRandom : UInt64;
  BEGIN
    CASE FMethod OF
      SplitMix : Result:=PRNG64Next(FSeed);
      PCG      : Result:=PCG64Next(FSeed,FSeedExtra);
    ELSE // OTHERWISE //
      RAISE ERangeError.Create('Unknown PRNG method')
    END
  END;

FUNCTION TPRNG64.RANDOM(Range : UInt64) : UInt64;
  VAR
    R         : UInt64;
    Threshold : UInt64;

  BEGIN
    IF Range=0 THEN RAISE ERangeError.Create('RANDOM64 range must be greater than zero');
    Threshold:=(UInt64(0)-Range) MOD Range;
    REPEAT
      R:=NextRandom
    UNTIL R>=Threshold;
    Result:=R MOD Range
  END;

FUNCTION TPRNG64.RND(Min,Max : UInt64) : UInt64;
  VAR
    Range : UInt64;

  BEGIN
    IF Max<Min THEN RAISE ERangeError.CreateFmt('RND64: Max (%d) must be greater than or equal to Min (%d)',[Max,Min]);
    Range:=SUCC(Max-Min);
    Result:=IF Range=0 THEN NextRandom ELSE Min+RANDOM(Range)
  END;

PROCEDURE TPRNG64.RANDOMIZE;
  VAR
    GUID : TGUID;

  BEGIN
    IF CreateGUID(GUID)<>0 THEN
      RAISE EInvalidOpException.Create('Unable to create GUID for PRNG seed');
    FullSeed:=GUID
  END;

PROCEDURE TPRNG64.RANDOMIZE(Seed : UInt64);
  VAR
    State : UInt64;

  BEGIN
    IF Seed=0 THEN BEGIN
      RANDOMIZE;
      EXIT
    END;
    IF FMethod=SplitMix THEN
      SetSeed(Seed)
    ELSE BEGIN
      State:=Seed;
      FSeed:=PRNG64Next(State);
      FSeedExtra:=PRNG64Next(State)
    END
  END;

FUNCTION TPRNG64.GetFullSeed : TGUID;
  BEGIN
    FillChar(Result,SizeOf(Result),0);
    Move(FSeed,Result,SizeOf(FSeed));
    IF FMethod=PCG THEN
      Move(FSeedExtra,Result.D4,SizeOf(FSeedExtra))
  END;

PROCEDURE TPRNG64.SetFullSeed(CONST Value : TGUID);
  VAR
    Words : ARRAY[0..1] OF UInt64;

  BEGIN
    Move(Value,Words,SizeOf(Words));
    IF FMethod=SplitMix THEN BEGIN
      FSeed:=Words[0] XOR Words[1];
      FSeedExtra:=0
    END ELSE BEGIN
      // The PCG64 state consumes all 128 GUID bits without folding.
      FSeed:=Words[0];
      FSeedExtra:=Words[1]
    END
  END;

FUNCTION TPRNG64.PUSH : TPRNG64State;
  BEGIN
    IF FStack=NIL THEN FStack:=TPRNG64Stack.Create;
    Result.Seed:=FSeed;
    Result.SeedExtra:=FSeedExtra;
    FStack.Push(Result)
  END;

FUNCTION TPRNG64.POP : TPRNG64State;
  BEGIN
    IF (FStack=NIL) OR (FStack.Count=0) THEN
      RAISE EInvalidOpException.Create('PRNG64 state stack is empty');
    Result:=FStack.Pop;
    FSeed:=Result.Seed;
    FSeedExtra:=Result.SeedExtra
  END;

// Self-contained deterministic regression tests. Failures raise EInvalidOpException.
// Calling UnitTest has no lasting effect on the global PRNG states.
PROCEDURE UnitTest;
  CONST
    TestGUID    : TGUID = '{FEDCBA98-7654-3210-0123-456789ABCDEF}';

  VAR
    A32,B32,C32 : TPRNG32;
    A64,B64,C64 : TPRNG64;
    Method      : TPRNGMethod;
    G,H         : TGUID;
    S32         : UInt32;
    S64         : UInt64;
    I,J         : Integer;
    V32         : UInt32;
    V64         : UInt64;
    Raised      : Boolean;
    Rejected32  : Boolean;
    Rejected64  : Boolean;
    Threshold32 : UInt32;
    Threshold64 : UInt64;
    Candidate32 : UInt32;
    Candidate64 : UInt64;

  PROCEDURE Check(Condition : Boolean; CONST Message : String);
    BEGIN
      IF NOT Condition THEN
        RAISE EInvalidOpException.Create('HeartWare.PRNG UnitTest: '+Message)
    END;

  PROCEDURE Check32(Expected,Actual : UInt32; CONST Message : String);
    BEGIN
      IF Expected<>Actual THEN
        RAISE EInvalidOpException.CreateFmt('HeartWare.PRNG UnitTest: %s (expected %.8x, got %.8x)',
                                            [Message,Expected,Actual])
    END;

  PROCEDURE Check64(Expected,Actual : UInt64; CONST Message : String);
    BEGIN
      IF Expected<>Actual THEN
        RAISE EInvalidOpException.CreateFmt('HeartWare.PRNG UnitTest: %s (expected %.16x, got %.16x)',
                                            [Message,Expected,Actual])
    END;

  PROCEDURE CheckGUID(CONST Expected,Actual : TGUID; CONST Message : String);
    BEGIN
      Check(CompareMem(@Expected,@Actual,SizeOf(TGUID)),Message)
    END;

  BEGIN
    // Rotation: identity, wraparound, modulo-width, discarded bits and high-bit carry.
    Check32($80000001,RotateRight32($80000001,0),'RotateRight32 zero');
    Check32($C0000000,RotateRight32($80000001,1),'RotateRight32 one');
    Check32($00000003,RotateRight32($80000001,31),'RotateRight32 31');
    Check32($80000001,RotateRight32($80000001,32),'RotateRight32 32');
    Check32($C0000000,RotateRight32($80000001,33),'RotateRight32 33');
    Check32($80000001,RotateRight32($80000001,64),'RotateRight32 64');
    Check32($00000001,RotateRight32($00000002,1),'RotateRight32 truncation');
    Check32($00000001,RotateRight32($80000000,31),'RotateRight32 high bit');
    Check64($8000000000000001,RotateRight64($8000000000000001,0),'RotateRight64 zero');
    Check64($C000000000000000,RotateRight64($8000000000000001,1),'RotateRight64 one');
    Check64($0000000000000003,RotateRight64($8000000000000001,63),'RotateRight64 63');
    Check64($8000000000000001,RotateRight64($8000000000000001,64),'RotateRight64 64');
    Check64($C000000000000000,RotateRight64($8000000000000001,65),'RotateRight64 65');
    Check64($8000000000000001,RotateRight64($8000000000000001,128),'RotateRight64 128');
    Check64(1,RotateRight64(2,1),'RotateRight64 truncation');
    Check64(1,RotateRight64($8000000000000000,63),'RotateRight64 high bit');
    FOR I:=0 TO 127 DO BEGIN
      Check32(RotateRight32($A53C19E7,UInt32(I AND 31)),RotateRight32($A53C19E7,UInt32(I)),
              'RotateRight32 modulo width');
      Check64(RotateRight64($A53C19E7F02468BD,UInt32(I AND 63)),
              RotateRight64($A53C19E7F02468BD,UInt32(I)),
              'RotateRight64 modulo width')
    END;

    // Independent known-answer sequences (not obtained by comparing two instances).
    A32:=TPRNG32.Create(1,SplitMix);
    Check32($5E2D1772,A32.RND(0,High(UInt32)),'SplitMix32 vector 1');
    Check32($14E498F0,A32.RND(0,High(UInt32)),'SplitMix32 vector 2');
    Check32($D20EA1FD,A32.RND(0,High(UInt32)),'SplitMix32 vector 3');
    Check32($B382F339,A32.RND(0,High(UInt32)),'SplitMix32 vector 4');
    A64:=TPRNG64.Create(1,SplitMix);
    Check64($910A2DEC89025CC1,A64.RND(0,High(UInt64)),'SplitMix64 vector 1');
    Check64($BEEB8DA1658EEC67,A64.RND(0,High(UInt64)),'SplitMix64 vector 2');
    Check64($F893A2EEFB32555E,A64.RND(0,High(UInt64)),'SplitMix64 vector 3');
    Check64($71C18690EE42C90B,A64.RND(0,High(UInt64)),'SplitMix64 vector 4');

    A32:=TPRNG32.Create(PCG,1);
    G:=Default(TGUID);
    // PCG32 vector state: high=$89ABCDEF, low=$01234567.
    V64:=UInt64($89ABCDEF01234567);
    Move(V64,G,SizeOf(V64));
    A32.FullSeed:=G;
    Check32($F85F1ABE,A32.RND(0,High(UInt32)),'PCG32 vector 1');
    Check32($27D2389C,A32.RND(0,High(UInt32)),'PCG32 vector 2');
    Check32($25DC28F5,A32.RND(0,High(UInt32)),'PCG32 vector 3');
    Check32($B58F077B,A32.RND(0,High(UInt32)),'PCG32 vector 4');

    A64:=TPRNG64.Create(PCG,1);
    G:=Default(TGUID);
    V64:=$0123456789ABCDEF;
    Move(V64,G,SizeOf(V64));
    V64:=$FEDCBA9876543210;
    Move(V64,G.D4,SizeOf(V64));
    A64.FullSeed:=G;
    Check64(High(UInt64),A64.RND(0,High(UInt64)),'PCG64 vector 1');
    Check64($764A3AD15D76F8EF,A64.RND(0,High(UInt64)),'PCG64 vector 2');
    Check64($A63ECC8FB0F5D6EA,A64.RND(0,High(UInt64)),'PCG64 vector 3');
    Check64($4001162E26A3B154,A64.RND(0,High(UInt64)),'PCG64 vector 4');

    // Multiplication high-half boundary cases.
    Check64(0,MultiplyHigh64(0,High(UInt64)),'MultiplyHigh64 zero');
    Check64(0,MultiplyHigh64(1,High(UInt64)),'MultiplyHigh64 one');
    Check64(High(UInt64)-1,MultiplyHigh64(High(UInt64),High(UInt64)),'MultiplyHigh64 maximum');
    Check64($4000000000000000,MultiplyHigh64($8000000000000000,
                                             $8000000000000000),'MultiplyHigh64 high bits');

    // Both algorithms: constructors, seed handling, bounds, stack and assignment.
    FOR Method:=Low(TPRNGMethod) TO High(TPRNGMethod) DO BEGIN
      A32:=TPRNG32.Create(123,Method);
      B32:=TPRNG32.Create(Method,123);
      A64:=TPRNG64.Create(UInt64(123),Method);
      B64:=TPRNG64.Create(Method,UInt64(123));
      Check((A32.Method=Method) AND (A64.Method=Method),'Method property');
      FOR I:=1 TO 20 DO BEGIN
        Check32(A32.RND(0,High(UInt32)),B32.RND(0,High(UInt32)),'Create overload 32');
        Check64(A64.RND(0,High(UInt64)),B64.RND(0,High(UInt64)),'Create overload 64')
      END;

      // FullSeed getter/setter roundtrip; in PCG64 all 128 bits must survive.
      A32.FullSeed:=TestGUID;
      A64.FullSeed:=TestGUID;
      G:=A32.FullSeed;
      H:=A64.FullSeed;
      B32.FullSeed:=G;
      B64.FullSeed:=H;
      CheckGUID(G,B32.FullSeed,'FullSeed32 roundtrip');
      CheckGUID(H,B64.FullSeed,'FullSeed64 roundtrip');
      IF Method=PCG THEN CheckGUID(TestGUID,H,'FullSeed64 PCG preserves all 128 bits');
      FOR I:=1 TO 16 DO BEGIN
        Check32(A32.RND(0,High(UInt32)),B32.RND(0,High(UInt32)),'FullSeed32 sequence');
        Check64(A64.RND(0,High(UInt64)),B64.RND(0,High(UInt64)),'FullSeed64 sequence')
      END;

      // Seed assignment works only in SplitMix mode.
      Raised:=FALSE;
      TRY A32.Seed:=777 EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised=(Method=PCG),'Seed32 setter restriction');
      Raised:=FALSE;
      TRY A64.Seed:=777 EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised=(Method=PCG),'Seed64 setter restriction');
      IF Method=SplitMix THEN BEGIN
        Check32(777,A32.Seed,'Seed32 assignment');
        Check64(777,A64.Seed,'Seed64 assignment')
      END;

      // Ranges: singleton, powers of two, non-powers, near-full and complete domain.
      FOR I:=1 TO 500 DO BEGIN
        Check32(0,A32.RANDOM(1),'RANDOM32 singleton');
        Check64(0,A64.RANDOM(1),'RANDOM64 singleton');
        V32:=A32.RANDOM(7);
        V64:=A64.RANDOM(7);
        Check(V32<7,'RANDOM32 range seven');
        Check(V64<7,'RANDOM64 range seven');
        Check(A32.RANDOM(256)<256,'RANDOM32 power of two');
        Check(A64.RANDOM(256)<256,'RANDOM64 power of two');
        Check(A32.RANDOM(High(UInt32))<High(UInt32),'RANDOM32 maximum range');
        Check(A64.RANDOM(High(UInt64))<High(UInt64),'RANDOM64 maximum range');
        Check32(123,A32.RND(123,123),'RND32 singleton');
        Check64(123,A64.RND(123,123),'RND64 singleton');
        V32:=A32.RND(High(UInt32)-10,High(UInt32));
        V64:=A64.RND(High(UInt64)-10,High(UInt64));
        Check(V32>=High(UInt32)-10,'RND32 upper edge');
        Check(V64>=High(UInt64)-10,'RND64 upper edge');
        A32.RND(0,High(UInt32));
        A64.RND(0,High(UInt64))
      END;

      // Compare bounded results against independent explicit rejection loops.
      // A range just over half the integer domain rejects nearly half the values.
      A32:=TPRNG32.Create(123,Method);
      A64:=TPRNG64.Create(123,Method);
      B32:=A32; B64:=A64;
      VAR UI32A : UInt32 := 0;
      VAR UI32B : UInt32 := $80000001;
      Threshold32:=(UI32A-UI32B) MOD UI32B;
      VAR UI64A : UInt64 := 0;
      VAR UI64B : UInt64 := $8000000000000001;
      Threshold64:=(UI64A-UI64B) MOD UI64B;
      Rejected32:=FALSE;
      Rejected64:=FALSE;
      FOR I:=1 TO 100 DO BEGIN
        REPEAT
          Candidate32:=B32.NextRandom;
          IF Candidate32<Threshold32 THEN Rejected32:=TRUE
        UNTIL Candidate32>=Threshold32;
        Check32(Candidate32 MOD UInt32($80000001),A32.RANDOM($80000001),
                'RANDOM32 rejection-sampling result');
        REPEAT
          Candidate64:=B64.NextRandom;
          IF Candidate64<Threshold64 THEN Rejected64:=TRUE
        UNTIL Candidate64>=Threshold64;
        Check64(Candidate64 MOD UInt64($8000000000000001),
                A64.RANDOM($8000000000000001),
                'RANDOM64 rejection-sampling result')
      END;
      Check(Rejected32 AND Rejected64,'Rejection loop exercised for both widths');
      CheckGUID(A32.FullSeed,B32.FullSeed,'RANDOM32 rejection preserves sequence state');
      CheckGUID(A64.FullSeed,B64.FullSeed,'RANDOM64 rejection preserves sequence state');

      // Every invalid range must raise; state must remain unchanged.
      G:=A32.FullSeed;
      H:=A64.FullSeed;
      Raised:=FALSE;
      TRY A32.RANDOM(0) EXCEPT ON ERangeError DO Raised:=TRUE END;
      Check(Raised,'RANDOM32(0) exception');
      Raised:=FALSE;
      TRY A64.RANDOM(0) EXCEPT ON ERangeError DO Raised:=TRUE END;
      Check(Raised,'RANDOM64(0) exception');
      Raised:=FALSE;
      TRY A32.RND(2,1) EXCEPT ON ERangeError DO Raised:=TRUE END;
      Check(Raised,'RND32 reversed bounds exception');
      Raised:=FALSE;
      TRY A64.RND(2,1) EXCEPT ON ERangeError DO Raised:=TRUE END;
      Check(Raised,'RND64 reversed bounds exception');
      CheckGUID(G,A32.FullSeed,'Invalid RANDOM32/RND32 preserves state');
      CheckGUID(H,A64.FullSeed,'Invalid RANDOM64/RND64 preserves state');

      Raised:=FALSE;
      TRY A32.POP EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised,'POP32 empty exception');
      Raised:=FALSE;
      TRY A64.POP EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised,'POP64 empty exception');

      // Three different stacked states, with advances between PUSHes.
      A32:=TPRNG32.Create(13579,Method);
      A64:=TPRNG64.Create(UInt64(13579),Method);
      A32.PUSH;
      A64.PUSH;
      FOR J:=1 TO 3 DO BEGIN A32.RND(0,High(UInt32)); A64.RND(0,High(UInt64)) END;
      A32.PUSH;
      A64.PUSH;
      FOR J:=1 TO 5 DO BEGIN A32.RANDOM(97); A64.RANDOM(97) END;
      A32.PUSH;
      A64.PUSH;
      FOR J:=1 TO 9 DO BEGIN A32.RND(0,High(UInt32)); A64.RND(0,High(UInt64)) END;

      B32:=A32; B64:=A64;           // Deep copy three saved states.
      C32:=B32; C64:=B64;           // Transitive copy.
      Check((B32.Method=Method) AND (C64.Method=Method),'Method copied');
      FOR I:=1 TO 3 DO BEGIN
        A32.POP; B32.POP; C32.POP;
        A64.POP; B64.POP; C64.POP;
        CheckGUID(A32.FullSeed,B32.FullSeed,'Assignment POP32 same state');
        CheckGUID(B32.FullSeed,C32.FullSeed,'Transitive POP32 same state');
        CheckGUID(A64.FullSeed,B64.FullSeed,'Assignment POP64 same state');
        CheckGUID(B64.FullSeed,C64.FullSeed,'Transitive POP64 same state');
        FOR J:=1 TO 4 DO BEGIN
          Check32(A32.RND(0,High(UInt32)),B32.RND(0,High(UInt32)),'Assignment POP32 sequence');
          Check64(A64.RND(0,High(UInt64)),B64.RND(0,High(UInt64)),'Assignment POP64 sequence')
        END
      END;
      Raised:=FALSE;
      TRY B32.POP EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised,'Copied stack32 exhausted');
      Raised:=FALSE;
      TRY B64.POP EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised,'Copied stack64 exhausted');

      // Independence: pop/clear destination stack must not alter the source stack.
      A32.PUSH; A64.PUSH;
      B32:=A32; B64:=A64;
      G:=A32.FullSeed; H:=A64.FullSeed;
      B32.POP; B64.POP;
      CheckGUID(G,A32.FullSeed,'Assignment32 independent state');
      CheckGUID(H,A64.FullSeed,'Assignment64 independent state');
      A32.POP; A64.POP;
      B32:=B32; B64:=B64;           // Self-assignment must be harmless.
      CheckGUID(G,B32.FullSeed,'Self assignment32');
      CheckGUID(H,B64.FullSeed,'Self assignment64');
      // Assign from empty-stack record, then push on the independent destination.
      C32:=TPRNG32.Create(2468,Method);
      C64:=TPRNG64.Create(2468,Method);
      B32:=C32; B64:=C64;
      Raised:=FALSE;
      TRY B32.POP EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised,'Assign32 clears old stack');
      Raised:=FALSE;
      TRY B64.POP EXCEPT ON EInvalidOpException DO Raised:=TRUE END;
      Check(Raised,'Assign64 clears old stack');
      B32.PUSH; B64.PUSH;
      B32.POP; B64.POP;
      CheckGUID(C32.FullSeed,B32.FullSeed,'Independent empty-stack32 assignment');
      CheckGUID(C64.FullSeed,B64.FullSeed,'Independent empty-stack64 assignment')
    END;

    // Parameterless/default/zero constructors must produce initialized generators.
    A32:=TPRNG32.Create;
    A64:=TPRNG64.Create;
    Check((A32.Method=SplitMix) AND (A64.Method=SplitMix),'Default method');
    A32:=TPRNG32.Create(0,PCG);
    A64:=TPRNG64.Create(PCG,0);
    Check((A32.Method=PCG) AND (A64.Method=PCG),'Zero seed PCG constructors');
    A32.RANDOMIZE;
    A64.RANDOMIZE;

    // Global generators: known SplitMix sequence and restoration of global seeds.
    S32:=RandSeed32;
    S64:=RandSeed64;
    TRY
      RANDOMIZE32(1);
      RANDOMIZE64(1);
      Check32($5E2D1772,RND32(0,High(UInt32)),'Global SplitMix32');
      Check64($910A2DEC89025CC1,RND64(0,High(UInt64)),'Global SplitMix64');
    FINALLY
      RandSeed32:=S32;
      RandSeed64:=S64
    END
  END;

END.
