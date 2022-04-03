import std/strutils


type
    FuzzyBool* = enum
        fbTrue, fbFalse, fbUncertain

    InputType* = enum
        itInt,
        itFloat,
        itString,
        itBool,
        itFuzzyBool

proc parseFuzzyBool* (s: string): FuzzyBool =
    let s2 = s.strip()
    if s2.startsWith("t") or s2.startsWith("y"):
        result = fbTrue
    elif s2.startsWith("f") or s2.startsWith("n"):
        result = fbFalse
    else:
        result = fbUncertain