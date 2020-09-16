--- add a new output item selection box for player with *player_index* at *parent* gui element
local function add_output_item_selection_box(player_index, parent, outputs_specifications)
    assertAllTruthy(player_index, parent, outputs_specifications)

    local row_num = #outputs_specifications + 1
    outputs_specifications[row_num] = { crafting_speed = 1, unit = output_units[1] }
    local choose_button = parent.add { name = "bp_output_choose_button" .. tostring(row_num), type = "choose-elem-button", elem_type = "recipe" }
    register_gui_event_handler(player_index, choose_button, defines.events.on_gui_elem_changed,
            function(e)
                outputs_specifications[row_num].ingredient = e.element.elem_value
                -- expand table if full
                if outputs_specifications:all(function(x)
                    return x.ingredient
                end) then
                    add_output_item_selection_box(e.player_index, parent, outputs_specifications)
                end
                -- any change to output makes input frame disappear
                remove_gui(e.player_index, inputs_select_frame)
            end
    )
    local num_field = parent.add { name = "bp_output_numfield" .. tostring(row_num), type = "textfield", text = "1", numeric = true, allow_negative = false }
    register_gui_event_handler(player_index, num_field, defines.events.on_gui_text_changed,
            function(e)
                local item_choice = outputs_specifications[row_num]
                item_choice.crafting_speed = (e.element.text ~= "" and tonumber(e.element.text) or 0) / unit_values[item_choice.unit]
            end
    )
    local unit_box = parent.add { name = "bp_output_dropdown" .. tostring(row_num), type = "drop-down", items = output_units, selected_index = 1 }
    register_gui_event_handler(player_index, unit_box, defines.events.on_gui_selection_state_changed,
            function(e)
                local item_choice = outputs_specifications[row_num]
                item_choice.unit = output_units[e.element.selected_index]
                -- recalculate item crafting speed according to new unit
                local new_num = item_choice.crafting_speed * unit_values[item_choice.unit]
                num_field.text = tostring(new_num)
            end
    )
end

local function create_settings_tab(player_index, tab_pane)
    update_player_crafting_machine_priorities(player_index)

    local setting_tab = tab_pane.add { type = "tab", name = "setting_tab", caption = "settings" }
    local vertical_flow = tab_pane.add { type = "flow", name = "vertical_flow", direction = "vertical" }
    vertical_flow.add { type = "label", name = "priority_label", caption = "Factory Priorities", tooltip = "Factories in front will be picked to generate blueprints first" }
    local priority_table = vertical_flow.add { type = "table", name = "priority_table", column_count = 8 }
    for i, factory in ipairs(global.settings[player_index].factory_priority) do
        priority_table.add { type = "sprite", name = "sprite_" .. tostring(i), sprite = sprite_of(factory.name) }
        local factory_button = priority_table.add { type = "sprite-button", name = "sort_up_" .. tostring(i), sprite = "utility/left_arrow" }
        register_gui_event_handler(player_index, factory_button, defines.events.on_gui_click,
                function(e)
                    -- eliminate first button
                    if i <= 1 then
                        return
                    end
                    -- swap global setting
                    local priority = global.settings[e.player_index].factory_priority
                    local this = priority[i]
                    local swapped = priority[i - 1]
                    priority[i] = swapped
                    priority[i - 1] = this
                    -- swap gui
                    elem_of(path_of(priority_table) .. "|sprite_" .. tostring(i), e.player_index).sprite = sprite_of(swapped.name)
                    elem_of(path_of(priority_table) .. "|sprite_" .. tostring(i - 1), e.player_index).sprite = sprite_of(this.name)
                end
        )
    end

    vertical_flow.add { type = "label", name = "belt_label", caption = "Belt Preference" }
    local belt_choose_table = vertical_flow.add { type = "table", name = "choose_table", column_count = 2 * #ALL_BELTS }
    for i, belt_name in ipairs(ALL_BELTS) do
        belt_choose_table.add { type = "sprite", sprite = sprite_of(belt_name) }
        local choose_button = belt_choose_table.add { name = "bp_setting_choose_belt_button" .. tostring(i), type = "radiobutton", state = global.settings[player_index].belt == i }
        register_gui_event_handler(player_index, choose_button, defines.events.on_gui_click,
                function(e)
                    global.settings[e.player_index].belt = i
                    for other = 1, 3 do
                        if other ~= i then
                            elem_of(path_of(belt_choose_table) .. "|bp_setting_choose_belt_button" .. tostring(other), e.player_index).state = false
                        end
                    end
                end
        )
    end
    tab_pane.add_tab(setting_tab, vertical_flow)
end

local function create_outputs_select_tab(player_index, tab_pane)
    --- @type OutputSpec[] player's specified blueprint outputs
    local output_specifications = toArrayList {}

    local output_tab = tab_pane.add { type = "tab", name = "outputs_tab", caption = "whole factory" }
    local output_flow = tab_pane.add { type = "flow", name = "output_flow", direction = "vertical" }
    local output_table = output_flow.add { type = "table", name = "output_table", caption = "select output items", column_count = 3 }
    add_output_item_selection_box(player_index, output_table, output_specifications)
    local confirm_button = output_flow.add { name = "bp_output_confirm_button", type = "button", caption = "confirm" }
    register_gui_event_handler(player_index, confirm_button, defines.events.on_gui_click,
            function(e)
                remove_gui(e.player_index, inputs_select_frame)
                create_inputs_select_frame(e.player_index, output_specifications)
            end
    )
    tab_pane.add_tab(output_tab, output_flow)
end

--- @param tab_pane LuaGuiElement
local function create_crafting_unit_select_tab(player_index, tab_pane)
    local crafting_unit_tab = tab_pane.add { type = "tab", name = "crafting_unit_tab", caption = "crafting unit" }
    local crafting_unit_flow = tab_pane.add { type = "flow", name = "crafting_unit_flow", direction = "vertical" }
    do
        crafting_unit_flow.add { name = "belt_direction_label", type = "label", caption = "Select crafting unit's belt direction:" }
        local belt_direction_table = crafting_unit_flow.add { name = "belt_direction_table", type = "table", column_count = 4 }
        do
            local belt_direction_preference = PlayerInfo.get_belt_direction(player_index)
            belt_direction_table.add { name = "left_label", type = "label", caption = "left" }
            local left_button = belt_direction_table.add { name = "left_button", type = "radiobutton", state = belt_direction_preference == defines.direction.west }

            belt_direction_table.add { name = "right_label", type = "label", caption = "right" }
            local right_button = belt_direction_table.add { name = "right_button", type = "radiobutton", state = belt_direction_preference == defines.direction.east }

            register_gui_event_handler(player_index, left_button, defines.events.on_gui_click, function(e)
                left_button.state = true
                right_button.state = false
                PlayerInfo.set_belt_direction(e.player_index, defines.direction.west)
            end)

            register_gui_event_handler(player_index, right_button, defines.events.on_gui_click, function(e)
                left_button.state = false
                right_button.state = true
                PlayerInfo.set_belt_direction(e.player_index, defines.direction.east)
            end)
        end
        crafting_unit_flow.add { name = "recipe_select_label", type = "label", caption = "Select your new crafting unit's recipe:" }
        local choose_button = crafting_unit_flow.add { name = "recipe_choose_button", type = "choose-elem-button", elem_type = "recipe", elem_filters = {
            enabled = true
        } }
        register_gui_event_handler(player_index, choose_button, defines.events.on_gui_elem_changed,
                function(e)
                    local recipe = game.recipe_prototypes[e.element.elem_value]
                    local blueprint_section, max_repetition = AssemblerNode.new({ recipe = recipe, player_index = e.player_index }):generate_crafting_unit()
                    if blueprint_section then
                        local blueprint = insert_blueprint(e.player_index, blueprint_section.entities)
                        if blueprint then
                            blueprint.label = recipe.name .. " crafting unit"
                            game.players[e.player_index].print("blueprint created. You can repeat this unit " .. tostring(max_repetition) .. " times to reach it's full belt capacity.")
                        end
                    end
                    remove_gui(e.player_index, main_function_frame)
                end
        )

    end
    tab_pane.add_tab(crafting_unit_tab, crafting_unit_flow)
end

function create_main_function_frame(player_index)
    assertAllTruthy(player_index)

    local frame = gui_root(player_index).add { type = "frame", name = main_function_frame, caption = "Blueprinter" }
    local tab_pane = frame.add { type = "tabbed-pane", name = "outputs_tab_pane", caption = "outputs", direction = "vertical" }

    create_crafting_unit_select_tab(player_index, tab_pane)
    create_outputs_select_tab(player_index, tab_pane)
    create_settings_tab(player_index, tab_pane)
    tab_pane.selected_tab_index = 1
end
