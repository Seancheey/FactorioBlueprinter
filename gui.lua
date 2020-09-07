require("helper")
require("blueprint_gen")
require("guilib")
main_button = "bp-main-button"
main_frame = "bp-outputs-frame"
inputs_frame = "bp-inputs-frame"
unit_values = {["item/s"] = 1, ["item/min"] = 60}
output_units = {"item/s", "item/min"}

-- clear all mod guis in gui_area associated with this mod
function clear_gui_area(gui_area)
    for _, to_remove in ipairs{main_frame,inputs_frame} do
        if gui_area[to_remove] then
            gui_area[to_remove].destroy()
        end
    end
end

-- initialize gui of player with player_index at gui_area
-- @param gui_area optional, default to player's gui left side
function init_player_gui(player_index, gui_area)
    local player_gui_area = gui_area or game.players[player_index].gui.left
    clear_gui_area(player_gui_area)
    __create_blueprinter_button(player_index, player_gui_area)
end

function __create_blueprinter_button(player_index, parent)
    local button = parent.add{
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = main_button
    }
end

function __create_new_output_item_choice(player_index, parent)
    local row_num = #global.blueprint_outputs[player_index] + 1
    global.blueprint_outputs[player_index][row_num] = {crafting_speed = 1, unit=output_units[1]}
    local choose_button = parent.add{name = "bp_output_choose_button"..tostring(row_num), type = "choose-elem-button", elem_type = "recipe"}
    register_gui_event_handler(player_index,choose_button, defines.events.on_gui_elem_changed,
        function(e)
            global.blueprint_outputs[e.player_index][row_num].ingredient = e.element.elem_value
            -- expand table if full
            if newtable(global.blueprint_outputs[e.player_index]):all(function(x) return x.ingredient end) then
                __create_new_output_item_choice(e.player_index,parent)
            end
            -- any change to output makes next frame invisible
            e.gui.left[inputs_frame].visible = false
        end
    , {row_num = row_num, parent_path = path_of(parent)})
    local numfield = parent.add{name = "bp_output_numfield"..tostring(row_num),type = "textfield", text = "1", numeric = true, allow_negative = false}
    register_gui_event_handler(player_index,numfield, defines.events.on_gui_text_changed,
        function(e)
            local item_choice = global.blueprint_outputs[e.player_index][row_num]
            item_choice.crafting_speed = (e.element.text ~= "" and tonumber(e.element.text) or 0) / unit_values[item_choice.unit]
        end
    , {row_num = row_num})
    local unit_box = parent.add{ name = "bp_output_dropdown"..tostring(row_num), type = "drop-down", items = output_units, selected_index = 1}
    register_gui_event_handler(player_index, unit_box, defines.events.on_gui_selection_state_changed,
        function(e)
            local item_choice = global.blueprint_outputs[e.player_index][row_num]
            item_choice.unit = output_units[e.element.selected_index]
            -- recalculate item crafting speed according to new unit
            local new_num = item_choice.crafting_speed*unit_values[item_choice.unit]
            elem_of(field_path, e.gui).text = tostring(new_num)
        end
    , {row_num = row_num, output_units = output_units, unit_values=unit_values, field_path = path_of(numfield)})
end

function __create_outputs_frame(player_index, parent)
    local frame = parent.add{type = "frame",name = main_frame,caption = "Blueprinter"}
        local tab_pane = frame.add{type = "tabbed-pane",name = "outputs_tab_pane", caption = "outputs",direction = "vertical"}
            local output_tab = tab_pane.add{type = "tab",name = "outputs_tab",caption = "outputs"}
            local output_flow = tab_pane.add{type = "flow", name = "output_flow", direction = "vertical"}
                local output_table = output_flow.add{type = "table", name = "output_table", caption = "select output items",column_count = 3}
                    __create_new_output_item_choice(player_index, output_table)
                local confirm_button = output_flow.add{name = "bp_output_confirm_button", type = "button", caption = "confirm"}
                register_gui_event_handler(player_index,confirm_button, defines.events.on_gui_click,
                    function(e)
                        e.gui.left[inputs_frame].visible = true
                        __update_input_frame(e.player_index)
                    end
                , {inputs_frame = inputs_frame})
            local setting_tab = tab_pane.add{type = "tab",name = "setting_tab",caption = "settings"}
                local vertical_flow = tab_pane.add{type = "flow", name="vertical_flow",direction = "vertical"}
                    local priority_label = vertical_flow.add{type = "label", name="priority_label", caption = "Factory Priorities", tooltip = "Factories in front will be picked to generate blueprints first"}
                    local priority_table = vertical_flow.add{type = "table", name="priority_table", column_count = 8}
                        for i, factory in ipairs(global.settings[player_index].factory_priority) do
                            priority_table.add{type = "sprite", name = "sprite_"..tostring(i), sprite = sprite_of(factory.name)}
                            local factory_button = priority_table.add{type = "sprite-button", name = "sort_up_"..tostring(i), sprite = "utility/left_arrow"}
                            register_gui_event_handler(player_index, factory_button, defines.events.on_gui_click,
                                function(e)
                                    -- eliminate first button
                                    if i <= 1 then return end
                                    -- sway global setting
                                    local priority = global.settings[e.player_index].factory_priority
                                    local this = priority[i]
                                    local swapped = priority[i-1]
                                    priority[i] = swapped
                                    priority[i-1] = this
                                    -- sway gui
                                    elem_of(parent_path.."|sprite_"..tostring(i),e.gui).sprite = sprite_of(swapped.name)
                                    elem_of(parent_path.."|sprite_"..tostring(i-1),e.gui).sprite = sprite_of(this.name)
                                end
                            , {i=i, parent_path = path_of(priority_table)})
                        end

                    local belt_label = vertical_flow.add{type = "label", name = "belt_label", caption="Belt Preference"}
                    local belt_choose_table = vertical_flow.add{type = "table", name="choose_table" , column_count = 2*#ALL_BELTS}
                        for i,belt_name in ipairs(ALL_BELTS) do
                            belt_choose_table.add{type = "sprite", sprite = sprite_of(belt_name)}
                            local choose_button = belt_choose_table.add{name = "bp_setting_choose_belt_button"..tostring(i), type = "radiobutton", state = global.settings[player_index].belt == i}
                            register_gui_event_handler(player_index,choose_button, defines.events.on_gui_click,
                                function(e)
                                    global.settings[e.player_index].belt = i
                                    for other = 1,3 do
                                        if other ~= i then
                                            elem_of(parent_path.."|bp_setting_choose_belt_button"..tostring(other), e.gui).state = false
                                        end
                                    end
                                end
                            , {i=i, parent_path = path_of(belt_choose_table)})
                        end
            tab_pane.add_tab(output_tab, output_flow)
            tab_pane.add_tab(setting_tab, vertical_flow)
            tab_pane.selected_tab_index = 1
end

function __create_input_buttons(player_index, gui_parent)
    for ingredient_name, node in pairs(global.blueprint_graph[player_index].inputs) do
        local left_button = gui_parent.add{type="sprite-button", name = "left_button_"..ingredient_name, sprite="utility/left_arrow", tooltip="use it's ingredient instead"}
        local ingredient_sprite = gui_parent.add{type="sprite", name = "sprite_"..ingredient_name, sprite=sprite_of(ingredient_name)}
        local right_button = gui_parent.add{type="sprite-button", name = "right_button_"..ingredient_name, sprite="utility/right_arrow", tooltip = "use it's targets instead"}
        register_gui_event_handler(player_index,left_button, defines.events.on_gui_click,
            function(e)
                BlueprintGraph.use_ingredients_as_input(global.blueprint_graph[e.player_index], ingredient_name)
                local gui_parent = elem_of(parent_path, e.gui)
                unregister_gui_children_event_handler(e.player_index, gui_parent, defines.events.on_gui_click)
                gui_parent.clear()
                __create_input_buttons(player_index, gui_parent, global.blueprint_graph[e.player_index])
            end
        , {parent_path = path_of(gui_parent), BlueprintGraph = BlueprintGraph})
        register_gui_event_handler(player_index,right_button, defines.events.on_gui_click,
            function(e)
                BlueprintGraph.use_products_as_input(global.blueprint_graph[e.player_index], ingredient_name)
                local gui_parent = elem_of(parent_path, e.gui)
                unregister_gui_children_event_handler(e.player_index, gui_parent, defines.events.on_gui_click)
                gui_parent.clear()
                __create_input_buttons(player_index, gui_parent, global.blueprint_graph[e.player_index])
            end
        , {parent_path = path_of(gui_parent), BlueprintGraph = BlueprintGraph})
    end
end

function __create_inputs_frame(player_index, parent)
    local frame = parent.add{name = inputs_frame, type= "frame", caption = "Input Source Select", direction = "vertical"}
        local hori_flow = frame.add{type = "table", name = "hori_flow", column_count = 2}
            local input_select_frame = hori_flow.add{type = "frame", name = "input_select_frame", caption = "Input Items Select"}
                local inputs_flow = input_select_frame.add{type = "flow", name = "inputs_flow", direction = "vertical"}
                    local inputs_table = inputs_flow.add{type = "table", name = "inputs_table", column_count = 3}
                    global.inputs_table_path = path_of(inputs_table)
                inputs_flow.style.vertically_stretchable = true
            local outputs_frame = hori_flow.add{type = "frame", name = "outputs_frame", caption = "Final Products"}
                local outputs_view_flow = outputs_frame.add{type = "flow", name = "outputs_view_flow",direction = "vertical", caption = "target outputs"}
                global.output_view_path = path_of(outputs_view_flow)
                outputs_view_flow.style.vertically_stretchable = true
        local confirm_button = frame.add{type = "button", name = "confirm_button", caption = "confirm"}
        register_gui_event_handler(
            player_index,
            confirm_button,
            defines.events.on_gui_click,
            function(e)
                game.players[e.player_index].insert("blueprint")
                local item = game.players[e.player_index].get_main_inventory().find_item_stack("blueprint")
                BlueprintGraph.generate_blueprint(global.blueprint_graph[e.player_index], e.player_index, item)
            end
        ,{BlueprintGraph = BlueprintGraph})
end

function __update_input_frame(player_index)
    local graph = BlueprintGraph.new()
    global.blueprint_graph[player_index] = graph

    graph:generate_graph_by_outputs(global.blueprint_outputs[player_index])
    local gui = game.players[player_index].gui
    -- update outputs view
    elem_of(global.output_view_path, gui).clear()
    for output_name, _ in pairs(graph.outputs) do
        elem_of(global.output_view_path, gui).add{type="sprite", sprite=sprite_of(output_name)}
    end

    -- update inputs view
    local inputs_table = elem_of(global.inputs_table_path, gui)
    unregister_gui_children_event_handler(player_index, inputs_table, defines.events.on_gui_click)
    inputs_table.clear()
    __create_input_buttons(player_index, inputs_table, graph)
end
