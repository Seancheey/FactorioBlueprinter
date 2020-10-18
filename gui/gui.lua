local assertNotNull = require("__MiscLib__/assert_not_null")
--- @type GuiLib
local GuiLib = require("__MiscLib__/guilib")

--- @class OutputSpec one blueprint output specification
--- @field crafting_speed number speed
--- @field unit number crafting speed unit multiplier, with item/s as 1
--- @field ingredient string recipe name of specification

main_button = "bp-main-button"
main_function_frame = "bp-outputs-frame"
inputs_select_frame = "bp-inputs-frame"
unit_values = { ["item/s"] = 1, ["item/min"] = 60 }
output_units = { "item/s", "item/min" }

--- initialize gui of player with player_index at gui_area
function init_player_gui(player_index)
    assertNotNull(player_index)
    GuiLib.removeGuiElementWithName(player_index, main_button)
    GuiLib.removeGuiElementWithName(player_index, main_function_frame)
    GuiLib.removeGuiElementWithName(player_index, inputs_select_frame)

    GuiLib.gui_root(player_index).add {
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = main_button
    }
end
