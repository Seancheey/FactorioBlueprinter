--- @class OutputSpec one blueprint output specification
--- @field crafting_speed number speed
--- @field unit number crafting speed unit multiplier, with item/s as 1
--- @field ingredient string recipe name of specification

main_button = "bp-main-button"
main_function_frame = "bp-outputs-frame"
inputs_select_frame = "bp-inputs-frame"
unit_values = {["item/s"] = 1, ["item/min"] = 60}
output_units = {"item/s", "item/min"}

--- clear gui and its children as well as unregister all it's handlers.
--- Non-existing gui element is tolerated and nothing will be done in this case.
--- @param gui_name string gui element name
function remove_gui(player_index, gui_name)
    assertAllTruthy(player_index, gui_name)

    if gui_root(player_index)[gui_name] then
        unregister_all_handlers(player_index, elem_of(gui_name, player_index))
        gui_root(player_index)[gui_name].destroy()
    end
end

function remove_all_gui_children(player_index, gui_elem)
    assertAllTruthy(player_index, gui_elem)

    for _, child in ipairs(gui_elem.children) do
        unregister_all_handlers(player_index, child)
    end
    gui_elem.clear()
end

--- initialize gui of player with player_index at gui_area
function init_player_gui(player_index)
    assertAllTruthy(player_index)

    remove_gui(player_index, main_button)
    remove_gui(player_index, main_function_frame)
    remove_gui(player_index, inputs_select_frame)

    gui_root(player_index).add{
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = main_button
    }
end
