import datatypes
import std/strutils


type
    FlagKind* = enum
        fkShortOnly,
        fkLongOnly,
        fkShortAndLong

    FlagAction* = enum
        faCallback,
        faRef

    FlagVariantRef* = ref FlagVariant
    FlagVariant* = object
        case kind*: FlagKind:
            of fkShortOnly: chr*: char
            of fkLongOnly: name*: string
            of fkShortAndLong:
                shortName*: char
                longName*: string
        case datatype*: InputType:
            of itInt:
                valInt*: int64
                case actionInt*: FlagAction:
                    of faCallback: callbackInt*: proc (val: int64): void
                    of faRef: refInt*: ref int64
            of itFloat:
                valFloat*: float64
                case actionFloat*: FlagAction:
                    of faCallback: callbackFloat*: proc (val: float64): void
                    of faRef: refFloat*: ref float64
            of itString:
                valString*: string
                case actionString*: FlagAction:
                    of faCallback: callbackString*: proc (val: string): void
                    of faRef: refString*: ref string
            of itBool:  # false by default
                valBool*: bool
                case actionBool*: FlagAction:
                    of faCallback: callbackBool*: proc (val: bool): void
                    of faRef: refBool*: ref bool
            of itFuzzyBool:  # fbUncertain by default
                valFuzzyBool*: FuzzyBool
                case actionFuzzyBool*: FlagAction:
                    of faCallback: callbackFuzzyBool*: proc (val: FuzzyBool): void
                    of faRef: refFuzzyBool*: ref FuzzyBool
        help*: string  # long
        info*: string # short

proc `$`* (fv: FlagVariantRef): string =
        case fv.kind:
            of fkShortOnly: result = result & $fv.chr
            of fkLongOnly: result = result & fv.name
            of fkShortAndLong:
                result = result & $fv.chr & $fv.longName
        case fv.datatype:
            of itInt:
                result = result & $fv.valInt
                case fv.actionInt:
                    of faCallback: result = result & "callbackInt"
                    of faRef: result = result & "refInt"
            of itFloat:
                result = result & $fv.valFloat
                case fv.actionFloat:
                    of faCallback: result = result & "callbackFloat"
                    of faRef: result = result & "refFloat"
            of itString:
                result = result & $fv.valString
                case fv.actionString:
                    of faCallback: result = result & "callbackString"
                    of faRef: result = result & "refString"
            of itBool:  # false by default
                result = result & $fv.valBool
                case fv.actionBool:
                    of faCallback: result = result & "callbackBool"
                    of faRef: result = result & "refBool"
            of itFuzzyBool:  # fbUncertain by default
                result = result & $fv.valFuzzyBool
                case fv.actionFuzzyBool:
                    of faCallback: result = result & "callbackFuzzyBool"
                    of faRef: result = result & "refFuzzyBool"
        result = result & fv.help
        result = result & fv.info


proc action* (fv: var FlagVariant): void =
    case fv.datatype:
        of itInt:
            case fv.actionInt:
                of faCallback: fv.callbackInt(fv.valInt)
                of faRef: fv.refInt[] = fv.valInt
        of itFloat:
            case fv.actionFloat:
                of faCallback: fv.callbackFloat(fv.valFloat)
                of faRef: fv.refFloat[] = fv.valFloat
        of itString:
            case fv.actionString:
                of faCallback: fv.callbackString(fv.valString)
                of faRef: fv.refString[] = fv.valString
        of itBool:
            case fv.actionBool:
                of faCallback: fv.callbackBool(fv.valBool)
                of faRef: fv.refBool[] = fv.valBool
        of itFuzzyBool:
            case fv.actionFuzzyBool:
                of faCallback: fv.callbackFuzzyBool(fv.valFuzzyBool)
                of faRef: fv.refFuzzyBool[] = fv.valFuzzyBool

proc action*[T] (fv: var FlagVariant, value: T): void =
    case fv.datatype:
        of itInt:
            case fv.actionInt:
                of faCallback: fv.callbackInt(value)
                of faRef: fv.refInt[] = value
        of itFloat:
            case fv.actionFloat:
                of faCallback: fv.callbackFloat(value)
                of faRef: fv.refFloat[] = value
        of itString:
            case fv.actionString:
                of faCallback: fv.callbackString(value)
                of faRef: fv.refString[] = value
        of itBool:
            case fv.actionBool:
                of faCallback: fv.callbackBool(value)
                of faRef: fv.refBool[] = value
        of itFuzzyBool:
            case fv.actionFuzzyBool:
                of faCallback: fv.callbackFuzzyBool(value)
                of faRef: fv.refFuzzyBool[] = value

proc action* (fv: var FlagVariant, value: string): void =
    case fv.datatype:
        of itInt:
            case fv.actionInt:
                of faCallback: fv.callbackInt(parseInt(value))
                of faRef: fv.refInt[] = parseInt(value)
        of itFloat:
            case fv.actionFloat:
                of faCallback: fv.callbackFloat(parseFloat(value))
                of faRef: fv.refFloat[] = parseFloat(value)
        of itString:
            case fv.actionString:
                of faCallback: fv.callbackString(value)
                of faRef: fv.refString[] = value
        of itBool:
            case fv.actionBool:
                of faCallback: fv.callbackBool(parseBool(value))
                of faRef: fv.refBool[] = parseBool(value)
        of itFuzzyBool:
            case fv.actionFuzzyBool:
                of faCallback: fv.callbackFuzzyBool(parseFuzzyBool(value))
                of faRef: fv.refFuzzyBool[] = parseFuzzyBool(value)

proc setValue*[T] (fv: var FlagVariant, value: T): void =
    case fv.datatype:
        of itInt:
            fv.valInt = value
        of itFloat:
            fv.valFloat = value
        of itString:
            fv.valString = value
        of itBool:
            fv.valBool = value
        of itFuzzyBool:
            fv.valFuzzyBool = value

proc setValue* (fv: var FlagVariant, value: string): void =
    case fv.datatype:
        of itInt:
            fv.valInt = parseInt(value)
        of itFloat:
            fv.valFloat = parseFloat(value)
        of itString:
            fv.valString = value
        of itBool:
            fv.valBool = parseBool(value)
        of itFuzzyBool:
            fv.valFuzzyBool = parseFuzzyBool(value)