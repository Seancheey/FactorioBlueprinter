require("util")

guilib_listening_events = {
    defines.events.on_gui_click,
    defines.events.on_gui_opened,
    defines.events.on_gui_elem_changed,
    defines.events.on_gui_selection_state_changed,
    defines.events.on_gui_text_changed
}

-- gui_handlers[player_index][event][gui_path] = handler
gui_handlers = {}

-- global_gui_handlers[event][gui_path] = handler
global_gui_handlers = {}

local gui_root_name = "left"

function __init_guilib_player_handler(player_index)
    gui_handlers[player_index] = gui_handlers[player_index] or {}
    for _, event in ipairs(guilib_listening_events) do
        gui_handlers[player_index][event] = gui_handlers[player_index][event] or {}
    end
end

-- start guilib listening, note that all events that the guilib listen to shall not be listened again
function start_listening_events()
    -- ensure this method is only called once
    if start_listening then
        return
    end
    start_listening = true

    for _, event in ipairs(guilib_listening_events) do
        global_gui_handlers[event] = global_gui_handlers[event] or {}
    end

    for _, event in ipairs(guilib_listening_events) do
        script.on_event(event, function(e)
            -- handle global events
            for gui_path, handle in pairs(global_gui_handlers[event]) do
                if e.element.name == gui_path then
                    handle(e)
                    return
                end
            end

            if not gui_handlers[e.player_index] or not gui_handlers[e.player_index][event] then
                print_log("no gui_handlers for player", logging.W)
                return
            end

            -- handle player events
            for path, handle in pairs(gui_handlers[e.player_index][event]) do
                if e.element == elem_of(path, e.player_index) then
                    handle(e)
                    return
                end
            end
        end)
    end
end

--- register a *handler* that handles *event* for gui element *gui_elem* of player with *player_index*
function register_gui_event_handler(player_index, gui_elem, event, handler)
    assertAllTruthy(player_index, gui_elem, event, handler)
    assert(type(handler) == "function", "handler should be a function")
    assert(gui_elem.name ~= "", "gui's name can't be nil")

    __init_guilib_player_handler(player_index)

    gui_path = path_of(gui_elem)
    for _, elem_name in pairs(__split_path(gui_path)) do
        assert(elem_name ~= "", "there is an element in path of " .. gui_elem.name .. "without name")
    end
    --debug_print("registering "..gui_path)
    gui_handlers[player_index][event][gui_path] = handler
end

--- register a global handler for a certain event for gui element with gui_path
--- this function is particularly useful for events handling on script loading stage, where no player is availiable
function register_global_gui_event_handler(gui_path, event, handler)
    assertAllTruthy(gui_path, event, handler)

    global_gui_handlers[event] = global_gui_handlers[event] or {}
    global_gui_handlers[event][gui_path] = handler
end

function unregister_gui_event_handler(player_index, gui_elem, event)
    assertAllTruthy(player_index, gui_elem, event)

    gui_handlers[player_index][event][path_of(gui_elem)] = nil
end

function unregister_gui_children_event_handler(player_index, gui_parent, event)
    for _, child in pairs(gui_parent.children) do
        unregister_gui_event_handler(player_index, child, event)
    end
end

--- unregister all handlers of gui_elem and its children
function unregister_all_handlers(player_index, gui_elem)
    assertAllTruthy(player_index, gui_elem)

    for _, event in pairs(guilib_listening_events) do
        if gui_handlers[player_index] and gui_handlers[player_index][event] then
            gui_handlers[player_index][event][path_of(gui_elem)] = nil
        end
    end
    for _, child in pairs(gui_elem.children) do
        unregister_all_handlers(player_index, child)
    end
end

--- @return LuaGuiElement root gui of player for this mod
function gui_root(player_index)
    assertAllTruthy(player_index)

    local root = game.players[player_index].gui[gui_root_name]
    assert(root ~= nil, "unable to find player's gui root")
    return root
end

--- @param gui_elem LuaGuiElement
--- @return string the path of a gui element represented by "root_name|parent_name|my_name ..."
function path_of(gui_elem)
    assertAllTruthy(gui_elem)

    local current_element = gui_elem
    local path = ""
    while current_element and current_element.name ~= gui_root_name do
        path = current_element.name .. "|" .. path
        current_element = current_element.parent
    end
    path = gui_root_name .. "|" .. path
    return path
end

-- returns the path of a gui element represented by a list in order of [elem_name, parent_name, ... , root_name]
function __split_path(str)
    local t = {}
    for s in string.gmatch(str, "([^|]+)") do
        table.insert(t, s)
    end
    return t
end

--- @param path string guilib path for the GuiElement
--- @param player_index player_index
--- @return LuaGuiElement
function elem_of(path, player_index)
    assertAllTruthy(path, player_index)

    local path_list = __split_path(path)
    local i = 1
    local current_element = gui_root(player_index)

    while i < #path_list do
        local found = false
        for _, child in ipairs(current_element.children) do
            if child.name == path_list[i+1] then
                current_element = child
                i = i + 1
                found = true
                break
            end
        end
        if not found then
            print_log("path children is not found/invalid when finding " .. path_list[i+1] .. " whole path:" .. serpent.line(path_list), logging.W)
            return nil
        end
    end

    return current_element
end
