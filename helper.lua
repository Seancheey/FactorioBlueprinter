-- helper function to easily register event handler
function register_gui_event_handler(gui_elem, event, handler)
    if not global.handlers[event] then
        global.handlers[event] = {}
        script.on_event(event,
            function(e)
                for elem, handle in pairs(global.handlers[event]) do
                    if e.element == elem then
                        e.gui = game.players[e.player_index].gui
                        handle(e)
                        break
                    end
                end
            end
        )
    end
    global.handlers[event][gui_elem] = handler
end

function unregister_gui_event_handler(gui_elem, event)
    global.handlers[event][gui_elem] = nil
end

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
    out = {}
    for k, v in pairs(self) do
        out[k] = f(v)
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
