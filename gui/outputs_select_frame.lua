local PlayerInfo = require("player_info")

--- add a new output item selection box for player with *player_index* at *parent* gui element
--- @param parent LuaGuiElement
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
    num_field.style.maximal_width = 50
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
    PlayerInfo.update_crafting_machine_priorities(player_index)

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

local CraftingUnitSelectTab = {}

--- @param recipe_max_repetition number
--- @param gui_parent LuaGuiElement
--- @return LuaGuiElement repeat number selector
function CraftingUnitSelectTab.create_repeat_num_selector(player_index, gui_parent, repetition_num_pointer, recipe_max_repetition)
    assertAllTruthy(player_index, gui_parent, repetition_num_pointer, recipe_max_repetition)

    local repeat_num_frame = gui_parent.add { name = "repeat_num_frame", type = "frame", direction = "horizontal", caption = "Choose unit number" }
    repeat_num_frame.add { name = "repeat_num_label", type = "label", caption = "repeat unit" }
    local repeat_num_field = repeat_num_frame.add { name = "repeat_num_field", type = "textfield", numeric = true, allow_decimal = false }
    repeat_num_frame.add { name = "repeat_times_label", type = "label", caption = "times" }
    repeat_num_field.style.maximal_width = 30
    repeat_num_field.text = tostring(Pointer.get(repetition_num_pointer))
    local repeat_num_slider = repeat_num_frame.add { name = "repeat_num_slider", type = "slider", minimum_value = 1, maximum_value = 10, value = 1, value_step = 1, discrete_slider = true, discrete_values = true }
    repeat_num_slider.style.maximal_width = 80
    repeat_num_slider.set_slider_minimum_maximum(1, (recipe_max_repetition > 100) and 100 or recipe_max_repetition)
    repeat_num_frame.add { name = "max_repetition_lavel", type = "label", caption = "(capacity: " .. tostring(recipe_max_repetition) .. ")" }
    register_gui_event_handler(player_index, repeat_num_field, defines.events.on_gui_text_changed, function(e)
        local new_repeat = tonumber(e.element.text)
        if new_repeat then
            new_repeat = new_repeat > recipe_max_repetition and recipe_max_repetition or new_repeat
            if new_repeat ~= Pointer.get(repetition_num_pointer) then
                Pointer.set(repetition_num_pointer, new_repeat)
                repeat_num_slider.slider_value = new_repeat
            end
            if new_repeat ~= tonumber(e.element.text) then
                repeat_num_field.text = tostring(new_repeat)
            end
        end
    end)
    register_gui_event_handler(player_index, repeat_num_slider, defines.events.on_gui_value_changed, function(e)
        local new_repeat = math.ceil(e.element.slider_value)
        if new_repeat ~= Pointer.get(repetition_num_pointer) then
            Pointer.set(repetition_num_pointer, new_repeat)
            repeat_num_field.text = tostring(new_repeat)
        end
    end)
    return repeat_num_frame
end

--- @param gui_parent LuaGuiElement
--- @param blueprint_pointer Pointer|BlueprintSection[]
function CraftingUnitSelectTab.create_confirm_button(player_index, gui_parent, recipe, repetition_pointer)
    assertAllTruthy(player_index, gui_parent, recipe, repetition_pointer)

    local confirm_button = gui_parent.add { name = "confirm_button", type = "button", caption = "Confirm" }
    register_gui_event_handler(player_index, confirm_button, defines.events.on_gui_click, function(e)
        local new_unit, _, direction_spec = AssemblerNode.new({ recipe = recipe, player_index = e.player_index }):generate_crafting_unit()
        local blueprint_section = new_unit:repeat_self(Pointer.get(repetition_pointer))
        blueprint_section:rotate(direction_spec.blueprintRotation)
        local blueprint = PlayerInfo.insert_blueprint(e.player_index, blueprint_section.entities)
        if blueprint then
            blueprint.label = recipe.name .. " crafting unit"
            game.players[e.player_index].print("blueprint \"" .. blueprint.label .. "\" created.")
        end
        remove_gui(e.player_index, main_function_frame)
    end)
    return confirm_button
end

local direction_table = { [0] = "hint_arrow_up", [2] = "hint_arrow_right", [4] = "hint_arrow_down", [6] = "hint_arrow_left" }
local function direction_sprite(direction)
    return direction_table[direction] and ("utility/" .. direction_table[direction]) or nil
end

--- @param gui_parent LuaGuiElement
--- @return LuaGuiElement
function CraftingUnitSelectTab.create_direction_select_frame(player_index, gui_parent, crafting_machine_name)
    assertAllTruthy(player_index, gui_parent, crafting_machine_name)

    local direction_frame = gui_parent.add { name = "direction_select_frame", type = "frame", direction = "vertical", caption = "Choose flow direction" }
    do
        direction_frame.add { name = "belt_direction_label", type = "label", caption = "Change input direction by clicking arrows in edges" }
        direction_frame.add { name = "output_direction_label", type = "label", caption = "Change output direction by clicking arrows in corners" }
        local choose_direction_tables_flow = direction_frame.add { name = "choose_direction_tables_flow", type = "flow", direction = "horizontal" }
        do
            --- @type table<defines.direction, LuaGuiElement>
            local preview_sprites = {}
            --- @type table<defines.direction, LuaGuiElement>
            local direction_buttons = {}

            --- update the direction preference for the player
            --- @param pressed_button_pos defines.direction position of the button that's pressed
            local function update_direction_preference(pressed_button_pos)
                local direction_spec = PlayerInfo.direction_settings(player_index)
                if pressed_button_pos % 2 == 0 then
                    direction_spec.ingredientDirection = Vector2D.fromDirection(pressed_button_pos):reverse():toDirection()
                    -- if pressed button is input direction button, update the position and direction of outputs
                    local direction_shift = (pressed_button_pos % 4 == 0) and -1 or 1
                    for output_button_pos = 1, 7, 2 do
                        local new_output_direction = (output_button_pos + direction_shift) % 8
                        direction_buttons[output_button_pos].sprite = direction_sprite(new_output_direction)
                        if preview_sprites[output_button_pos].sprite ~= "" then
                            preview_sprites[output_button_pos].sprite = direction_buttons[output_button_pos].sprite
                            direction_spec.productDirection = new_output_direction
                            direction_spec.productPosition = (new_output_direction - 2 * direction_shift) % 8
                        end
                        direction_shift = direction_shift * -1
                    end
                else
                    local input_button_pos
                    for i = 0, 6, 2 do
                        if preview_sprites[i].sprite ~= "" then
                            input_button_pos = i
                            break
                        end
                    end
                    local input_direction_vector = Vector2D.fromDirection(input_button_pos):reverse()
                    local output_button_pos_vector = Vector2D.fromDirection(pressed_button_pos)
                    direction_spec.productDirection = Vector2D.new(
                            input_direction_vector.x == 0 and 0 or output_button_pos_vector.x,
                            input_direction_vector.y == 0 and 0 or output_button_pos_vector.y
                    )                                         :toDirection()
                    direction_spec.productPosition = Vector2D.new(
                            input_direction_vector.x == 0 and output_button_pos_vector.x or 0,
                            input_direction_vector.y == 0 and output_button_pos_vector.y or 0
                    )                                        :toDirection()
                end
                preview_sprites[pressed_button_pos].sprite = direction_buttons[pressed_button_pos].sprite
                for other_same_type_button_offset = 2, 6, 2 do
                    preview_sprites[(pressed_button_pos + other_same_type_button_offset) % 8].sprite = nil
                end
            end

            local belt_direction_table = choose_direction_tables_flow.add { name = "belt_direction_table", type = "table", column_count = 3 }
            belt_direction_table.style.left_margin = 20
            for _, direction in ipairs({ 7, 0, 1, 6, -1, 2, 5, 4, 3 }) do
                if direction >= 0 then
                    -- 4 inputs direction button should reverse its arrow direction, other 4 outputs direction button should stay the same
                    local arrow_direction = (direction % 2 == 0) and ((direction + 4) % 8) or direction
                    direction_buttons[direction] = belt_direction_table.add { type = "sprite-button", name = "direction_button_" .. tostring(direction), sprite = direction_sprite(arrow_direction) }
                    register_gui_event_handler(player_index, direction_buttons[direction], defines.events.on_gui_click, function()
                        -- create a mapping from (4 input direction + 4 output direction) to (inputs belt left/right + outputs belt left/right + 4 rotation)
                        update_direction_preference(direction)
                    end)
                else
                    -- center of the table is a crafting machine icon
                    belt_direction_table.add { type = "sprite-button", name = "crafting_machine_sprite", sprite = sprite_of(crafting_machine_name), ignored_by_interaction = true }
                end
            end
            local preview_flow = choose_direction_tables_flow.add { name = "preview_frame", type = "table", direction = "vertical", column_count = 1, draw_horizontal_line_after_headers = true }
            preview_flow.style.left_margin = 20
            do
                preview_flow.add { name = "preview_label", type = "label", caption = "Preview" }
                local preview_table = preview_flow.add { name = "preview_table", type = "table", column_count = 3 }
                local sprite_size = 28
                for _, direction in ipairs({ 7, 0, 1, 6, -1, 2, 5, 4, 3 }) do
                    if direction >= 0 then
                        preview_sprites[direction] = preview_table.add { type = "sprite", name = "direction_" .. tostring(direction) }
                        preview_sprites[direction].style.minimal_height = sprite_size
                        preview_sprites[direction].style.minimal_width = sprite_size
                        preview_sprites[direction].style.stretch_image_to_widget_size = true
                    else
                        -- center of the table is a crafting machine icon
                        local crafting_machine_sprite = preview_table.add { type = "sprite", name = "crafting_machine_sprite", sprite = sprite_of(crafting_machine_name), ignored_by_interaction = true }
                        crafting_machine_sprite.style.minimal_height = sprite_size
                        crafting_machine_sprite.style.minimal_width = sprite_size
                        crafting_machine_sprite.style.stretch_image_to_widget_size = true
                    end
                end
            end

            -- Preset default direction preference
            update_direction_preference(defines.direction.west)
            update_direction_preference(defines.direction.northeast)
        end
    end
    return direction_frame
end

--- @param tab_pane LuaGuiElement
local function create_crafting_unit_select_tab(player_index, tab_pane)
    --- @type BlueprintSection[]

    local crafting_unit_tab = tab_pane.add { type = "tab", name = "crafting_unit_tab", caption = "crafting unit" }
    local crafting_unit_flow = tab_pane.add { type = "flow", name = "crafting_unit_flow", direction = "vertical" }
    do
        crafting_unit_flow.add { name = "recipe_select_label", type = "label", caption = "Select your new crafting unit's recipe:" }
        local choose_button = crafting_unit_flow.add { name = "recipe_choose_button", type = "choose-elem-button", elem_type = "recipe", elem_filters = {
            enabled = true
        } }

        local direction_frame, repeat_num_selector, confirm_button
        register_gui_event_handler(player_index, choose_button, defines.events.on_gui_elem_changed, function(e)
            remove_gui(player_index, direction_frame)
            direction_frame = nil
            remove_gui(player_index, repeat_num_selector)
            repeat_num_selector = nil
            remove_gui(player_index, confirm_button)
            confirm_button = nil
            if e.element.elem_value then
                local recipe = game.recipe_prototypes[e.element.elem_value]
                local blueprint, max_repetition_num = AssemblerNode.new({ recipe = recipe, player_index = e.player_index }):generate_crafting_unit()
                if blueprint and max_repetition_num then
                    direction_frame = CraftingUnitSelectTab.create_direction_select_frame(player_index, crafting_unit_flow, PlayerInfo.get_crafting_machine_prototype(player_index, recipe).name)
                    local repetition_pointer = Pointer.new(1)
                    if max_repetition_num > 1 then
                        repeat_num_selector = CraftingUnitSelectTab.create_repeat_num_selector(player_index, crafting_unit_flow, repetition_pointer, max_repetition_num)
                    end
                    confirm_button = CraftingUnitSelectTab.create_confirm_button(player_index, crafting_unit_flow, recipe, repetition_pointer)
                end
            end
        end)

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
