type
    PermName = distinct string
    Permission = ref object
        name*: PermName
        granted*: seq[Permission]
        description*: string

proc `==`* (left: PermName, right: PermName): bool {.borrow.}

proc `in`* (left: Permission, right: Permission): bool =
    return left in right.granted

proc `notin`* (left: Permission, right: Permission): bool =
    return left notin right.granted

proc `in`* (left: PermName, right: Permission): bool =
    if left == right.name:
        return true
    for p in right.granted:
        if left == p.name:
            return true
    for p in right.granted:
        if left in p:
            return true
    return false

proc `notin`* (left: PermName, right: Permission): bool =
    return not (left in right)