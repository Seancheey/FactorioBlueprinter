require("prototype_info")
--- @type Logger
local logging = require("__MiscLib__/logging")
--- @type ArrayList
local ArrayList = require("__MiscLib__/array_list")
--- @type Vector2D
local Vector2D = require("__MiscLib__/vector2d")
local PlayerInfo = require("player_info")
local PrototypeInfo = require("prototype_info")
local BlueprintGeneratorUtil = require("blueprint_gen.util")
local average_amount_of = BlueprintGeneratorUtil.average_amount_of
--- @type BlueprintSection
local BlueprintSection = require("blueprint_gen.blueprint_section")

--- @class AssemblerNode represent a group of crafting machines for crafting a single recipe
--- @field recipe LuaRecipePrototype
--- @field recipe_speed number how fast the recipe should be done per second
--- @field targets table<ingredient_name, AssemblerNode> target assemblers that outputs are delivered to
--- @field sources table<ingredient_name, AssemblerNode> assemblers that inputs are received from
--- @field player_index player_index
--- @type AssemblerNode
local AssemblerNode = {}

-- AssemblerNode class inherent Table class
function AssemblerNode.__index (t, k)
    return AssemblerNode[k] or ArrayList[k] or t.recipe[k]
end

function AssemblerNode.__tostring()
    return serpent.line(self)
end

function AssemblerNode.new(o)
    assert(o.recipe and o.player_index)
    o.recipe_speed = o.recipe_speed or 0
    o.targets = o.targets or ArrayList.new {}
    o.sources = o.sources or ArrayList.new {}
    setmetatable(o, AssemblerNode)
    return o
end

--- generate a blueprint section with a single crafting machine unit
--- @return BlueprintSection, number, InternalDirectionSpec
function AssemblerNode:generate_crafting_unit()
    local section = BlueprintSection.new()
    local crafting_machine = PlayerInfo.get_crafting_machine_prototype(self.player_index, self.recipe)
    local available_inserters = PlayerInfo.unlocked_inserters(self.player_index)
    local crafting_machine_size = PrototypeInfo.get_size(crafting_machine)
    local crafter_width = crafting_machine_size.x
    local crafter_height = crafting_machine_size.y
    --- ideal crafting speed of the recipe, unit is recipe/second
    local ideal_crafting_speed = crafting_machine.crafting_speed / self.recipe.energy

    logging.log("crafter_width = " .. tostring(crafter_width) .. ", crafter_height = " .. tostring(crafter_height))

    section:add({
        -- set top-left corner of crafting machine to 0,0
        position = { x = math.floor(crafter_width / 2), y = math.floor(crafter_height / 2) },
        name = crafting_machine.name,
        recipe = self.recipe.name
    })

    -- specify available parallel transporting lines
    --- @class fulfilled_line
    --- @field item boolean true if it is unavailable
    --- @field fluid boolean true if fluid is unavailable

    --- @type table<number, fulfilled_line> key is y coordinate of the line
    local fulfilled_lines = {}
    --- @type number[]
    local line_check_order = {}
    -- populate available transporting lines in order like -2, 2, -3, 3 ...
    -- available transporting line starting 2 block away from crafting machine,
    -- since 1 block away are all inserters
    for yoff = 2, 10, 1 do
        for side = -1, 1, 2 do
            local y = yoff * side + (side < 0 and 0 or crafter_height - 1)
            line_check_order[#line_check_order + 1] = y
            fulfilled_lines[y] = {}
        end
    end

    -- populate actual transporting lines for each ingredient
    local preferred_belt = PlayerInfo.get_preferred_belt(self.player_index)
    --- @class ConnectionSpec
    --- @field replaceable boolean required, if this connection point could be replaced by others
    --- @field entity LuaEntityPrototype nullable, inserter/pipe prototype
    --- @field direction defines.direction nullable, inserter/pipe direction
    --- @field transport_line_y number the connection point's corresponding transport line
    --- @field line_info TransportLineInfo transport line information

    --- @type table<Vector2D, ConnectionSpec> connection entity specification table which is keyed by its coordinate
    local connection_positions = setmetatable({}, { __index = function(t, k)
        for test_key, v in pairs(t) do
            if test_key == k then
                return v
            end
        end
    end
    })
    do
        -- populate all connection positions
        for _, y in ipairs({ -1, crafter_height }) do
            for x = 0, crafter_width - 1, 1 do
                connection_positions[Vector2D.new(x, y)] = {
                    replaceable = true
                }
            end
        end
    end

    --- @type table<'"input"'|'"output"', ArrayList|Vector2D[]> fluid connection point positions of the crafting machine, if available
    local fluid_box_positions = {}
    for _, connection_type in ipairs({ "output", "input" }) do
        fluid_box_positions[connection_type] = ArrayList.new(crafting_machine.fluid_boxes)
                                                        :filter(
                function(box)
                    local out = type(box) == "table" and box.production_type == connection_type
                    return out
                end)
                                                        :map(
                function(b)
                    local connection_position = Vector2D.new(
                            b.pipe_connections[1].position[1] + math.floor(crafter_width / 2),
                            b.pipe_connections[1].position[2] + math.floor(crafter_height / 2)
                    )
                    -- fill position with fluid box, so that inserters can't occupy this position
                    connection_positions[connection_position].replaceable = false
                    return connection_position
                end)
    end
    --- true for output fluid box index, false for input fluid box index
    local fluid_box_indices = { ["output"] = 1, ["input"] = 1 }

    --- @class TransportLineInfo
    --- @field crafting_items (Product|Ingredient)[]
    --- @field direction '"input"' | '"output"'
    --- @field type '"fluid"' | '"item"'

    --- @param recipe LuaRecipePrototype
    --- @return TransportLineInfo[] | ArrayList
    local function create_transport_line_info_list(recipe)
        --- @type TransportLineInfo[]|ArrayList
        local item_info_list = ArrayList.new()
        --- @type TransportLineInfo[]|ArrayList
        local fluid_info_list = ArrayList.new()
        -- iterate input ingredients, combine 2 input items into a single belt
        do
            local i = 1
            local next_line_items = ArrayList.new()
            while i <= #recipe.ingredients do
                local ingredient = recipe.ingredients[i]
                if ingredient.type == "fluid" then
                    fluid_info_list:add { type = 'fluid', crafting_items = { ingredient }, direction = "input" }
                else
                    next_line_items:add(ingredient)
                    if #next_line_items == 2 then
                        item_info_list:add { type = "item", crafting_items = next_line_items, direction = "input" }
                        next_line_items = ArrayList.new()
                    end
                end
                i = i + 1
            end
            if #next_line_items > 0 then
                item_info_list:add { type = 'item', direction = "input", crafting_items = next_line_items }
            end
        end
        -- iterate output products
        for _, product in ipairs(recipe.products) do
            if product.type == "item" then
                item_info_list:add { type = "item", direction = "output", crafting_items = { product } }
            else
                fluid_info_list:add { type = "fluid", direction = "output", crafting_items = { product } }
            end
        end
        item_info_list:addAll(fluid_info_list)
        return item_info_list
    end

    local transport_line_infos = create_transport_line_info_list(self.recipe)

    local direction_spec
    -- determine the directions of transport belts
    do
        local item_line_num = #transport_line_infos:filter(function(line_info)
            return line_info.type == "item"
        end)
        local item_output_direction = item_line_num % 2 == 0 and defines.direction.south or defines.direction.north
        direction_spec = PlayerInfo.get_internal_direction_spec(self.player_index, item_output_direction)
    end
    -- concatenate ingredients and products together
    for _, line_info in ipairs(transport_line_infos) do
        -- find next available transporting line to fill
        for _, y in ipairs(line_check_order) do
            local line = fulfilled_lines[y]
            if not line[line_info.type] then
                local y_closer_to_factory = y - (y > 0 and 1 or -1)
                local corresponding_fluid_box_position = fluid_box_positions[line_info.direction][fluid_box_indices[line_info.direction]]
                -- pre-check for any crafting machine prototypes with unknown fluid box support
                if line_info.type == "fluid" and corresponding_fluid_box_position == nil then
                    logging.log("This mod recipe's crafting machine needs fluid box connection, which is not supported by the mod yet. Consider prioritize a built-in crafting machine instead? Failed to make blueprint :(", logging.E)
                    logging.log("You can add support for this recipe by contributing it's fluid box connections in github: https://github.com/Seancheey/FactorioBlueprinter/blob/master/prototype_info.lua")
                    return
                end
                if line_info.type == "fluid" and
                        -- fluid box's connection position and transport line is at same side
                        corresponding_fluid_box_position.y * y > 0 and
                        -- line next to factory can use pipe directly, so allowed
                        (fulfilled_lines[y_closer_to_factory] == nil or
                                -- line's side towards factory will be used for underground pipe, which can't be fulfilled
                                not fulfilled_lines[y_closer_to_factory]["item"]) then
                    -- different fluid line can't be neighboring each other
                    if fulfilled_lines[y + 1] then
                        fulfilled_lines[y + 1].fluid = true
                    end
                    if fulfilled_lines[y - 1] then
                        fulfilled_lines[y - 1].fluid = true
                    end
                    -- fluid line's side towards factory are used for underground pipe, so can't use
                    if fulfilled_lines[y_closer_to_factory] then
                        fulfilled_lines[y_closer_to_factory].item = true
                    end
                    -- occupy this line
                    line.item = true
                    line.fluid = true
                    -- populate transportation line to section
                    for x = 0, crafter_width - 1, 1 do
                        section:add({
                            name = "pipe",
                            position = { x = x, y = y }
                        })
                    end

                    if fulfilled_lines[y_closer_to_factory] == nil then
                        -- pipe line next to factory only needs one connection pipe
                        section:add({
                            name = "pipe",
                            position = corresponding_fluid_box_position,
                            direction = defines.direction.north
                        })
                    else
                        -- pipe line further needs a pair of underground connection pipe
                        section:add({
                            name = "pipe-to-ground",
                            position = { x = corresponding_fluid_box_position.x, y = y_closer_to_factory },
                            direction = y > 0 and defines.direction.south or defines.direction.north
                        })
                        section:add({
                            name = "pipe-to-ground",
                            position = corresponding_fluid_box_position,
                            direction = y > 0 and defines.direction.north or defines.direction.south
                        })
                    end
                    fluid_box_indices[line_info.direction] = fluid_box_indices[line_info.direction] + 1
                    break
                elseif line_info.type == "item" then
                    line.item = true
                    line.fluid = true
                    -- populate transportation line to section
                    for x = 0, crafter_width - 1, 1 do
                        section:add({
                            name = preferred_belt.name,
                            position = { x = x, y = y },
                            direction = line_info.direction == "input" and direction_spec.linearIngredientDirection or direction_spec.linearOutputDirection
                        })
                    end
                    local connection_y = y > 0 and crafter_height or -1
                    --- @type string
                    local inserter_type
                    -- number of inserter needed to full-fill ideal crafting speed, this number is not guaranteed to be in blueprint
                    local inserter_num_need = 1
                    do
                        -- determine what kind of inserter to use for the transport line
                        local transport_line_distance = math.abs(y - connection_y)
                        -- TODO should handle transport_line_distance = 3 situation
                        transport_line_distance = (transport_line_distance <= 1) and 1 or 2
                        local inserter_order = available_inserters[transport_line_distance]
                        if inserter_order then
                            local required_rotation_per_sec = 0
                            for _, crafting_item in ipairs(line_info.crafting_items) do
                                local avg_amount = average_amount_of(crafting_item)
                                required_rotation_per_sec = required_rotation_per_sec + avg_amount * ideal_crafting_speed
                            end
                            -- use lower-level inserters if it's enough
                            local found_satisfying_inserter = false
                            for _, inserter in ipairs(inserter_order) do
                                if PlayerInfo.inserter_items_speed(self.player_index, inserter) >= required_rotation_per_sec then
                                    inserter_type = inserter.name
                                    found_satisfying_inserter = true
                                    break
                                end
                            end
                            -- even fastest inserter doesn't support required speed, use fastest
                            if not found_satisfying_inserter then
                                local fastest_inserter = inserter_order[#inserter_order]
                                inserter_type = fastest_inserter.name
                                inserter_num_need = math.ceil(required_rotation_per_sec / PlayerInfo.inserter_items_speed(self.player_index, fastest_inserter))
                                logging.log(serpent.line(line_info.crafting_items) .. " requires " .. tostring(inserter_num_need) .. " " .. fastest_inserter.name)
                            end
                        else
                            if transport_line_distance == 1 then
                                inserter_type = "inserter"
                            else
                                game.players[self.player_index].print("fail to find an unlocked inserter with arm length " .. transport_line_distance .. ", use long handed inserter instead")
                                inserter_type = "long-handed-inserter"
                            end
                        end
                    end

                    -- iterate through possible positions for placing inserter
                    for coordinate, connection_spec in pairs(connection_positions) do
                        if coordinate.y == connection_y and connection_spec.replaceable == true then
                            connection_positions[coordinate] = {
                                replaceable = inserter_num_need ~= 1,
                                direction = (line_info.direction == "output" and 1 or -1) * (connection_y < 0 and 1 or -1) > 0 and defines.direction.south or defines.direction.north,
                                entity = game.entity_prototypes[inserter_type],
                                transport_line_y = y,
                                line_info = line_info
                            }
                            inserter_num_need = inserter_num_need - 1
                            if inserter_num_need == 0 then
                                break
                            end
                        end
                    end
                    break
                end
            end
        end
    end
    -- fill inserters and calculate corresponding item transfer speed
    do
        --- @type table<number, ConnectionPoint>
        local inlet_line_spec = {}
        --- @type table<number, ConnectionPoint>
        local outlet_line_spec = {}
        for coordinate, connection_spec in pairs(connection_positions) do
            -- logging.log("coordinate: " .. serpent.line(coordinate) .. " connection spec: " .. serpent.line(connection_spec))
            if connection_spec.entity then
                section:add({
                    name = connection_spec.entity.name,
                    direction = connection_spec.direction,
                    position = coordinate
                })
                local spec_table = (connection_spec.line_info.direction == "input") and inlet_line_spec or outlet_line_spec
                -- initialize inlet/outlet table if entry not exists
                if not spec_table[connection_spec.transport_line_y] then
                    local connection_point_x = (
                            (direction_spec.linearIngredientDirection == defines.direction.east) == (connection_spec.line_info.direction == "input")
                    ) and (crafter_width - 1) or 0
                    spec_table[connection_spec.transport_line_y] = {
                        position = Vector2D.new(connection_point_x, connection_spec.transport_line_y),
                        entity = connection_spec.line_info.type == "item" and preferred_belt or game.entity_prototypes["pipe"],
                        ingredients = ArrayList.mapToTable(connection_spec.line_info.crafting_items, function(x)
                            return x.name, 0
                        end)
                    }
                end

                --- a inserter's speed is split by two items in the belt according to it's recipe items' amount ratios
                --- @type table<string, number> item name to it's speed
                local crafting_item_ratios = {}
                do
                    local crafting_item_recipe_nums = {}
                    local total_amount = 0
                    for _, crafting_item in ipairs(connection_spec.line_info.crafting_items) do
                        local average_amount = average_amount_of(crafting_item)
                        crafting_item_recipe_nums[crafting_item.name] = average_amount
                        total_amount = total_amount + average_amount
                    end
                    for item_name, amount in pairs(crafting_item_recipe_nums) do
                        crafting_item_ratios[item_name] = amount / total_amount
                    end
                    logging.log("crafting_item_ratios = " .. serpent.line(crafting_item_ratios))
                end

                for _, crafting_item in ipairs(connection_spec.line_info.crafting_items) do
                    spec_table[connection_spec.transport_line_y].ingredients[crafting_item.name] = spec_table[connection_spec.transport_line_y].ingredients[crafting_item.name] + PlayerInfo.inserter_items_speed(self.player_index, connection_spec.entity) * crafting_item_ratios[crafting_item.name]
                end
            end
            -- TODO also add inlet/outlet for fluid
        end
        section.inlets = ArrayList.new(inlet_line_spec)
        section.outlets = ArrayList.new(outlet_line_spec)
    end

    local max_speed_unit_repetition_num = 1 / 0
    local max_recipe_speed = 1 / 0
    --- @type ConnectionPoint[][]
    local all_connections = { section.inlets, section.outlets }
    for _, connections in ipairs(all_connections) do
        for _, connection_point in ipairs(connections) do
            local belt_lane_num = #ArrayList.new(connection_point.ingredients)
            for _, speed in pairs(connection_point.ingredients) do
                local max_belt_speed = preferred_belt.belt_speed * 480 / belt_lane_num
                logging.log("max belt speed " .. tostring(preferred_belt.belt_speed * 480))
                local repetition = math.ceil(max_belt_speed / speed)
                if repetition < max_speed_unit_repetition_num then
                    max_speed_unit_repetition_num = repetition
                end
                if speed < max_recipe_speed then
                    max_recipe_speed = speed
                end
            end
        end
    end
    --logging.log("inlets = " .. serpent.line(section.inlets) .. ",\n outlets = " .. serpent.line(section.outlets).. "\n ---")
    return section, max_speed_unit_repetition_num, direction_spec, max_recipe_speed
end

--- @return BlueprintSection
function AssemblerNode:generate_section()
    local unit_section, max_unit_per_row, _, unit_crafting_speed = self:generate_crafting_unit()
    local unit_needed = math.ceil(self.recipe_speed / unit_crafting_speed)

    local section = BlueprintSection.new()
    local unit_height = unit_section:height()
    local y_shift = 0
    while unit_needed > 0 do
        local unit_num_in_row = (unit_needed >= max_unit_per_row) and max_unit_per_row or unit_needed
        local new_unit_row = unit_section:copy():repeat_self(unit_num_in_row)
        new_unit_row:shift(0, y_shift)
        section:addSection(new_unit_row)

        y_shift = y_shift + unit_height
        unit_needed = unit_needed - unit_num_in_row
    end

    return section
end

return AssemblerNode