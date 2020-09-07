function debug_print(msg, player_index)
    local player = player_index and game.players[player_index] or game
    if true then
        player.print(tostring(msg))
    end
end

Table = {}
Table.__index = Table

function newtable(table)
    out = table or {}
    setmetatable(out,Table)
    return out
end

function Table:keys()
    assert(self)
    local keyset = newtable()
    local n=0
    for k, _ in pairs(self) do
      n=n+1
      keyset[n]=k
    end
    return keyset
end

function Table:values()
    assert(self)
    local valset = newtable()
    local n=0
    for _, v in pairs(self) do
      n=n+1
      valset[n]=v
    end
    return valset
end

function Table:has(val)
    assert(self and val)
    for _, test in pairs(self) do
        if val == test then
            return true
        end
    end
    return false
end

function Table:map(f)
    assert(self and f)
    out = newtable{}
    for k, v in pairs(self) do
        out[k] = f(v)
    end
    return out
end

function Table:filter(f)
    assert(self and f)
    out = newtable{}
    for k,v in pairs(self) do
        if f(v) then
            out[k] = v
        end
    end
    return out
end

function Table:all(f)
    f = f or function(x) return x end
    assert(self and f)
    for _, v in pairs(self) do
        if not f(v) then
            return false
        end
    end
    return true
end

function Table:any(f)
    f = f or function(x) return x end
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
    for k,v in pairs(self) do
        keys = keys .. tostring(k) .. ": " .. tostring(v) .. ","
    end
    keys = "{" .. keys:sub(1,-2) .. "}"
    return keys
end

function Table:shallow_copy()
    out = newtable{}
    for k,v in pairs(self) do
        out[k] = v
    end
    return out
end

function sprite_of(name)
    if game.item_prototypes[name] then
        return "item/"..name
    elseif game.fluid_prototypes[name] then
        return "fluid/"..name
    end
end

-- raise error if any value is nil or false
-- note: 0 / "" will pass the assertion in lua
function assertAllTruthy(...)
    for i, v in ipairs({...}) do
        assert(v, "ERROR: argument at position " .. i .. " is falsy.")
    end
end