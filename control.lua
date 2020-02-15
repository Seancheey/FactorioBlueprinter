require("gui")

function try_init_all_global(reset)
    if reset or not global.handlers then global.handlers = newtable{} end
    if reset or not global.blueprint_outputs then global.blueprint_outputs = newtable{} end
end

function initialize_player_gui(e)
    print("initilizing player gui")
    try_init_all_global(false)
    global.blueprint_outputs[e.player_index] = newtable{}
    local player = game.players[e.player_index]
    clear_mod_gui(player)
    local button = create_blueprinter_button(player.gui.left)
    local frame = create_outputs_frame(player.gui.left, e.player_index)
    frame.visible = false
    local in_frame =  create_inputs_frame(player.gui.left, e.player_index)
    in_frame.visible = false
end

--initialize blueprinter guis
script.on_event(defines.events.on_player_joined_game,initialize_player_gui)

script.on_event(defines.events.on_player_created,initialize_player_gui)

script.on_configuration_changed(function(data)try_init_all_global(true)end)

script.on_event(defines.events.on_player_left_game,
    function(e)
        if next(game.players) == nil then
            try_init_all_global(true)
        end
    end
)
