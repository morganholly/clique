import std/tables, std/os
import flag, datatypes, command


type
    AliasMoveStateKind* = enum
        amMoveUp,
        amMoveRoot,
        amMoveDown

    AliasMoveStateVariant* = object
        case kind: AliasMoveStateKind
            of amMoveUp, amMoveRoot:
                discard
            of amMoveDown:
                commandName: string

    AliasProcStateKind* = enum
        apSetCharFlag,
        apSetStringFlag,
        apProcInput,
        apProcInputs

    AliasProcStateVariant* = object
        case kind: AliasProcStateKind
            of apSetCharFlag:
                chr: char
                case charFlagType: InputType
                    of itInt:
                        newValProc_char_int: proc (input: int64): int64
                    of itFloat:
                        newValProc_char_float: proc (input: float64): float64
                    of itString:
                        newValProc_char_string: proc (input: string): string
                    of itBool:
                        newValProc_char_bool: proc (input: bool): bool
                    of itFuzzyBool:
                        newValProc_char_FuzzyBool: proc (input: FuzzyBool): FuzzyBool
            of apSetStringFlag:
                name: string
                case stringFlagType: InputType
                    of itInt:
                        newValProc_string_int: proc (input: int64): int64
                    of itFloat:
                        newValProc_string_float: proc (input: float64): float64
                    of itString:
                        newValProc_string_string: proc (input: string): string
                    of itBool:
                        newValProc_string_bool: proc (input: bool): bool
                    of itFuzzyBool:
                        newValProc_string_FuzzyBool: proc (input: FuzzyBool): FuzzyBool
            of apProcInput:
                inputIndex: int
                newValProcInput: proc (input: string): string
            of apProcInputs:
                newValProcInputs: proc (input: seq[string]): seq[string]

    AliasKind* = enum
        akMoveOnly,
        akProcessing

    AliasVariant* = object
        case kind: AliasKind
            of akMoveOnly:
                states: seq[AliasMoveStateVariant]
            of akProcessing:
                moveStates: seq[AliasMoveStateVariant]
                procStates: seq[AliasProcStateVariant]