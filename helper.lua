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

function key_string(table)
    local keys = ""
    for k,v in pairs(table) do
        keys = keys .. " " .. tostring(k)
    end
    return keys
end

function array_string(array)
    local out = ""
    for i,val in ipairs(array) do
        out = out .. " " .. tostring(val)
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
