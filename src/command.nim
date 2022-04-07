import std/tables, std/os, std/strutils
import flag, datatypes, alias


type
    AliasKind* = enum
        akMoveOnly,
        akProcessing

    CommandKind* = enum
        ckCommand,
        ckAlias

    CommandVariant* = ref object
        case kind*: CommandKind:
            of ckCommand:
                name*: string
                info*: string # short
                help*: string  # long
                subcommands*: Table[string, CommandVariant]
                callback*: proc (input: varargs[string, `$`]): void
                flagsShort*: Table[char, FlagVariantRef]
                flagsLong*: Table[string, FlagVariantRef]
                sharedFlagsShort*: Table[char, FlagVariantRef]  # applies to all subcommands
                sharedFlagsLong*: Table[string, FlagVariantRef]  # applies to all subcommands
            of ckAlias:
                case aliasKind*: AliasKind
                    of akMoveOnly:
                        states*: seq[AliasMoveStateVariant]
                    of akProcessing:
                        moveStates*: seq[AliasMoveStateVariant]
                        procStates*: seq[AliasProcStateVariant]
        parent*: CommandVariant

proc `$`* (com: CommandVariant): string =
        case com.kind:
            of ckCommand:
                result = com.name & com.info & com.help & $com.subcommands & $com.flagsShort & $com.flagsLong & $com.sharedFlagsShort & $com.sharedFlagsLong
            of ckAlias:
                result = "alias"

proc parse* (com: var CommandVariant, params: seq[string], root: CommandVariant, readOffset: range[0 .. high(int)] = 0): void =
    echo("parse")
    echo(len(params), params, readOffset)
    if (len(params) - readOffset) > 0:
        echo("has params")
        if params[readOffset].startsWith("-"):
            echo("flag, currently not implimented")
            discard  # flag
        else:
            echo("subcommand or input")
            echo($com.subcommands)
            echo(params[readOffset])
            if params[readOffset] in com.subcommands:
                echo("subcommand")
                var subcommand = com.subcommands[params[readOffset]]
                case subcommand.kind:
                    of ckCommand:
                        echo("command")
                        parse(subcommand, params, root, readOffset + 1)
                    of ckAlias:
                        echo("alias")
                        var alias = subcommand
                        case alias.aliasKind:
                            of akMoveOnly:
                                echo("move alias")
                                var current: CommandVariant = subcommand
                                for state in alias.states:
                                    case state.kind:
                                        of amMoveUp:
                                            echo("move up")
                                            if current != root:
                                                current = current.parent
                                        of amMoveRoot:
                                            echo("move root")
                                            current = root
                                        of amMoveDown:
                                            echo("move down to ", state.commandName)
                                            case current.kind:
                                                of ckCommand:
                                                    current = current.subcommands[state.commandName]
                                                of ckAlias:
                                                    raise newException(ValueError, "Aliases do not contain subcommands")
                                parse(current, params, root, readOffset + 1)
                            of akProcessing:
                                discard
                                # moveStates: seq[AliasMoveStateVariant]
                                # procStates: seq[AliasProcStateVariant]
            else:
                echo("input or misspelled")
    else:
        com.callback()

proc process* (com: var CommandVariant): void =
    echo("process")
    parse(com, commandLineParams(), com, 0)


proc newCommandVariant* (name: string,
                    info: string,
                    help: string,
                    callback: proc (input: varargs[string, `$`]): void
                    ): CommandVariant =
    result = CommandVariant(kind: ckCommand,
                            name: name,
                            info: info,
                            help: help,
                            subcommands: initTable[string, CommandVariant](),
                            callback: callback,
                            flagsShort: initTable[char, FlagVariantRef](),
                            flagsLong: initTable[string, FlagVariantRef](),
                            sharedFlagsShort: initTable[char, FlagVariantRef](),
                            sharedFlagsLong: initTable[string, FlagVariantRef](),
                            parent: nil
                            )

proc addSubcommand* (com: var CommandVariant,
                    name: string,
                    info: string,
                    help: string,
                    callback: proc (input: varargs[string, `$`]): void
                    ): CommandVariant =
    com.subcommands[name] = CommandVariant(kind: ckCommand,
                                            name: name,
                                            info: info,
                                            help: help,
                                            subcommands: initTable[string, CommandVariant](),
                                            callback: callback,
                                            flagsShort: initTable[char, FlagVariantRef](),
                                            flagsLong: initTable[string, FlagVariantRef](),
                                            sharedFlagsShort: initTable[char, FlagVariantRef](),
                                            sharedFlagsLong: initTable[string, FlagVariantRef](),
                                            parent: com)
    result = com.subcommands[name]

proc addAlias* (com: var CommandVariant,
                    name: string,
                    movements: string
                    ): CommandVariant =
    var movementsGenerated: seq[AliasMoveStateVariant] = @[]
    for i in movements.split(","):
        case i:
            of "root", "r", "~":
                movementsGenerated = movementsGenerated & @[AliasMoveStateVariant(kind: amMoveRoot)]
            of "parent", "up", "^":
                movementsGenerated = movementsGenerated & @[AliasMoveStateVariant(kind: amMoveUp)]
            elif len(i.replace("`", "").replace("\\", "")) > 0:
                movementsGenerated = movementsGenerated & @[AliasMoveStateVariant(kind: amMoveDown, commandName: i.replace("`", "").replace("\\", ""))]
            else:
                raise newException(ValueError, "Parsing alias string requires all segments to be at least one character in length, not" & i)
    com.subcommands[name] = CommandVariant(kind: ckALias,
                                            aliasKind: akMoveOnly,
                                            states: movementsGenerated,
                                            parent: com)
    result = com.subcommands[name]


proc recAddSharedShortFlag* (com: var CommandVariant, name: char, flag: FlagVariantRef): void =
    com.sharedFlagsShort[name] = flag
    for subc in com.subcommands.mvalues():
        recAddSharedShortFlag(subc, name, flag)

proc recAddSharedLongFlag* (com: var CommandVariant, name: string, flag: FlagVariantRef): void =
    com.sharedFlagsLong[name] = flag
    for subc in com.subcommands.mvalues():
        recAddSharedLongFlag(subc, name, flag)


proc addIntFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: int64): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addIntFlag* (com: var CommandVariant,
                    shortName: char,
                    callback: proc (val: int64): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addIntFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: int64): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addIntFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref int64,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addIntFlag* (com: var CommandVariant,
                    shortName: char,
                    reference: ref int64,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addIntFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref int64,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com


proc addFloatFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: float64): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    shortName: char,
                    callback: proc (val: float64): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: float64): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref float64,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    shortName: char,
                    reference: ref float64,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref float64,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com


proc addStringFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: string): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addStringFlag* (com: var CommandVariant,
                    shortName: char,
                    callback: proc (val: string): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addStringFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: string): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addStringFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref string,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addStringFlag* (com: var CommandVariant,
                    shortName: char,
                    reference: ref string,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addStringFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref string,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com


proc addBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: bool): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    callback: proc (val: bool): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addBoolFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: bool): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref bool,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    reference: ref bool,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addBoolFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref bool,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com


proc addFuzzyBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: FuzzyBool): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    callback: proc (val: FuzzyBool): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: FuzzyBool): void,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref FuzzyBool,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    reference: ref FuzzyBool,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref FuzzyBool,
                    shared: bool = false
                    ): CommandVariant =
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
    result = com
