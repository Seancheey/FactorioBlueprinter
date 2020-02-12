require("helper")
require("blueprint_gen")
main_button = "bp-main-button"
main_frame = "bp-outputs-frame"
inputs_frame = "bp-inputs-frame"
unit_values = {["item/s"] = 1, ["item/min"] = 60}
output_units = {"item/s", "item/min"}

-- clear all mod guis
function clear_mod_gui(player)
    for i, to_remove in ipairs{main_button,main_frame,inputs_frame} do
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
            e.gui.left[main_frame].visible = not e.gui.left[main_frame].visible
            e.gui.left[inputs_frame].visible = false
        end
    )
end


function create_new_output_item_choice(parent, player_index)
    local outputs_table = global.blueprint_outputs[player_index]
    local item_choice = {recipe=nil, crafting_speed = 1, unit=output_units[1]}
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
            item_choice.crafting_speed = (e.element.text ~= "" and tonumber(e.element.text) or 0) / unit_values[item_choice.unit]
            debug_print('number to ' .. tostring(item_choice.crafting_speed), e.player_index)
        end
    )
    local unitbox = parent.add{type = "drop-down", items = output_units, selected_index = 1}
    register_gui_event_handler(unitbox, defines.events.on_gui_selection_state_changed,
        function(e)
            item_choice.unit = output_units[e.element.selected_index]
            -- recalculate item crafting speed according to new unit
            local new_num = item_choice.crafting_speed*unit_values[item_choice.unit]
            numfield.text = tostring(new_num)
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
                register_gui_event_handler(confirm_button, defines.events.on_gui_click,
                    function(e)
                        e.gui.left[inputs_frame].visible = true
                        script.raise_event(defines.events.on_gui_opened, {player_index = player_index, element = e.gui.left[inputs_frame]})
                    end
                )
            local setting_tab = tab_pane.add{type = "tab",name = "setting_tab",caption = "settings"}
                local test = tab_pane.add{type = "label",name = "test",caption = "test setting"}
            tab_pane.add_tab(output_tab, output_flow)
            tab_pane.add_tab(setting_tab, test)
            tab_pane.selected_tab_index = 1
    return frame
end

function create_inputs_frame(parent, player_index)
    local frame = parent.add{name = inputs_frame, type= "frame", caption = "Input Source Select"}
        local inputs_flow = frame.add{type = "flow", direction = "vertical"}
            local inputs_table = inputs_flow.add{type = "table", column_count = 3}
                -- TODO add input recipes
            local confirm_button = inputs_flow.add{type = "button", caption = "confirm"}
        local outputs_view_flow = frame.add{type = "flow", direction = "vertical", caption = "target outputs"}
            -- TODO add output recipes
    register_gui_event_handler(frame, defines.events.on_gui_opened,
        function(e)
            inputs_flow.clear()
            outputs_view_flow.clear()
            --debug_print(key_string(global.blueprint_outputs), e.player_index)
            local graph = generate_dependency_graph(e.player_index)
            debug_print("outputs:" .. key_string(graph.outputs), e.player_index)
            debug_print("inputs:" .. key_string(graph.inputs), e.player_index)
            for k, v in pairs(graph.outputs) do
                outputs_view_flow.add{type="sprite", sprite="item/"..k}
            end
        end
    )
    return frame
end
