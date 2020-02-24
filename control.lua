require("gui")
function init_all_global(reset)
    if reset or not global.blueprint_outputs then global.blueprint_outputs = {} end
    if reset or not global.blueprint_inputs then global.blueprint_inputs = {} end
    if reset or not global.blueprint_graph then global.blueprint_graph = {} end
    if reset or not global.settings then global.settings = newtable{} end
end

function init_player_global(player_index)
    init_all_global(false)
    if not global.blueprint_outputs[player_index] then global.blueprint_outputs[player_index] = {} end
    if not global.blueprint_inputs[player_index] then global.blueprint_inputs[player_index] = {} end
    if not global.settings[player_index] then global.settings[player_index] = {assembler = 1,belt = 1} end
    if not global.blueprint_graph[player_index] then global.blueprint_graph[player_index] = {} end
end

function initialize_player_gui(e)
    print("initilizing player gui")
    init_player_global(e.player_index)
    local player = game.players[e.player_index]
    clear_mod_gui(player)
    local button = create_blueprinter_button(e.player_index, player.gui.left)
    local frame = create_outputs_frame(player.gui.left, e.player_index)
    frame.visible = false
    local in_frame =  create_inputs_frame(player.gui.left, e.player_index)
    in_frame.visible = false
end

script.on_init(function()
    init_all_global(true)
    for i, _ in pairs(game.players) do
        initialize_player_gui{player_index=i}
    end
end)

--initialize blueprinter guis
script.on_event(defines.events.on_player_joined_game,initialize_player_gui)

-- script.on_event(defines.events.on_player_created,initialize_player_gui)

script.on_configuration_changed(function(data)
    debug_print("configuration changed, re-initialize blueprinter globals")
end)

guilib_start_listening_events()
