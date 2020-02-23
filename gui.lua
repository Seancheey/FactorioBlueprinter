require("helper")
require("blueprint_gen")
require("guilib")
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

function create_blueprinter_button(player_index, parent)
    local button = parent.add{
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = main_button
    }
    register_gui_event_handler(player_index,button, defines.events.on_gui_click,
        function(e)
            e.gui.left[main_frame].visible = not e.gui.left[main_frame].visible
            e.gui.left[inputs_frame].visible = false
        end
    )
end


function create_new_output_item_choice(parent, player_index)
    local row_num = #global.blueprint_outputs[player_index] + 1
    global.blueprint_outputs[player_index][row_num] = {crafting_speed = 1, unit=output_units[1]}
    local choose_button = parent.add{name = "bp_output_choose_button"..tostring(row_num), type = "choose-elem-button", elem_type = "recipe"}
    register_gui_event_handler(player_index,choose_button, defines.events.on_gui_elem_changed,
        function(e, global, env)
            global.blueprint_outputs[e.player_index][env.row_num].ingredient = e.element.elem_value
            -- expand table if full
            if env.newtable(global.blueprint_outputs[e.player_index]):all(function(x) return x.ingredient end) then
                create_new_output_item_choice(elem_of(env.parent_path, e.gui), e.player_index)
            end
            -- any change to output makes next frame invisible
            e.gui.left[inputs_frame].visible = false
        end
    , {row_num = row_num, parent_path = path_of(parent)})
    local numfield = parent.add{name = "bp_output_numfield"..tostring(row_num),type = "textfield", text = "1", numeric = true, allow_negative = false}
    register_gui_event_handler(player_index,numfield, defines.events.on_gui_text_changed,
        function(e)
            item_choice.crafting_speed = (e.element.text ~= "" and tonumber(e.element.text) or 0) / unit_values[item_choice.unit]
        end
    )
    local unitbox = parent.add{name = "bp_output_dropdown"..tostring(row_num), type = "drop-down", items = output_units, selected_index = 1}
    register_gui_event_handler(player_index,unitbox, defines.events.on_gui_selection_state_changed,
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
        local tab_pane = frame.add{type = "tabbed-pane",name = "outputs_tab_pane", caption = "outputs",direction = "vertical"}
            local output_tab = tab_pane.add{type = "tab",name = "outputs_tab",caption = "outputs"}
            local output_flow = tab_pane.add{type = "flow", name = "output_flow", direction = "vertical"}
                local output_table = output_flow.add{type = "table", name = "output_table", caption = "select output items",column_count = 3}
                    create_new_output_item_choice(output_table, player_index)
                local confirm_button = output_flow.add{name = "bp_output_confirm_button", type = "button", caption = "confirm"}
                register_gui_event_handler(player_index,confirm_button, defines.events.on_gui_click,
                    function(e)
                        e.gui.left[inputs_frame].visible = true
                        script.raise_event(defines.events.on_gui_opened, {player_index = player_index, element = e.gui.left[inputs_frame]})
                    end
                )
            local setting_tab = tab_pane.add{type = "tab",name = "setting_tab",caption = "settings"}
                local vertical_flow = tab_pane.add{type = "flow", name="vertical_flow",direction = "vertical"}
                    local assembler_choose_label = vertical_flow.add{type = "label", caption = "Preferred assembling machine"}
                    local assembler_choose_table = vertical_flow.add{type = "table", name="choose_table" , column_count = 6}
                        local choose_buttons = {}
                        for i = 1,3 do
                            assembler_choose_table.add{type = "sprite", sprite = sprite_of("assembling-machine-"..tostring(i))}
                            choose_buttons[i] = assembler_choose_table.add{name = "bp_setting_choose_assembler_button"..tostring(i), type = "radiobutton", state = global.settings[player_index].assembler == i}
                            register_gui_event_handler(player_index,choose_buttons[i], defines.events.on_gui_click,
                                function(e)
                                    global.settings[player_index].assembler = i
                                    for other = 1,3 do
                                        if other ~= i then
                                            choose_buttons[other].state = false
                                        end
                                    end
                                end
                            )
                        end
            tab_pane.add_tab(output_tab, output_flow)
            tab_pane.add_tab(setting_tab, vertical_flow)
            tab_pane.selected_tab_index = 1
    return frame
end

function create_input_buttons(player_index, gui_parent, graph)
    for ingredient_name, node in pairs(graph.inputs) do
        local left_button = gui_parent.add{type="sprite-button", sprite="utility/left_arrow", tooltip="use it's ingredient instead"}
        local ingredient_sprite = gui_parent.add{type="sprite", sprite=sprite_of(ingredient_name)}
        local right_button = gui_parent.add{type="sprite-button", sprite="utility/right_arrow", tooltip = "use it's targets instead"}
        register_gui_event_handler(player_index,left_button, defines.events.on_gui_click,
            function (e)
                graph:use_ingredients_as_input(ingredient_name)
                gui_parent.clear()
                create_input_buttons(player_index, gui_parent, graph)
            end
        )
        register_gui_event_handler(player_index,right_button, defines.events.on_gui_click,
            function (e)
                graph:use_products_as_input(ingredient_name)
                gui_parent.clear()
                create_input_buttons(player_index, gui_parent, graph)
            end
        )
    end
end

function create_inputs_frame(parent, player_index)
    local frame = parent.add{name = inputs_frame, type= "frame", caption = "Input Source Select", direction = "vertical"}
        local hori_flow = frame.add{type = "table", name = "hori_flow", column_count = 2}
            local input_select_frame = hori_flow.add{type = "frame", name = "input_select_frame", caption = "Input Items Select"}
                local inputs_flow = input_select_frame.add{type = "flow", name = "inputs_flow", direction = "vertical"}
                    local inputs_table = inputs_flow.add{type = "table", name = "inputs_table", column_count = 3}
                inputs_flow.style.vertically_stretchable = true
            local outputs_frame = hori_flow.add{type = "frame", caption = "Final Products"}
                local outputs_view_flow = outputs_frame.add{type = "flow", direction = "vertical", caption = "target outputs"}
                outputs_view_flow.style.vertically_stretchable = true
        local confirm_button = frame.add{type = "button", name = "confirm_button", caption = "confirm"}
    register_gui_event_handler(player_index, frame, defines.events.on_gui_opened,
        function(e)
            local graph = BlueprintGraph.new()
            register_gui_event_handler(player_index,confirm_button, defines.events.on_gui_click,
                function(e)
                    game.players[e.player_index].insert("blueprint")
                    local item = game.players[e.player_index].get_main_inventory().find_item_stack("blueprint")
                    graph:generate_blueprint(item)
                end
            )

            graph:generate_graph_by_outputs(global.blueprint_outputs[e.player_index])

            -- update outputs view
            outputs_view_flow.clear()
            for output_name, _ in pairs(graph.outputs) do
                outputs_view_flow.add{type="sprite", sprite=sprite_of(output_name)}
            end

            -- update inputs view
            inputs_table.clear()
            create_input_buttons(player_index, inputs_table, graph)
        end
    )
    return frame
end
