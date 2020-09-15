logging = {}
logging.E = 1
logging.W = 2
logging.I = 3
logging.D = 4

function logging.should_output(level)
    if level == logging.E then
        return true
    end
    return false
end

function print_log(msg, level)
    level = level or logging.D
    if logging.should_output(level) then
        game.print(tostring(msg))
    end
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

--- @param comp function(a, b):boolean element goes into the first element with true value returned
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
--- @param eq_func function(a:T, b:T):boolean
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

--- @param f function(ele: any):any
--- @return ArrayList
function ArrayList:map(f)
    assert(self and f)
    local out = toArrayList {}
    for k, v in pairs(self) do
        out[k] = f(v)
    end
    return out
end

--- @generic T
--- @param f function(a:T, b:T):T
function ArrayList:reduce(f)
    assert(self and f)
    local val = self[1]
    for i = 2, #self, 1 do
        val = f(val, self[i])
    end
    return val
end

--- @param f function(ele: any):boolean
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

--- @param f function(ele: any):boolean
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

--- @param f function(ele: any):boolean
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

function ArrayList:shallow_copy()
    local out = toArrayList {}
    for k, v in pairs(self) do
        out[k] = v
    end
    return out
end

--- @generic T
--- @param table T
--- @return ArrayList|T
function toArrayList(table)
    return setmetatable(table or {}, ArrayList)
end

function sprite_of(name)
    if game.item_prototypes[name] then
        return "item/" .. name
    elseif game.fluid_prototypes[name] then
        return "fluid/" .. name
    end
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