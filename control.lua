require("gui")

--- @alias player_index number

-- initialize global data as empty if they are nil
-- Note that global data cannot be metatable
function init_all_global()
    --- @type table<player_index, BlueprintGraph> records player's blueprint graph
    global.blueprint_graph = global.blueprint_graph or {}
    global.settings = global.settings or {}
end

function init_player_mod(player_index)
    global.blueprint_graph[player_index] = global.blueprint_graph[player_index] or {}
    global.settings[player_index] = global.settings[player_index] or {
        belt = 1,
        factory_priority = all_factories()
    }
    init_player_gui(player_index, nil)
end


-- Only called when starting a new game / loading a game without this mod
script.on_init(function()
    init_all_global()
end)

-- Besides when on_init, Called everytime the script is loaded
script.on_load(function()
end)

script.on_event(defines.events.on_player_joined_game, function(e)
    init_player_mod(e.player_index)
end)

start_listening_events()

register_global_gui_event_handler(main_button, defines.events.on_gui_click, function(e)
    parent = game.players[e.player_index].gui.left
    if not parent[outputs_select_frame] then
        create_outputs_select_frame(e.player_index, parent)
        create_inputs_select_frame(e.player_index, parent)
        parent[inputs_select_frame].visible = false
    else
        clear_additional_gui(e.player_index, parent)
    end
end)


script.on_configuration_changed(function(data)
    -- no configuration change should be needed for now
end)
