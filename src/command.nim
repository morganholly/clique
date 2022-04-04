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

proc new* (name: string,
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
