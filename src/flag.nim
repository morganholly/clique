import datatypes


type
    FlagKind* = enum
        fkShortOnly,
        fkLongOnly,
        fkShortAndLong

    FlagAction* = enum
        faCallback,
        faRef

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
