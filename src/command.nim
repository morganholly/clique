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
        flagsShort*: Table[char, ref FlagVariant]
        flagsLong*: Table[string, ref FlagVariant]
        sharedFlagsShort*: Table[char, ref FlagVariant]  # applies to all subcommands
        sharedFlagsLong*: Table[string, ref FlagVariant]  # applies to all subcommands


proc process* (cv: CommandVariant): void =
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
                            flagsShort: initTable[char, ref FlagVariant](),
                            flagsLong: initTable[string, ref FlagVariant](),
                            sharedFlagsShort: initTable[char, ref FlagVariant](),
                            sharedFlagsLong: initTable[string, ref FlagVariant]()
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
                        flagsShort: initTable[char, ref FlagVariant](),
                        flagsLong: initTable[string, ref FlagVariant](),
                        sharedFlagsShort: initTable[char, ref FlagVariant](),
                        sharedFlagsLong: initTable[string, ref FlagVariant]()
                        ))