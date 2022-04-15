import command, datatypes


proc root(input: varargs[string, `$`]): void =
    echo("root callback")

proc foo(input: varargs[string, `$`]): void =
    echo("foo callback")

proc bar(input: varargs[string, `$`]): void =
    echo("bar callback")

proc bat(input: varargs[string, `$`]): void =
    echo("bat callback")

proc foo_a(val: bool): void =
    echo("foo -a callback")

proc foo_bbb(val: bool): void =
    echo("foo --bbb callback")

proc bar_cc(val: int64): void =
    echo("bar --cc callback")

var dref: ref int64
dref[] = 5

var cv1 = newCommandVariant("root", "test_short", "test_long", root)
var cv_foo = cv1.addSubcommand("foo", "foo_short", "foo_long", foo)
var cv_bar = cv1.addSubcommand("bar", "bar_short", "bar_long", bar)
var cv_bat = cv1.addSubcommand("bat", "bat_short", "bat_long", bat)
var cv_foo_alias = cv1.addAlias("foo_alias", "^,foo")
var cv_foo_flags = cv_foo.addBoolFlag('a', foo_a, false).addBoolFlag("bbb", foo_bbb, false)
var cv_bar_flags = cv_bar.addIntFlag('d', dref)
addFlags(cv_bar, ('c', "cc", true, bar_cc), ('d', true, dref))
cv1.process()
