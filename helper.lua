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

--- @class HelperTable

--- @type HelperTable
Table = {}
Table.__index = Table

--- @return HelperTable
function newtable(table)
    return setmetatable(table or {}, Table)
end

--- @return HelperTable
function Table:keys()
    assert(self)
    local keyset = newtable()
    local n = 0
    for k, _ in pairs(self) do
        n = n + 1
        keyset[n] = k
    end
    return keyset
end

--- @return HelperTable
function Table:values()
    assert(self)
    local valset = newtable()
    local n = 0
    for _, v in pairs(self) do
        n = n + 1
        valset[n] = v
    end
    return valset
end

--- @param val any
--- @return boolean
function Table:has(val)
    assert(self and val)
    for _, test in pairs(self) do
        if val == test then
            return true
        end
    end
    return false
end

--- @param f function(ele: any):any
--- @return HelperTable
function Table:map(f)
    assert(self and f)
    local out = newtable {}
    for k, v in pairs(self) do
        out[k] = f(v)
    end
    return out
end

--- @param f function(ele: any):boolean
--- @return HelperTable
function Table:filter(f)
    assert(self and f)
    local out = newtable {}
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
function Table:all(f)
    f = f or function(x)
        return x
    end
    assert(self and f)
    for _, v in pairs(self) do
        if not f(v) then
            return false
        end
    end
    return true
end

--- @param f function(ele: any):boolean
--- @return boolean
function Table:any(f)
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

function Table:tostring()
    local keys = ""
    for k, v in pairs(self) do
        keys = keys .. tostring(k) .. ": " .. tostring(v) .. ","
    end
    keys = "{" .. keys:sub(1, -2) .. "}"
    return keys
end

function Table:shallow_copy()
    local out = newtable {}
    for k, v in pairs(self) do
        out[k] = v
    end
    return out
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