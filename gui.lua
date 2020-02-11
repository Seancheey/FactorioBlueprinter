require("helper")
main_button = "bp-main-button"
main_frame = "bp-outputs-frame"
unit_values = {["item/s"] = 1, ["item/min"] = 60}
output_units = {"item/s", "item/min"}
-- clear all mod guis
function clear_mod_gui(player)
    for i, to_remove in ipairs{main_button,main_frame} do
        if player.gui.left[to_remove] then
            player.gui.left[to_remove].destroy()
        end
        if player.gui.left[to_remove] then
            player.gui.left[to_remove].destroy()
        end
    end
end

function create_blueprinter_button(parent)
    local button = parent.add{
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = main_button
    }
    register_gui_event_handler(button, defines.events.on_gui_click,
        function(e)
            local player = game.players[e.player_index]
            player.gui.left[main_frame].visible = not player.gui.left[main_frame].visible
        end
    )
end

function create_new_output_item_choice(parent, player_index)
    local outputs_table = global.blueprint_outputs[player_index]
    local item_choice = {recipe=nil, num=1, unit=output_units[1]}
    outputs_table[#outputs_table+1] = item_choice
    local choose_button = parent.add{type = "choose-elem-button", elem_type = "recipe"}
    register_gui_event_handler(choose_button, defines.events.on_gui_elem_changed,
        function(e)
            item_choice.recipe = e.element.elem_value
            debug_print('recipe to ' .. tostring(item_choice.recipe), e.player_index)
            -- expand table if in need
            local need_expand = true
            for i, choice in ipairs(outputs_table) do
                if not choice.recipe then
                    need_expand = false
                    break
                end
            end
            if need_expand then
                create_new_output_item_choice(parent, player_index)
            end
        end
    )
    local numfield = parent.add{type = "textfield", text = "1", numeric = true, allow_negative = false}
    register_gui_event_handler(numfield, defines.events.on_gui_text_changed,
        function(e)
            item_choice.num = (e.element.text ~= "" and tonumber(e.element.text) or 0)
            debug_print('number to ' .. tostring(item_choice.num), e.player_index)
        end
    )
    local unitbox = parent.add{type = "drop-down", items = output_units, selected_index = 1}
    register_gui_event_handler(unitbox, defines.events.on_gui_selection_state_changed,
        function(e)
            local old_unit_val = unit_values[item_choice.unit]
            item_choice.unit = output_units[e.element.selected_index]
            local new_unit_val = unit_values[item_choice.unit]
            -- recalculate item crafting speed according to new unit
            local new_num = item_choice.num*new_unit_val/old_unit_val
            numfield.text = tostring(new_num)
            item_choice.num = new_num
            debug_print('unit to ' .. item_choice.unit, e.player_index)
        end
    )
end

function create_outputs_frame(parent, player_index)
    local frame = parent.add{type = "frame",name = main_frame,caption = "Blueprinter"}
        local tab_pane = frame.add{type = "tabbed-pane",name = outputs_tab_pane,caption = "outputs",direction = "vertical"}
            local output_tab = tab_pane.add{type = "tab",name = "outputs_tab",caption = "outputs"}
            local output_flow = tab_pane.add{type = "flow", direction = "vertical"}
                local output_table = output_flow.add{type = "table", name = "output_table", caption = "select output items",column_count = 3}
                    create_new_output_item_choice(output_table, player_index)
                local confirm_button = output_flow.add{type = "button", caption = "confirm"}
            local setting_tab = tab_pane.add{type = "tab",name = "setting_tab",caption = "settings"}
                local test = tab_pane.add{type = "label",name = "test",caption = "test setting"}
            tab_pane.add_tab(output_tab, output_flow)
            tab_pane.add_tab(setting_tab, test)
            tab_pane.selected_tab_index = 1
    return frame
end
