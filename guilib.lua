require("helper")

guilib_listening_events = {
    defines.events.on_gui_click,
    defines.events.on_gui_opened,
    defines.events.on_gui_elem_changed,
    defines.events.on_gui_selection_state_changed,
    defines.events.on_gui_text_changed
}

start_listening = false
gui_handlers = {}
gui_refreshed = {}

function __init_guilib_player_handler(player_index)
    gui_handlers[player_index] = gui_handlers[player_index] or {}
    for _, event in ipairs(guilib_listening_events) do
        gui_handlers[player_index][event] = gui_handlers[player_index][event] or {}
    end
end

function guilib_start_listening_events()
    -- ensure this method is only called once
    if start_listening then
        return
    end
    start_listening = true

    for _, event in ipairs(guilib_listening_events) do
        script.on_event(event, function(e)
            debug_print("guilib event detected")
            if not gui_handlers[e.player_index] or not gui_handlers[e.player_index][event] then
                debug_print("ERROR: no gui_handlers for player")
                return
            end
            for path, handle in pairs(gui_handlers[e.player_index][event]) do
                e.gui = game.players[e.player_index].gui
                if e.element.name == elem_of(path, e.gui).name then
                    debug_print("handle found")
                    handle(e)
                    return
                end
            end
            debug_print("guilib event failed to associate event to registered components")
        end)
    end
end

-- helper function to easily register event handler
function register_gui_event_handler(player_index, gui_elem, event, handler)
    assert(player_index and gui_elem and event and type(handler) == "function", "missing parameter")
    assert(gui_elem.name ~= "", "gui's name can't be nil")

    __init_guilib_player_handler(player_index)

    gui_path = path_of(gui_elem)
    for _, elem_name in pairs(__path_split(gui_path)) do
        assert(elem_name ~= "", "there is an element in path of " .. gui_elem.name .. "without name")
    end
    --debug_print("registering "..gui_path)
    gui_handlers[player_index][event][gui_path] = handler
end

function unregister_gui_event_handler(player_index, gui_elem, event)
    assert(gui_elem.name)
    gui_handlers[player_index][event][path_of(gui_elem)] = nil
end

function unregister_gui_children_event_handler(player_index, gui_parent, event)
    for _, child in pairs(gui_parent.children) do
        unregister_gui_event_handler(player_index, child, event)
    end
end

-- returns the path of a gui element represented by a list in order of [elem_name, parent_name, ... , root_name]
function path_of(gui_elem)
    assert(gui_elem.name)
    if gui_elem.parent then
        return path_of(gui_elem.parent) .. "|" .. gui_elem.name
    else
        return gui_elem.name
    end
end

function __path_split(str)
    local t = {}
    for s in string.gmatch(str, "([^|]+)") do
        table.insert(t, s)
    end
    return t
end

function __elem_of_helper(path, gui, i)
    if path[i] then
        if path[i] == "left" or path[i] == "top" or path[i] == "center" then
            return __elem_of_helper(path, gui[path[i]], i + 1)
        end
        for _, child in ipairs(gui.children) do
            if child.name and child.name == path[i] then
                return __elem_of_helper(path, child, i + 1)
            end
        end
        assert(false, "path children is not found/invalid when finding " .. path[i])
    else
        return gui
    end
end

function elem_of(path, gui)
    assert(path and gui, "Found missing/nil parameter")
    return __elem_of_helper(__path_split(path), gui, 1)
end
