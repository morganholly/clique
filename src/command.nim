import std/tables, std/os
import flag, datatypes


type
    SubCommandKind* = enum
        sckCommand,
        sckAlias

    SubCommandVariant* = object
        case kind*: SubCommandKind:
            of sckCommand: command*: CommandVariant
            of sckAlias: aliased*: string

    CommandVariant = object
        name*: string
        info*: string # short
        help*: string  # long
        subcommands*: Table[string, SubCommandVariant]
        callback*: proc (input: varargs[string, `$`]): void
        flagsShort*: Table[char, FlagVariantRef]
        flagsLong*: Table[string, FlagVariantRef]
        sharedFlagsShort*: Table[char, FlagVariantRef]  # applies to all subcommands
        sharedFlagsLong*: Table[string, FlagVariantRef]  # applies to all subcommands


proc process* (cv: var CommandVariant): void =
    echo(commandLineParams())

proc newCommandVariant* (name: string,
            info: string,
            help: string,
            callback: proc (input: varargs[string, `$`]): void
            ): CommandVariant =
    result = CommandVariant(name: name,
                            info: info,
                            help: help,
                            subcommands: initTable[string, SubCommandVariant](),
                            callback: callback,
                            flagsShort: initTable[char, FlagVariantRef](),
                            flagsLong: initTable[string, FlagVariantRef](),
                            sharedFlagsShort: initTable[char, FlagVariantRef](),
                            sharedFlagsLong: initTable[string, FlagVariantRef]()
                            )

proc addSubcommand* (cv: var CommandVariant,
                        name: string,
                        info: string,
                        help: string,
                        callback: proc (input: varargs[string, `$`]): void
                        ): void =
    cv.subcommands[name] = SubCommandVariant(kind: sckCommand, command:
        CommandVariant(name: name,
                        info: info,
                        help: help,
                        subcommands: initTable[string, SubCommandVariant](),
                        callback: callback,
                        flagsShort: initTable[char, FlagVariantRef](),
                        flagsLong: initTable[string, FlagVariantRef](),
                        sharedFlagsShort: initTable[char, FlagVariantRef](),
                        sharedFlagsLong: initTable[string, FlagVariantRef]()
                        ))

proc addIntFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    callback: proc (val: int64): void,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faCallback,
                                        callbackInt: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faCallback,
                                        callbackInt: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faCallback,
                                        callbackInt: callback)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addIntFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    reference: ref int64,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faRef,
                                        refInt: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faRef,
                                        refInt: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faRef,
                                        refInt: reference)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addFloatFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    callback: proc (val: float64): void,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faCallback,
                                        callbackFloat: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faCallback,
                                        callbackFloat: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faCallback,
                                        callbackFloat: callback)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addFloatFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    reference: ref float64,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faRef,
                                        refFloat: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faRef,
                                        refFloat: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faRef,
                                        refFloat: reference)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addStringFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    callback: proc (val: string): void,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faCallback,
                                        callbackString: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faCallback,
                                        callbackString: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faCallback,
                                        callbackString: callback)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addStringFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    reference: ref string,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faRef,
                                        refString: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faRef,
                                        refString: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faRef,
                                        refString: reference)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addBoolFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    callback: proc (val: bool): void,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faCallback,
                                        callbackBool: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faCallback,
                                        callbackBool: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faCallback,
                                        callbackBool: callback)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addBoolFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    reference: ref bool,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faRef,
                                        refBool: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faRef,
                                        refBool: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faRef,
                                        refBool: reference)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addFuzzyBoolFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    callback: proc (val: FuzzyBool): void,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faCallback,
                                        callbackFuzzyBool: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faCallback,
                                        callbackFuzzyBool: callback)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faCallback,
                                        callbackFuzzyBool: callback)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addFuzzyBoolFlag* (cv: var CommandVariant,
                    shortName: char = '\0',
                    longName: string = "",
                    reference: ref FuzzyBool,
                    shared: bool
                    ): void =
    if (shortName != '\0') or (longName != ""):
        if (shortName != '\0') and (longName != ""):
            var flag = FlagVariantRef(kind: fkShortAndLong,
                                        shortName: shortName,
                                        longName: longName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faRef,
                                        refFuzzyBool: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsShort[shortName] = flag
                cv.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faRef,
                                        refFuzzyBool: reference)
            if shared:
                cv.sharedFlagsShort[shortName] = flag
            else:
                cv.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faRef,
                                        refFuzzyBool: reference)
            if shared:
                cv.sharedFlagsLong[longName] = flag
            else:
                cv.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")
