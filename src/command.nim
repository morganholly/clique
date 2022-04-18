import std/tables, std/os, std/strutils, std/macros, std/enumerate
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
            result = com.name & com.info & com.help & "\n" & $com.subcommands & "\nfs " & $com.flagsShort & "\nfl " & $com.flagsLong & "\nsfs " & $com.sharedFlagsShort & "\nsfl " & $com.sharedFlagsLong
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
                    if (len(params) - readOffset) > 1:
                        com.flagsLong[vnodash].action(params[readOffset + 1])
                        parse(com, params, root, readOffset + 2)
                    else:
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
                            if (len(params) - readOffset) > 1:
                                current.sharedFlagsLong[vnodash].action(params[readOffset + 1])
                                parse(current, params, root, readOffset + 2)
                            else:
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
    FlagDeclTuplesNoAction* = tuple[shortName: char,
                            longName: string,
                            shared: bool] or
                    tuple[shortName: char,
                            longName: string,
                            shared: bool,
                            callbackNoInput: proc (val: bool): void] or
                    tuple[shortName: char,
                            longName: string,
                            shared: bool,
                            refNoInput: ref bool]
    # FlagDeclCallbackLong* = tuple[longName: string, shared: bool, callback: proc (val: int64): void] or
    #                     tuple[longName: string, shared: bool, callback: proc (val: float64): void] or
    #                     tuple[longName: string, shared: bool, callback: proc (val: string): void] or
    #                     tuple[longName: string, shared: bool, callback: proc (val: bool): void] or
    #                     tuple[longName: string, shared: bool, callback: proc (val: FuzzyBool): void]
    # FlagDeclCallbackBoth* = tuple[shortName: char, longName: string, shared: bool, callback: proc (val: int64): void] or
    #                     tuple[shortName: char, longName: string, shared: bool, callback: proc (val: float64): void] or
    #                     tuple[shortName: char, longName: string, shared: bool, callback: proc (val: string): void] or
    #                     tuple[shortName: char, longName: string, shared: bool, callback: proc (val: bool): void] or
    #                     tuple[shortName: char, longName: string, shared: bool, callback: proc (val: FuzzyBool): void]
    # FlagDeclCallback* = FlagDeclCallbackLong or FlagDeclCallbackBoth
    # FlagDeclRefLong* = tuple[longName: string, shared: bool, refVal: ref int64] or
    #                 tuple[longName: string, shared: bool, refVal: ref float64] or
    #                 tuple[longName: string, shared: bool, refVal: ref string] or
    #                 tuple[longName: string, shared: bool, refVal: ref bool] or
    #                 tuple[longName: string, shared: bool, refVal: ref FuzzyBool]
    # FlagDeclRefBoth* = tuple[shortName: char, longName: string, shared: bool, refVal: ref int64] or
    #                 tuple[shortName: char, longName: string, shared: bool, refVal: ref float64] or
    #                 tuple[shortName: char, longName: string, shared: bool, refVal: ref string] or
    #                 tuple[shortName: char, longName: string, shared: bool, refVal: ref bool] or
    #                 tuple[shortName: char, longName: string, shared: bool, refVal: ref FuzzyBool]
    # FlagDeclRef* = FlagDeclRefLong or FlagDeclRefBoth
    # FlagDeclCallbackNoInput* = tuple[shortName: char, longName: string, shared: bool, callback: proc (val: int64): void, callbackNoInput: proc (val: bool): void] or
    #                             tuple[shortName: char, longName: string, shared: bool, callback: proc (val: float64): void, callbackNoInput: proc (val: bool): void] or
    #                             tuple[shortName: char, longName: string, shared: bool, callback: proc (val: string): void, callbackNoInput: proc (val: bool): void] or
    #                             tuple[shortName: char, longName: string, shared: bool, callback: proc (val: bool): void, callbackNoInput: proc (val: bool): void] or
    #                             tuple[shortName: char, longName: string, shared: bool, callback: proc (val: FuzzyBool): void, callbackNoInput: proc (val: bool): void]
    # FlagDeclRefNoInput* = tuple[shortName: char, longName: string, shared: bool, refVal: ref int64, refNoInput: ref bool] or
    #                         tuple[shortName: char, longName: string, shared: bool, refVal: ref float64, refNoInput: ref bool] or
    #                         tuple[shortName: char, longName: string, shared: bool, refVal: ref string, refNoInput: ref bool] or
    #                         tuple[shortName: char, longName: string, shared: bool, refVal: ref bool, refNoInput: ref bool] or
    #                         tuple[shortName: char, longName: string, shared: bool, refVal: ref FuzzyBool, refNoInput: ref bool]
    # FlagDeclTuples* = FlagDeclCallback or FlagDeclRef or FlagDeclCallbackNoInput or FlagDeclRefNoInput


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
            shortName: char = '\0',
            longName: string = "",
            callback: FlagCallbacks,
            shared: bool = false
            ): var CommandVariant =
    var flag: FlagVariantRef
    when callback is proc (val: int64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itInt,
                            valInt: 0,
                            actionInt: faCallback,
                            callbackInt: callback,
                            hasNoInputAction: nikRequiresInput)
    elif callback is proc (val: float64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itFloat,
                            valFloat: 0.0,
                            actionFloat: faCallback,
                            callbackFloat: callback,
                            hasNoInputAction: nikRequiresInput)
    elif callback is proc (val: string): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itString,
                            valString: "",
                            actionString: faCallback,
                            callbackString: callback,
                            hasNoInputAction: nikRequiresInput)
    elif callback is proc (val: bool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itBool,
                            valBool: false,
                            actionBool: faCallback,
                            callbackBool: callback,
                            hasNoInputAction: nikRequiresInput)
    elif callback is proc (val: FuzzyBool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itFuzzyBool,
                            valFuzzyBool: fbUncertain,
                            actionFuzzyBool: faCallback,
                            callbackFuzzyBool: callback,
                            hasNoInputAction: nikRequiresInput)
    when shared:
        when (shortName != '\0') and (longName != ""):
            com.sharedFlagsShort[shortName] = flag
            com.sharedFlagsLong[longName] = flag
        elif shortName != '\0':
            com.sharedFlagsShort[shortName] = flagsLong
        elif longName != "":
            com.sharedFlagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    else:
        when (shortName != '\0') and (longName != ""):
            com.flagsShort[shortName] = flag
            com.flagsLong[longName] = flag
        elif shortName != '\0':
            com.flagsShort[shortName] = flagsLong
        elif longName != "":
            com.flagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    result = com

proc addFlag* (com: var CommandVariant,
            shortName: char = '\0',
            longName: string = "",
            reference: FlagRefs,
            shared: bool = false
            ): var CommandVariant =
    var flag: FlagVariantRef
    when reference is proc (val: int64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itInt,
                            valInt: 0,
                            actionInt: faRef,
                            refInt: reference,
                            hasNoInputAction: nikRequiresInput)
    elif reference is proc (val: float64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itFloat,
                            valFloat: 0.0,
                            actionFloat: faRef,
                            refFloat: reference,
                            hasNoInputAction: nikRequiresInput)
    elif reference is proc (val: string): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itString,
                            valString: "",
                            actionString: faRef,
                            refString: reference,
                            hasNoInputAction: nikRequiresInput)
    elif reference is proc (val: bool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itBool,
                            valBool: false,
                            actionBool: faRef,
                            refBool: reference,
                            hasNoInputAction: nikRequiresInput)
    elif reference is proc (val: FuzzyBool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itFuzzyBool,
                            valFuzzyBool: fbUncertain,
                            actionFuzzyBool: faRef,
                            refFuzzyBool: reference,
                            hasNoInputAction: nikRequiresInput)
    when shared:
        when (shortName != '\0') and (longName != ""):
            com.sharedFlagsShort[shortName] = flag
            com.sharedFlagsLong[longName] = flag
        elif shortName != '\0':
            com.sharedFlagsShort[shortName] = flagsLong
        elif longName != "":
            com.sharedFlagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    else:
        when (shortName != '\0') and (longName != ""):
            com.flagsShort[shortName] = flag
            com.flagsLong[longName] = flag
        elif shortName != '\0':
            com.flagsShort[shortName] = flagsLong
        elif longName != "":
            com.flagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    result = com


proc addFlag* (com: var CommandVariant,
            shortName: char = '\0',
            longName: string = "",
            callback: FlagCallbacks,
            shared: bool = false,
            callbackNoInput: proc (val: bool): void
            ): var CommandVariant =
    var flag: FlagVariantRef
    when callback is proc (val: int64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
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
    elif callback is proc (val: float64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
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
    elif callback is proc (val: string): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
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
    elif callback is proc (val: bool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itBool,
                            valBool: false,
                            actionBool: faCallback,
                            callbackBool: callback,
                            hasNoInputAction: nikHasNoInputAction,
                            noInputType: itBool)
    elif callback is proc (val: FuzzyBool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
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
                            callbackNoInput: callbackNoInput)
    when shared:
        when (shortName != '\0') and (longName != ""):
            com.sharedFlagsShort[shortName] = flag
            com.sharedFlagsLong[longName] = flag
        elif shortName != '\0':
            com.sharedFlagsShort[shortName] = flagsLong
        elif longName != "":
            com.sharedFlagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    else:
        when (shortName != '\0') and (longName != ""):
            com.flagsShort[shortName] = flag
            com.flagsLong[longName] = flag
        elif shortName != '\0':
            com.flagsShort[shortName] = flagsLong
        elif longName != "":
            com.flagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    result = com

proc addFlag* (com: var CommandVariant,
            shortName: char = '\0',
            longName: string = "",
            reference: FlagRefs,
            shared: bool = false,
            refNoInput: ref bool
            ): var CommandVariant =
    var flag: FlagVariantRef
    when reference is proc (val: int64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
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
    elif reference is proc (val: float64): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itFloat,
                            valFloat: 0.0,
                            actionFloat: faRef,
                            refFloat: reference,
                            hasNoInputAction: nikHasNoInputAction,
                            noInputType: itFloat,
                            noInputBool: true,
                            noInputAction: faRef,
                            refNoInput: refNoInput)
    elif reference is proc (val: string): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itString,
                            valString: "",
                            actionString: faRef,
                            refString: reference,
                            hasNoInputAction: nikHasNoInputAction,
                            noInputType: itString,
                            noInputBool: true,
                            noInputAction: faRef,
                            refNoInput: refNoInput)
    elif reference is proc (val: bool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itBool,
                            valBool: false,
                            actionBool: faRef,
                            refBool: reference,
                            hasNoInputAction: nikHasNoInputAction,
                            noInputType: itBool)
    elif reference is proc (val: FuzzyBool): void:
        flag = FlagVariantRef(kind: fkShortAndLong,
                            shortName: shortName,
                            longName: longName,
                            datatype: itFuzzyBool,
                            valFuzzyBool: fbUncertain,
                            actionFuzzyBool: faRef,
                            refFuzzyBool: reference,
                            hasNoInputAction: nikHasNoInputAction,
                            noInputType: itFuzzyBool,
                            noInputBool: true,
                            noInputAction: faRef,
                            refNoInput: refNoInput)
    when shared:
        when (shortName != '\0') and (longName != ""):
            com.sharedFlagsShort[shortName] = flag
            com.sharedFlagsLong[longName] = flag
        elif shortName != '\0':
            com.sharedFlagsShort[shortName] = flagsLong
        elif longName != "":
            com.sharedFlagsLong[longName] = flag
        else:
            raise newException(ValueError, "Creation of a flag requires at least one name")
    else:
        when (shortName != '\0') and (longName != ""):
            com.flagsShort[shortName] = flag
            com.flagsLong[longName] = flag
        elif shortName != '\0':
            com.flagsShort[shortName] = flagsLong
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
                                chr: shortName,
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
