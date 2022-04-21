import std/tables, std/os, std/strutils, std/macros, std/enumerate, std/algorithm, std/sequtils
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
            result = com.name & " " & com.info & " " & com.help & "\n" & $com.subcommands & "\nfs " & $com.flagsShort & "\nfl " & $com.flagsLong & "\nsfs " & $com.sharedFlagsShort & "\nsfl " & $com.sharedFlagsLong
        of ckAlias:
            result = "alias"

proc parse* (com: var CommandVariant, params: seq[string], root: CommandVariant, readOffset: range[0 .. high(int)] = 0): void =
    echo("parse")
    echo(len(params), params, readOffset)
    if (len(params) - readOffset) > 0:
        echo("has params")
        var value = params[readOffset]
        if value.startsWith("--"):
            echo("long flag")
            var vnodash = value.replace("-", "")
            if vnodash in com.flagsLong:
                echo("command has flag")
                if com.flagsLong[vnodash].datatype != itBool:
                    if (len(params) - readOffset) > 1 and not params[readOffset + 1].startsWith("-"):
                        com.flagsLong[vnodash].action(params[readOffset + 1])
                        parse(com, params, root, readOffset + 2)
                    else:
                        case com.flagsLong[vnodash].hasNoInputAction:
                            of nikHasNoInputAction:
                                com.flagsLong[vnodash].actionNoInput()
                                parse(com, params, root, readOffset + 1)
                            of nikRequiresInput:
                                raise newException(ValueError, "Missing value for flag")
                else:
                    com.flagsLong[vnodash].action("")
                    parse(com, params, root, readOffset + 1)
            else:
                echo("recurse up")
                var current: CommandVariant = com.parent
                while current != root:
                    if vnodash in current.sharedFlagsLong:
                        if current.sharedFlagsLong[vnodash].datatype != itBool:
                            if (len(params) - readOffset) > 1 and not params[readOffset + 1].startsWith("-"):
                                current.sharedFlagsLong[vnodash].action(params[readOffset + 1])
                                parse(current, params, root, readOffset + 2)
                            else:
                                case com.sharedFlagsLong[vnodash].hasNoInputAction:
                                    of nikHasNoInputAction:
                                        com.sharedFlagsLong[vnodash].actionNoInput()
                                        parse(com, params, root, readOffset + 1)
                                    of nikRequiresInput:
                                        raise newException(ValueError, "Missing value for flag")
                        else:
                            current.sharedFlagsLong[vnodash].action("")
                            parse(current, params, root, readOffset + 1)
                        break
                    else:
                        echo(current.parent.name)
                        current = current.parent
        elif value.startsWith("-"):
            echo("short flag")
            var offsetFromValue: int = 0
            for c in value.replace("-", ""):
                # TODO finish below code, should handle -a, -a val, -abc, -abc val for any combination of types
                if c in com.flagsShort:
                    echo("not shared flag")
                    if com.flagsShort[c].datatype != itBool:
                        if (len(params) - readOffset) > 1 and not params[readOffset + 1].startsWith("-"):
                            echo("has value")
                            com.flagsShort[c].action(params[readOffset + 1])
                            offsetFromValue = 2
                        else:
                            echo("no input, notbool")
                            case com.flagsShort[c].hasNoInputAction:
                                of nikHasNoInputAction:
                                    com.flagsShort[c].actionNoInput()
                                    if offsetFromValue < 2:
                                        offsetFromValue = 1
                                of nikRequiresInput:
                                    raise newException(ValueError, "Missing value for flag")
                    else:
                        echo("no input, bool")
                        com.flagsShort[c].action("")
                        if offsetFromValue < 2:
                            offsetFromValue = 1
                else:
                    echo("shared flag")
                    var current: CommandVariant = com.parent
                    while current != root:
                        echo("step")
                        if c in current.sharedFlagsShort:
                            echo("found shared flag")
                            if com.sharedFlagsShort[c].datatype != itBool:
                                if (len(params) - readOffset) > 1 and not params[readOffset + 1].startsWith("-"):
                                    com.sharedFlagsShort[c].action(params[readOffset + 1])
                                    offsetFromValue = 2
                                else:
                                    case com.sharedFlagsShort[c].hasNoInputAction:
                                        of nikHasNoInputAction:
                                            com.sharedFlagsShort[c].actionNoInput()
                                            if offsetFromValue < 2:
                                                offsetFromValue = 1
                                        of nikRequiresInput:
                                            raise newException(ValueError, "Missing value for flag")
                            else:
                                com.sharedFlagsShort[c].action("")
                                if offsetFromValue < 2:
                                    offsetFromValue = 1
                            break
                        else:
                            echo("recurse up")
                            current = current.parent
                    if current == root:
                        if c in current.sharedFlagsShort:
                            echo("found shared flag on root")
                            if com.sharedFlagsShort[c].datatype != itBool:
                                if (len(params) - readOffset) > 1 and not params[readOffset + 1].startsWith("-"):
                                    com.sharedFlagsShort[c].action(params[readOffset + 1])
                                    offsetFromValue = 2
                                else:
                                    case com.sharedFlagsShort[c].hasNoInputAction:
                                        of nikHasNoInputAction:
                                            com.sharedFlagsShort[c].actionNoInput()
                                            if offsetFromValue < 2:
                                                offsetFromValue = 1
                                        of nikRequiresInput:
                                            raise newException(ValueError, "Missing value for flag")
                            else:
                                com.sharedFlagsShort[c].action("")
                                if offsetFromValue < 2:
                                    offsetFromValue = 1
                            break
                        else:
                            raise newException(ValueError, "Flag " & $c & " not found in current command and all parent commands")
            parse(com, params, root, readOffset + offsetFromValue)
        else:
            echo("subcommand or input")
            echo($com)
            echo(value)
            if value in com.subcommands:
                echo("subcommand")
                var subcommand = com.subcommands[value]
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
    # TODO restructure to remove recursion
    # echo("process")
    # var clparams: seq[string] = commandLineParams()
    # if len(clparams) > 0:
    #     var revparams: seq[string] = clparams.reversed()
    #     echo(revparams)
    #     var toggleRev: seq[bool] = @[]
    #     for i in 0 .. len(revparams) - 2:
    #         toggleRev &= @[revparams[i].startswith("-") or (revparams[i + 1].startswith("-") and not (revparams[i + 1].endswith("%") or revparams[i + 1].endswith("^")))]
    #         echo(toggleRev)
    #     toggleRev &= @[clparams[0].startswith("-")]
    #     var toggle: seq[bool] = toggleRev.reversed()
    #     echo(toggle)
    #     var flags: seq[string] = @[]
    #     var remainder: seq[string] = @[]
    #     for z in zip(clparams, toggle):
    #         if z[1]:
    #             flags &= @[z[0]]
    #         else:
    #             remainder &= @[z[0]]
    #     echo(remainder)
    #     echo(flags)
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
                raise newException(ValueError, "Parsing alias string requires all segments to be at least one character in length, not " & i)
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


type
    FlagCallbacks* = (proc (val: int64): void) or
                    (proc (val: float64): void) or
                    (proc (val: string): void) or
                    (proc (val: bool): void) or
                    (proc (val: FuzzyBool): void)
    FlagRefs* = ref int64 or
                ref float64 or
                ref string or
                ref bool or
                ref FuzzyBool
    FlagActions* = FlagCallbacks or FlagRefs
    FlagTypes* = int64 or
                float64 or
                string or
                bool or
                FuzzyBool


proc typeSplit* (repr: string): seq[string] =
    result = newSeq[string](1)
    var scope: int = 0
    var select: int = 0
    for c in repr:
        case c:
            of ',':
                if scope == 0:
                    select = select + 1
                    result.add("")
                else:
                    result[select] = result[select] & ","
            of '[':
                result[select] = result[select] & "["
                scope = scope + 1
            of ']':
                result[select] = result[select] & "]"
                scope = scope - 1
            of ' ':
                if scope == 0:
                    discard
                else:
                    result[select] = result[select] & " "
            else:
                result[select] = result[select] & $c

# macro addFlags* (com: var CommandVariant, flags: varargs[typed]): untyped =
#     # result = nnkStmtList.newTree()
#     echo(flags.treeRepr())
#     for i, f in enumerate(flags):
#         echo(f.repr())
#         # echo(astGenRepr(f))
#         # for i in f[1]:
#         #     echo(i.kind)
#         # echo(owner(f[2]))
#         # echo(symKind(f[2]).repr())
#         # echo(getImpl(f[2]).repr())
#         # echo(owner(f[3]))
#         # echo(symKind(f[3]).repr())
#         # echo(getImpl(f[3]).repr())
#         var fTypeRepr: string = getType(f).repr()
#         echo(fTypeRepr)
#         if fTypeRepr.startswith("tuple"):
#             var fv: seq[string] = typeSplit(fTypeRepr[6..len(fTypeRepr)-2].multiReplace(("\r", ""), ("\n", ""), ("\r\n", ""), ("\f", ""), ("\v", "")))
#             echo(fv)
#             var shortName: char = '\0'
#             var longName: string = ""
#             var nameKind: FlagKind
#             var offset: int = 0
#             if fv[0] == "char" and fv[1] == "string":
#                 echo(f[0].kind)
#                 shortName = chr(intVal(f[0]))
#                 longName = strVal(f[1])
#                 nameKind = fkShortAndLong
#                 offset = 2
#             elif fv[0] == "string" and fv[1] == "char":
#                 longName = strVal(f[0])
#                 shortName = chr(intVal(f[1]))
#                 nameKind = fkShortAndLong
#                 offset = 2
#             elif fv[0] == "char":
#                 shortName = chr(intVal(f[0]))
#                 nameKind = fkShortOnly
#                 offset = 1
#             elif fv[0] == "string":
#                 longName = strVal(f[0])
#                 nameKind = fkLongOnly
#                 offset = 1
#             else:
#                 raise newException(ValueError, "Flag " & $i & " requires at least one name")
#             echo(shortName, " ", longName)
#             var shared: bool = false
#             if fv[offset] == "bool":
#                 shared = boolVal(f[offset])
#             echo(shared)
#             var datatype: InputType
#             var actionType: FlagAction
#             var hasNoInputAction: NoInputKind
#             if fv[offset+1].startswith("proc[void, "):
#                 hasNoInputAction = nikRequiresInput
#                 actionType = faCallback
#                 if fv[offset+1] == "proc[void, int64]":
#                     datatype = itInt
#                 elif fv[offset+1] == "proc[void, float64]":
#                     datatype = itFloat
#                 elif fv[offset+1] == "proc[void, string]":
#                     datatype = itString
#                 elif fv[offset+1] == "proc[void, bool]":
#                     datatype = itBool
#                 elif fv[offset+1] == "proc[void, FuzzyBool]":
#                     datatype = itFuzzyBool
#                 else:
#                     raise newException(ValueError, "Flag " & $i & " action is of invalid type. flag action is " & getType(f).repr() & " inst: " & getTypeInst(f).repr() & " impl: " & getTypeImpl(f).repr())
#                 if fv[offset+2] == "proc[void, bool]":
#                     discard
#             elif fv[offset+1].startswith("ref["):
#                 hasNoInputAction = nikRequiresInput
#                 actionType = faRef
#                 if fv[offset+1] == "ref[int64]":
#                     datatype = itInt
#                 elif fv[offset+1] == "ref[float64]":
#                     datatype = itFloat
#                 elif fv[offset+1] == "ref[string]":
#                     datatype = itString
#                 elif fv[offset+1] == "ref[bool]":
#                     datatype = itBool
#                 elif fv[offset+1] == "ref[FuzzyBool]":
#                     datatype = itFuzzyBool
#                 else:
#                     raise newException(ValueError, "Flag " & $i & " action is of invalid type. flag action is " & getType(f).repr() & " inst: " & getTypeInst(f).repr() & " impl: " & getTypeImpl(f).repr())
#                 if fv[offset+2] == "ref[bool]":
#                     discard
#             else:
#                 raise newException(ValueError, "Flag " & $i & " action is of invalid type. flag action is " & getType(f).repr() & " inst: " & getTypeInst(f).repr() & " impl: " & getTypeImpl(f).repr())
#         else:
#             raise newException(ValueError, "Flag " & $i & " in sequence must be a tuple. flag is " & getType(f).repr() & " inst: " & getTypeInst(f).repr() & " impl: " & getTypeImpl(f).repr())

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            shortName: char,
            callback: proc (val: T): void,
            callbackNoInput: proc (val: bool): void,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag(shortName, "", callback, callbackNoInput, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            longName: string,
            callback: proc (val: T): void,
            callbackNoInput: proc (val: bool): void,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag('\0', longName, callback, callbackNoInput, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            shortName: char,
            callback: proc (val: T): void,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag(shortName, "", callback, nil, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            longName: string,
            callback: proc (val: T): void,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag('\0', longName, callback, nil, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            shortName: char = '\0',
            longName: string = "",
            callback: proc (val: T): void,
            callbackNoInput: proc (val: bool): void = nil,
            shared: bool = false
            ): var CommandVariant =
    var flag: FlagVariantRef
    if callbackNoInput == nil:
        when T is int64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itInt, valInt: 0,
                                actionInt: faCallback, callbackInt: callback,
                                hasNoInputAction: nikRequiresInput)
        elif T is float64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFloat, valFloat: 0.0,
                                actionFloat: faCallback, callbackFloat: callback,
                                hasNoInputAction: nikRequiresInput)
        elif T is string:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itString, valString: "",
                                actionString: faCallback, callbackString: callback,
                                hasNoInputAction: nikRequiresInput)
        elif T is bool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itBool, valBool: false,
                                actionBool: faCallback, callbackBool: callback,
                                hasNoInputAction: nikRequiresInput)
        elif T is FuzzyBool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFuzzyBool, valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback, callbackFuzzyBool: callback,
                                hasNoInputAction: nikRequiresInput)
        else:
            raise newException(ValueError, "Creation of a flag requires a reference of type int64, float64, string, bool, or FuzzyBool")
    else:
        when T is int64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itInt, valInt: 0,
                                actionInt: faCallback, callbackInt: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
        elif T is float64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFloat, valFloat: 0.0,
                                actionFloat: faCallback, callbackFloat: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
        elif T is string:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itString, valString: "",
                                actionString: faCallback, callbackString: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
        elif T is bool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itBool, valBool: false,
                                actionBool: faCallback, callbackBool: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itBool)
        elif T is FuzzyBool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFuzzyBool, valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback, callbackFuzzyBool: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
        else:
            raise newException(ValueError, "Creation of a flag requires a reference of type int64, float64, string, bool, or FuzzyBool")
    if shared:
        if (shortName != '\0') and (longName != ""):
            com.sharedFlagsShort[shortName] = flag
            com.sharedFlagsLong[longName] = flag
        elif shortName != '\0':
            com.sharedFlagsShort[shortName] = flag
        elif longName != "":
            com.sharedFlagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    else:
        if (shortName != '\0') and (longName != ""):
            com.flagsShort[shortName] = flag
            com.flagsLong[longName] = flag
        elif shortName != '\0':
            com.flagsShort[shortName] = flag
        elif longName != "":
            com.flagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    result = com


proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            shortName: char,
            reference: ref T,
            refNoInput: ref bool,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag(shortName, "", reference, refNoInput, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            longName: string,
            reference: ref T,
            refNoInput: ref bool,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag('\0', longName, reference, refNoInput, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            shortName: char,
            reference: ref T,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag(shortName, "", reference, nil, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            longName: string,
            reference: ref T,
            shared: bool = false
            ): var CommandVariant =
    return com.addFlag('\0', longName, reference, nil, shared)

proc addFlag*[T: FlagTypes] (com: var CommandVariant,
            shortName: char = '\0',
            longName: string = "",
            reference: ref T,
            refNoInput: ref bool = nil,
            shared: bool = false
            ): var CommandVariant =
    var flag: FlagVariantRef
    if refNoInput == nil:
        when T is int64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itInt, valInt: 0,
                                actionInt: faRef, refInt: reference,
                                hasNoInputAction: nikRequiresInput)
        elif T is float64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFloat, valFloat: 0.0,
                                actionFloat: faRef, refFloat: reference,
                                hasNoInputAction: nikRequiresInput)
        elif T is string:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itString, valString: "",
                                actionString: faRef, refString: reference,
                                hasNoInputAction: nikRequiresInput)
        elif T is bool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itBool, valBool: false,
                                actionBool: faRef, refBool: reference,
                                hasNoInputAction: nikRequiresInput)
        elif T is FuzzyBool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFuzzyBool, valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef, refFuzzyBool: reference,
                                hasNoInputAction: nikRequiresInput)
        else:
            raise newException(ValueError, "Creation of a flag requires a reference of type int64, float64, string, bool, or FuzzyBool")
    else:
        when T is int64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itInt, valInt: 0,
                                actionInt: faRef, refInt: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
        elif T is float64:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFloat, valFloat: 0.0,
                                actionFloat: faRef, refFloat: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
        elif T is string:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itString, valString: "",
                                actionString: faRef, refString: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
        elif T is bool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itBool, valBool: false,
                                actionBool: faRef, refBool: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itBool)
        elif T is FuzzyBool:
            flag = FlagVariantRef(kind: fkShortAndLong, shortName: shortName, longName: longName,
                                datatype: itFuzzyBool, valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef, refFuzzyBool: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
        else:
            raise newException(ValueError, "Creation of a flag requires a reference of type int64, float64, string, bool, or FuzzyBool")
    if shared:
        if (shortName != '\0') and (longName != ""):
            com.sharedFlagsShort[shortName] = flag
            com.sharedFlagsLong[longName] = flag
        elif shortName != '\0':
            com.sharedFlagsShort[shortName] = flag
        elif longName != "":
            com.sharedFlagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    else:
        if (shortName != '\0') and (longName != ""):
            com.flagsShort[shortName] = flag
            com.flagsLong[longName] = flag
        elif shortName != '\0':
            com.flagsShort[shortName] = flag
        elif longName != "":
            com.flagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    result = com


proc addIntFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: int64): void,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faCallback,
                                callbackInt: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faCallback,
                                callbackInt: callback,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addIntFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: int64): void,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faCallback,
                                callbackInt: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faRef,
                                refInt: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faRef,
                                refInt: reference,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addIntFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref int64,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faRef,
                                refInt: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faCallback,
                                callbackFloat: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faCallback,
                                callbackFloat: callback,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: float64): void,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faCallback,
                                callbackFloat: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faRef,
                                refFloat: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faRef,
                                refFloat: reference,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref float64,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faRef,
                                refFloat: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faCallback,
                                callbackString: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itString,
                                valString: "",
                                actionString: faCallback,
                                callbackString: callback,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addStringFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: string): void,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faCallback,
                                callbackString: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faRef,
                                refString: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itString,
                                valString: "",
                                actionString: faRef,
                                refString: reference,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addStringFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref string,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faRef,
                                refString: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itBool,
                                valBool: false,
                                actionBool: faCallback,
                                callbackBool: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itBool,
                                valBool: false,
                                actionBool: faCallback,
                                callbackBool: callback,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addBoolFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: bool): void,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itBool,
                                valBool: false,
                                actionBool: faCallback,
                                callbackBool: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itBool,
                                valBool: false,
                                actionBool: faRef,
                                refBool: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itBool,
                                valBool: false,
                                actionBool: faRef,
                                refBool: reference,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addBoolFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref bool,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itBool,
                                valBool: false,
                                actionBool: faRef,
                                refBool: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback,
                                callbackFuzzyBool: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback,
                                callbackFuzzyBool: callback,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: FuzzyBool): void,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback,
                                callbackFuzzyBool: callback,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef,
                                refFuzzyBool: reference,
                                hasNoInputAction: nikRequiresInput)
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
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef,
                                refFuzzyBool: reference,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref FuzzyBool,
                    shared: bool = false
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef,
                                refFuzzyBool: reference,
                                hasNoInputAction: nikRequiresInput)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com


proc addIntFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: int64): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faCallback,
                                callbackInt: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
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
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faCallback,
                                callbackInt: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addIntFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: int64): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faCallback,
                                callbackInt: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com

proc addIntFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref int64,
                    shared: bool = false,
                    refNoInput: ref bool
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faRef,
                                refInt: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: true,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
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
                    shared: bool = false,
                    refNoInput: ref bool
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faRef,
                                refInt: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: true,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addIntFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref int64,
                    shared: bool = false,
                    refNoInput: ref bool
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itInt,
                                valInt: 0,
                                actionInt: faRef,
                                refInt: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itInt,
                                noInputBool: true,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com


proc addFloatFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: float64): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faCallback,
                                callbackFloat: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
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
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faCallback,
                                callbackFloat: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: float64): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faCallback,
                                callbackFloat: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref float64,
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faRef,
                                refFloat: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
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
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faRef,
                                refFloat: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFloatFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref float64,
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFloat,
                                valFloat: 0.0,
                                actionFloat: faRef,
                                refFloat: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFloat,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com


proc addStringFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: string): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faCallback,
                                callbackString: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
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
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itString,
                                valString: "",
                                actionString: faCallback,
                                callbackString: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addStringFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: string): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faCallback,
                                callbackString: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com

proc addStringFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref string,
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faRef,
                                refString: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
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
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itString,
                                valString: "",
                                actionString: faRef,
                                refString: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addStringFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref string,
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itString,
                                valString: "",
                                actionString: faRef,
                                refString: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itString,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com


proc addFuzzyBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    callback: proc (val: FuzzyBool): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback,
                                callbackFuzzyBool: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput,)
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
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback,
                                callbackFuzzyBool: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput,)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    longName: string,
                    callback: proc (val: FuzzyBool): void,
                    shared: bool = false,
                    callbackNoInput: proc (val: bool): void
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faCallback,
                                callbackFuzzyBool: callback,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faCallback,
                                callbackNoInput: callbackNoInput,)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    shortName: char,
                    longName: string,
                    reference: ref FuzzyBool,
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortAndLong,
                                shortName: shortName,
                                longName: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef,
                                refFuzzyBool: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput,)
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
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkShortOnly,
                                letter: shortName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef,
                                refFuzzyBool: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput,)
    if shared:
        com.sharedFlagsShort[shortName] = flag
    else:
        com.flagsShort[shortName] = flag
    result = com

proc addFuzzyBoolFlag* (com: var CommandVariant,
                    longName: string,
                    reference: ref FuzzyBool,
                    shared: bool = false,
                    refNoInput: ref bool,
                    ): var CommandVariant =
    var flag = FlagVariantRef(kind: fkLongOnly,
                                name: longName,
                                datatype: itFuzzyBool,
                                valFuzzyBool: fbUncertain,
                                actionFuzzyBool: faRef,
                                refFuzzyBool: reference,
                                hasNoInputAction: nikHasNoInputAction,
                                noInputType: itFuzzyBool,
                                noInputBool: false,
                                noInputAction: faRef,
                                refNoInput: refNoInput,)
    if shared:
        com.sharedFlagsLong[longName] = flag
    else:
        com.flagsLong[longName] = flag
    result = com
