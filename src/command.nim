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
