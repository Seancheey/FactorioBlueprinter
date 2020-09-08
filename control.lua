require("gui")

--- @alias player_index number

-- initialize global data as empty if they are nil
-- Note that global data cannot be metatable
function init_all_global()
    --- @type table<player_index, BlueprintGraph> records player's blueprint graph
    global.settings = global.settings or {}
end

function init_player_mod(player_index)
    global.settings[player_index] = global.settings[player_index] or {
        belt = 1,
        factory_priority = all_factories()
    }
    init_player_gui(player_index)
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
    if not gui_root(e.player_index)[outputs_select_frame] then
        create_outputs_select_frame(e.player_index)
    else
        remove_gui(e.player_index, outputs_select_frame)
        remove_gui(e.player_index, inputs_select_frame)
    end
end)
