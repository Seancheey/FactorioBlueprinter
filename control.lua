require("gui")
function try_init_all_global()
    if not global.handlers then global.handlers = {} end
    if not global.blueprint_outputs then global.blueprint_outputs = {} end
end
function init_player_global(player_index)
    global.blueprint_outputs[player_index] = {}
end
--initialize blueprinter guis
script.on_event(defines.events.on_player_joined_game,
    function(e)
        try_init_all_global()
        init_player_global(e.player_index)
        local player = game.players[e.player_index]
        player.print("player joined")
        clear_mod_gui(player)
        local button = create_blueprinter_button(player.gui.left)
        local frame = create_outputs_frame(player.gui.left, e.player_index)
        frame.visible = false
        local in_frame =  create_inputs_frame(player.gui.left, e.player_index)
        in_frame.visible = false
    end
)
-- script.on_event(defines.events.on_gui_elem_changed,
--     function(e)
--         local player = game.players[e.player_index]
--         if e.element.type == "choose-elem-button" then
--             player.print(e.element.elem_type .. ", " .. e.element.elem_value)
--         end
--     end
-- )
--script.on_event(defines.events.on_player_respawned,create_mod_gui)
