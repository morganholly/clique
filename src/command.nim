import std/tables, std/os
import flag, datatypes


type
    SubCommandKind* = enum
        sckCommand,
        sckAlias  # maybe a seq of commands to either move to a parent command, do a name lookup, return to the root node, set a flag, run a proc on a flag value, run a proc on an input

    SubCommand* = object
        case kind*: SubCommandKind:
            of sckCommand: command*: Command
            of sckAlias: aliased*: string

    Command* = object
        name*: string
        info*: string # short
        help*: string  # long
        subcommands*: Table[string, SubCommand]
        callback*: proc (input: varargs[string, `$`]): void
        flagsShort*: Table[char, FlagVariantRef]
        flagsLong*: Table[string, FlagVariantRef]
        sharedFlagsShort*: Table[char, FlagVariantRef]  # applies to all subcommands
        sharedFlagsLong*: Table[string, FlagVariantRef]  # applies to all subcommands


proc process* (com: var Command): void =
    echo(commandLineParams())

proc newCommand* (name: string,
                    info: string,
                    help: string,
                    callback: proc (input: varargs[string, `$`]): void
                    ): Command =
    result = Command(name: name,
                    info: info,
                    help: help,
                    subcommands: initTable[string, SubCommand](),
                    callback: callback,
                    flagsShort: initTable[char, FlagVariantRef](),
                    flagsLong: initTable[string, FlagVariantRef](),
                    sharedFlagsShort: initTable[char, FlagVariantRef](),
                    sharedFlagsLong: initTable[string, FlagVariantRef]()
                    )

proc addSubcommand* (com: var Command,
                    name: string,
                    info: string,
                    help: string,
                    callback: proc (input: varargs[string, `$`]): void
                    ): void =
    com.subcommands[name] = SubCommand(kind: sckCommand, command:
        Command(name: name,
                info: info,
                help: help,
                subcommands: initTable[string, SubCommand](),
                callback: callback,
                flagsShort: initTable[char, FlagVariantRef](),
                flagsLong: initTable[string, FlagVariantRef](),
                sharedFlagsShort: initTable[char, FlagVariantRef](),
                sharedFlagsLong: initTable[string, FlagVariantRef]()
                ))

proc addIntFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faCallback,
                                        callbackInt: callback)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faCallback,
                                        callbackInt: callback)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addIntFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faRef,
                                        refInt: reference)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itInt,
                                        valInt: 0,
                                        actionInt: faRef,
                                        refInt: reference)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addFloatFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faCallback,
                                        callbackFloat: callback)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faCallback,
                                        callbackFloat: callback)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addFloatFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faRef,
                                        refFloat: reference)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFloat,
                                        valFloat: 0.0,
                                        actionFloat: faRef,
                                        refFloat: reference)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addStringFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faCallback,
                                        callbackString: callback)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faCallback,
                                        callbackString: callback)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addStringFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faRef,
                                        refString: reference)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itString,
                                        valString: "",
                                        actionString: faRef,
                                        refString: reference)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addBoolFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faCallback,
                                        callbackBool: callback)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faCallback,
                                        callbackBool: callback)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addBoolFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faRef,
                                        refBool: reference)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itBool,
                                        valBool: false,
                                        actionBool: faRef,
                                        refBool: reference)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")


proc addFuzzyBoolFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faCallback,
                                        callbackFuzzyBool: callback)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faCallback,
                                        callbackFuzzyBool: callback)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")

proc addFuzzyBoolFlag* (com: var Command,
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
                com.sharedFlagsShort[shortName] = flag
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsShort[shortName] = flag
                com.flagsLong[longName] = flag
        elif (shortName != '\0'):
            var flag = FlagVariantRef(kind: fkShortOnly,
                                        chr: shortName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faRef,
                                        refFuzzyBool: reference)
            if shared:
                com.sharedFlagsShort[shortName] = flag
            else:
                com.flagsShort[shortName] = flag
        else:
            var flag = FlagVariantRef(kind: fkLongOnly,
                                        name: longName,
                                        datatype: itFuzzyBool,
                                        valFuzzyBool: fbUncertain,
                                        actionFuzzyBool: faRef,
                                        refFuzzyBool: reference)
            if shared:
                com.sharedFlagsLong[longName] = flag
            else:
                com.flagsLong[longName] = flag
    else:
        raise newException(ValueError, "Creation of a flag requires at least one name")
