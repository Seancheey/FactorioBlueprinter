require("gui")

function reset_all_global()
    global.blueprint_outputs = {}
    global.blueprint_inputs = {}
    global.blueprint_graph = {}
    global.settings = newtable {}
end

function init_all_global()
    global.blueprint_outputs = global.blueprint_outputs or {}
    global.blueprint_inputs = global.blueprint_inputs or {}
    global.blueprint_graph = global.blueprint_graph or {}
    global.settings = global.settings or newtable {}
end

function init_player_mod(player_index)
    init_all_global()
    global.blueprint_outputs[player_index] = global.blueprint_outputs[player_index] or {}
    global.blueprint_inputs[player_index] = global.blueprint_inputs[player_index] or {}
    global.blueprint_graph[player_index] = global.blueprint_graph[player_index] or {}
    global.settings[player_index] = global.settings[player_index] or {
        belt = 1,
        factory_priority = all_factories()
    }
    init_player_gui(player_index, nil)
end

script.on_init(function()
    reset_all_global()
    for player_index, _ in pairs(game.players) do
        init_player_mod(player_index)
    end
end)

--initialize blue printer GUIs
script.on_event(defines.events.on_player_joined_game, function(e)
    init_player_mod(e.player_index)
end)

script.on_configuration_changed(function(data)
    debug_print("configuration changed, re-initialize blueprinter globals")
end)

guilib_start_listening_events()
