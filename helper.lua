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
                    end
                end
            end
        )
    end
    global.handlers[event][gui_elem] = handler
end

function debug_print(msg, player_index)
    if true then
        game.players[player_index].print(tostring(msg))
    end
end

function key_string(table)
    local keys = ""
    for k,v in pairs(table) do
        keys = keys .. " " .. tostring(k)
    end
    return keys
end
