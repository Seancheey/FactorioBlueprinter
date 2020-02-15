require("helper")
require("blueprint_gen")
main_button = "bp-main-button"
main_frame = "bp-outputs-frame"
inputs_frame = "bp-inputs-frame"
unit_values = {["item/s"] = 1, ["item/min"] = 60}
output_units = {"item/s", "item/min"}

-- clear all mod guis
function clear_mod_gui(player)
    for _, to_remove in ipairs{main_button,main_frame,inputs_frame} do
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
            item_choice.ingredient = e.element.elem_value
            -- expand table if full
            if outputs_table:all(function(x) return x.ingredient end) then
                create_new_output_item_choice(parent, player_index)
            end
            -- any change to output makes next frame invisible
            e.gui.left[inputs_frame].visible = false
        end
    )
    local numfield = parent.add{type = "textfield", text = "1", numeric = true, allow_negative = false}
    register_gui_event_handler(numfield, defines.events.on_gui_text_changed,
        function(e)
            item_choice.crafting_speed = (e.element.text ~= "" and tonumber(e.element.text) or 0) / unit_values[item_choice.unit]
        end
    )
    local unitbox = parent.add{type = "drop-down", items = output_units, selected_index = 1}
    register_gui_event_handler(unitbox, defines.events.on_gui_selection_state_changed,
        function(e)
            item_choice.unit = output_units[e.element.selected_index]
            -- recalculate item crafting speed according to new unit
            local new_num = item_choice.crafting_speed*unit_values[item_choice.unit]
            numfield.text = tostring(new_num)
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

function create_input_buttons(gui_parent, graph)
    for ingredient_name, node in pairs(graph.inputs) do
        local left_button = gui_parent.add{type="sprite-button", sprite="utility/left_arrow", tooltip="use it's ingredient instead"}
        local ingredient_sprite = gui_parent.add{type="sprite", sprite=sprite_of(ingredient_name)}
        local right_button = gui_parent.add{type="sprite-button", sprite="utility/right_arrow", tooltip = "use it's targets instead"}
        register_gui_event_handler(left_button, defines.events.on_gui_click,
            function (e)
                graph:use_ingredients_as_input(ingredient_name)
                gui_parent.clear()
                create_input_buttons(gui_parent, graph)
            end
        )
        register_gui_event_handler(right_button, defines.events.on_gui_click,
            function (e)
                graph:use_products_as_input(ingredient_name)
                gui_parent.clear()
                create_input_buttons(gui_parent, graph)
            end
        )
    end
end

function create_inputs_frame(parent, player_index)
    local frame = parent.add{name = inputs_frame, type= "frame", caption = "Input Source Select", direction = "vertical"}
        local hori_flow = frame.add{type = "table", column_count = 2}
            local input_select_frame = hori_flow.add{type = "frame", caption = "Input Items Select"}
                local inputs_flow = input_select_frame.add{type = "flow", direction = "vertical"}
                    local inputs_table = inputs_flow.add{type = "table", column_count = 3}
                inputs_flow.style.vertically_stretchable = true
            local outputs_frame = hori_flow.add{type = "frame", caption = "Final Products"}
                local outputs_view_flow = outputs_frame.add{type = "flow", direction = "vertical", caption = "target outputs"}
                outputs_view_flow.style.vertically_stretchable = true
        local confirm_button = frame.add{type = "button", caption = "confirm"}
    register_gui_event_handler(frame, defines.events.on_gui_opened,
        function(e)
            local graph = BlueprintGraph.new()
            graph:generate_graph_by_outputs(global.blueprint_outputs[e.player_index])

            -- update outputs view
            outputs_view_flow.clear()
            for output_name, _ in pairs(graph.outputs) do
                outputs_view_flow.add{type="sprite", sprite=sprite_of(output_name)}
            end

            -- update inputs view
            inputs_table.clear()
            create_input_buttons(inputs_table, graph)
        end
    )
    return frame
end
