require("gui")
--initialize blueprinter guis
script.on_event(defines.events.on_player_joined_game,
    function(e)
        local player = game.players[e.player_index]
        player.print("player joined")
        clear_mod_gui(player)
        local button = create_blueprinter_button(player.gui.left)
        local frame = create_outputs_frame(player.gui.left)
        frame.visible = false
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
