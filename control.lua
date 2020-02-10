
function create_mod_gui(player)
    if player.gui.left["blueprinter-button"] then
        player.gui.left["blueprinter-button"].destroy()
    end

    player.gui.left.add{
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = "blueprinter-button"
    }
end

script.on_event(defines.events.on_player_joined_game,
    function(e)
        local player = game.players[e.player_index]
        player.print("player joined")
        create_mod_gui(player)
    end
)
--script.on_event(defines.events.on_player_respawned,create_mod_gui)
