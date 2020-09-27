logging = {}
logging.E = 1
logging.W = 2
logging.I = 3
logging.D = 4

function logging.should_output()
    return true
end

function print_log(msg, level)
    level = level or logging.D
    if logging.should_output(level) then
        game.print(tostring(msg))
    end
end

--- @class Pointer a simple reference pointer
Pointer = {}

--- @generic T
--- @param val T
--- @return T[]
function Pointer.new(val)
    return { val }
end

--- @generic T
--- @param ref T[]
--- @return T
function Pointer.get(ref)
    return ref[1]
end

function Pointer.set(ref, value)
    ref[1] = value
end

--- @class ArrayList
ArrayList = {}
ArrayList.__index = ArrayList

--- @generic T: ArrayList
--- @param toCast T listToBeCased
--- @return T
function ArrayList.cast(toCast)
    return setmetatable(toCast, ArrayList)
end

--- @generic T: ArrayList
--- @param list T listToBeCased
--- @return T
function ArrayList.new(list)
    local o = setmetatable({}, ArrayList)
    if list then
        o:addAll(list)
    end
    return o
end

--- @generic T
--- @param table table<T, any>
--- @return T[]|ArrayList
function ArrayList.fromKeys(table)
    assert(table)

    local o = setmetatable({}, ArrayList)
    for k, _ in pairs(table) do
        o:add(k)
    end
    return o
end

--- @generic T: self
--- @param val T
function ArrayList:add(val)
    assertAllTruthy(self, val)

    self[#self + 1] = val
    return self
end

--- @generic T
--- @param table table<any, T>|T[]
--- @return ArrayList|T[]
function ArrayList:addAll(table)
    assertAllTruthy(self, table)

    for _, val in pairs(table) do
        ArrayList.add(self, val)
    end
    return self
end

function ArrayList:insert(val, pos)
    assertAllTruthy(self, val)
    local p = pos or 1

    local i = #self + 1
    while i > p and i > 1 do
        self[i] = self[i - 1]
        i = i - 1
    end
    self[p] = val
end

--- @param comp fun(a, b):boolean element goes into the first element with true value returned
function ArrayList:insert_by_order(val, comp)
    assertAllTruthy(self, val, comp)
    for i, list_val in ipairs(self) do
        if comp(val, list_val) then
            self:insert(val, i)
            return
        end
    end
    self:insert(val, #self + 1)
end

--- @generic T
--- @param val T
--- @param eq_func fun(a:T, b:T):boolean
--- @return boolean
function ArrayList:has(val, eq_func)
    assert(self and val)
    for _, test in pairs(self) do
        if eq_func and eq_func(val, test) or (val == test) then
            return true
        end
    end
    return false
end

--- @param f fun(ele: any):any
--- @return ArrayList
function ArrayList:map(f)
    assert(self and f)
    local out = toArrayList {}
    for k, v in pairs(self) do
        out[k] = f(v)
    end
    return out
end

--- @param f fun(ele:any):any, any
function ArrayList:mapToTable(f)
    assert(self and f)
    local out = {}
    for _, v in pairs(self) do
        local table_key, table_val = f(v)
        out[table_key] = table_val
    end
    return out
end

--- @generic T
--- @param f fun(a:T, b:T):T
function ArrayList:reduce(f)
    assert(self and f)
    local val = self[1]
    for i = 2, #self, 1 do
        val = f(val, self[i])
    end
    return val
end

--- @param f fun(ele: any):boolean
--- @return ArrayList
function ArrayList:filter(f)
    assert(self and f)
    local out = toArrayList {}
    local i = 1
    for _, v in pairs(self) do
        if f(v) then
            out[i] = v
            i = i + 1
        end
    end
    return out
end

--- @param f fun(ele: any):boolean
--- @return boolean
function ArrayList:all(f)
    assert(self and f)
    f = f or function(x)
        return x
    end
    for _, v in pairs(self) do
        if not f(v) then
            return false
        end
    end
    return true
end

--- @param f fun(ele: any):boolean
--- @return boolean
function ArrayList:any(f)
    f = f or function(x)
        return x
    end
    assert(self and f)
    for _, v in pairs(self) do
        if f(v) then
            return true
        end
    end
    return false
end

function ArrayList:tostring()
    local keys = ""
    for k, v in pairs(self) do
        keys = keys .. tostring(k) .. ": " .. tostring(v) .. ","
    end
    keys = "{" .. keys:sub(1, -2) .. "}"
    return keys
end

--- @generic T
--- @param table T
--- @return ArrayList|T
function toArrayList(table)
    return setmetatable(table or {}, ArrayList)
end

function sprite_of(name)
    assert(type(name) == "string")
    if game.item_prototypes[name] then
        return "item/" .. name
    elseif game.fluid_prototypes[name] then
        return "fluid/" .. name
    elseif game.entity_prototypes[name] then
        return "entity/" .. name
    else
        print_log("failed to find sprite path for name " .. name)
    end
end

--- @class Vector
--- @field x number
--- @field y number

--- @class Dimension
--- @field x number
--- @field y number
Dimension = {}
Dimension.__index = Dimension

function Dimension.__eq(ca, cb)
    return ca.x == cb.x and ca.y == cb.y
end

--- @return Dimension a comparable coordinate object
function Dimension.new(x, y)
    return setmetatable({ x = x, y = y }, Dimension)
end

--- @type Vector
Vector = {}
Vector.__index = Vector

--- @return Vector
function Vector.new(x, y)
    return setmetatable({ x = x or 0, y = y or 0 }, Vector)
end

--- @param direction defines.direction
--- @return Vector
function Vector.fromDirection(direction)
    assertAllTruthy(direction)

    if direction == 0 then
        return Vector.new(0, -1)
    elseif direction == 1 then
        return Vector.new(1, -1)
    elseif direction == 2 then
        return Vector.new(1, 0)
    elseif direction == 3 then
        return Vector.new(1, 1)
    elseif direction == 4 then
        return Vector.new(0, 1)
    elseif direction == 5 then
        return Vector.new(-1, 1)
    elseif direction == 6 then
        return Vector.new(-1, 0)
    elseif direction == 7 then
        return Vector.new(-1, -1)
    else
        print_log("direction " .. direction .. "has no corresponding vector :( ???")
        return nil
    end
end

--- @return defines.direction
function Vector:toDirection()
    if self.x == 0 and self.y == -1 then
        return 0
    elseif self.x == 1 and self.y == -1 then
        return 1
    elseif self.x == 1 and self.y == 0 then
        return 2
    elseif self.x == 1 and self.y == 1 then
        return 3
    elseif self.x == 0 and self.y == 1 then
        return 4
    elseif self.x == -1 and self.y == 1 then
        return 5
    elseif self.x == -1 and self.y == 0 then
        return 6
    elseif self.x == -1 and self.y == -1 then
        return 7
    else
        print_log("Vector has no corresponding direction :( ???")
        return nil
    end
end

--- @return Vector
function Vector:reverse()
    return Vector.new(self.x * -1, self.y * -1)
end

--- @return Vector
function Vector:__add(other)
    return Vector.new(self.x + other.x, self.y + other.y)
end

--- @return Vector
function Vector.__sub(other)
    return Vector.new(self.x - other.x, self.y - other.y)
end

--- @generic T
--- @param orig T
--- @return T
function deep_copy(orig, keep_metatable)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deep_copy(orig_key)] = deep_copy(orig_value)
        end
        if keep_metatable then
            setmetatable(copy, deep_copy(getmetatable(orig)))
        end
    else
        -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- @generic T
--- @param orig T
--- @return T
function shallow_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

--- raises error if any value is nil
function assertAllTruthy(...)
    local n = select("#", ...)
    local arg_num = 0
    for _, _ in pairs { ... } do
        arg_num = arg_num + 1
    end
    if n ~= arg_num then
        assert(false, "needs " .. n .. " arguments but only provided " .. arg_num .. " non-nil arguments")
    end
end