require("gui.root_names")
require("gui.outputs_select_frame")
require("gui.inputs_select_frame")

local PlayerInfo = require("player_info")
--- @type Logger
local logging = require("__MiscLib__/logging")
--- @type GuiLib
local GuiLib = require("__MiscLib__/guilib")
--- @type GuiRootChildrenNames
local GuiRootNames = require("gui.root_names")
local releaseMode = require("release_mode")

--- @alias player_index number

if releaseMode then
    logging.disableCategory(logging.D)
    logging.disableCategory(logging.I)
    logging.disableCategory(logging.V)
    logging.disableCategory(logging.W)
    logging.disableCategory("guilib")
end

GuiLib.listenToEvents {
    defines.events.on_gui_click,
    defines.events.on_gui_opened,
    defines.events.on_gui_elem_changed,
    defines.events.on_gui_selection_state_changed,
    defines.events.on_gui_text_changed,
    defines.events.on_gui_value_changed,
}

-- initialize global data as empty if they are nil
-- Note that global data cannot be metatable
local function init_all_global()
    --- @type table<player_index, PlayerSetting>
    global.settings = global.settings or {}
end

local function init_player_mod(player_index)
    if not global.settings[player_index] then
        PlayerInfo.set_default_settings(player_index)
    end
    for _, childName in pairs(GuiRootNames) do
        GuiLib.removeGuiElementWithName(player_index, childName)
    end
    GuiLib.gui_root(player_index).add {
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = GuiRootNames.main_button
    }

end

GuiLib.registerGuiHandlerForAllPlayers(GuiLib.rootName .. "|" .. GuiRootNames.main_button, {
    [defines.events.on_gui_click] = function(e)
        if not GuiLib.gui_root(e.player_index)[GuiRootNames.main_function_frame] then
            create_main_function_frame(e.player_index)
        else
            GuiLib.removeGuiElementWithName(e.player_index, GuiRootNames.main_function_frame)
            GuiLib.removeGuiElementWithName(e.player_index, GuiRootNames.inputs_select_frame)
        end
    end
})

-- Only called when starting a new game / loading a game without this mod
script.on_init(function()
    logging.log("initialize game")
    init_all_global()
    for _, player in pairs(game.players) do
        init_player_mod(player.index)
    end
end)

-- Besides when on_init, Called everytime the script is loaded
script.on_load(function()
end)

script.on_event(defines.events.on_player_joined_game, function(e)
    logging.log("player joined game, initialize mod")
    init_player_mod(e.player_index)
end)

script.on_configuration_changed(function()
    logging.log("configuration changed, reset default settings")
    for player_index, _ in ipairs(global.settings) do
        PlayerInfo.set_default_settings(player_index)
        init_player_mod(player_index)
    end
end)

-- used for debugging purpose only
if script.active_mods["gvv"] then
    require("__gvv__.gvv")()
end