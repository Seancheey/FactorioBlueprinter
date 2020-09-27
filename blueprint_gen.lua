require("util")
require("prototype_info")
require("player_info")

--- @alias recipe_name string
--- @alias ingredient_name string

--- @class Coordinate
--- @field x number
--- @field y number

--- @class Entity
--- @field entity_number number unique identifier of entity
--- @field name string entity name
--- @field position Coordinate
--- @field direction any defines.direction.east/south/west/north

--- @class ConnectionPoint
--- @field ingredients table<ingredient_name, number> ingredients that the connection point is transporting to number of items transported per second
--- @field position Coordinate
--- @field connection_entity LuaEntityPrototype

--- @class BlueprintSection
--- @field entities Entity[]
--- @field inlets ConnectionPoint[]
--- @field outlets ConnectionPoint[]

--- @type BlueprintSection
BlueprintSection = {}
BlueprintSection.__index = BlueprintSection

--- @return Coordinate a comparable coordinate object
function Coordinate(x, y)
    return setmetatable({ x = x, y = y }, { __eq = function(ca, cb)
        return ca.x == cb.x and ca.y == cb.y
    end })
end

--- @return BlueprintSection
function BlueprintSection.new()
    --- @type BlueprintSection
    o = { entities = toArrayList {}, inlets = toArrayList {}, outlets = toArrayList {} }
    setmetatable(o, BlueprintSection)
    return o
end

function BlueprintSection:copy(xoff, yoff)
    assert(self)
    xoff = xoff or 0
    yoff = yoff or 0
    --- @param old Entity
    function shifted_entity(old)
        local entity = deep_copy(old)
        entity.position.x = entity.position.x + xoff
        entity.position.y = entity.position.y + yoff
        return entity
    end
    local new_section = BlueprintSection.new()
    new_section.entities = toArrayList(self.entities):map(shifted_entity)
    -- TODO also update inlets/outlets
    return new_section
end

--- @param entity Entity
function BlueprintSection:add(entity)
    assertAllTruthy(self, entity)
    entity.entity_number = #self.entities + 1
    self.entities[entity.entity_number] = entity
end

--- concatenate with another section, assuming that self's outlets and other's inlets are connected.
--- If no offsets are provided, default to concatenate other to right side.
--- @param other BlueprintSection
--- @param xoff number optional, x-offset of the other section, default to width of self
--- @param yoff number optional, y-offset of the other section, default to 0
--- @return BlueprintSection new self
function BlueprintSection:concat(other, xoff, yoff)
    assertAllTruthy(self, other)
    xoff = xoff or self:width()
    yoff = yoff or 0

    self.outlets = {}
    for _, entity in ipairs(other.entities) do
        local new_entity = deep_copy(entity)
        new_entity.position.x = new_entity.position.x + xoff
        new_entity.position.y = new_entity.position.y + yoff
        self:add(new_entity)
        -- TODO also add outlet transform
    end

    return self
end

function BlueprintSection:width()
    -- TODO verify width calculation
    local min, max
    for _, entity in ipairs(self.entities) do
        test_min = entity.position.x + game.entity_prototypes[entity.name].selection_box.left_top.x
        if not min or test_min < min then
            min = test_min
        end
        test_max = entity.position.x + game.entity_prototypes[entity.name].selection_box.right_bottom.x
        if not max or test_max > max then
            max = test_max
        end
    end
    local width = math.floor((max or 0) - (min or 0))
    return width
end

--- clear overlapped units, last-in entity get saved
function BlueprintSection:clear_overlap()
    local position_dict = {}
    for _, entity in pairs(self.entities) do
        local pos = tostring(entity.position[1] or entity.position.x) .. "," .. tostring(entity.position[2] or entity.position.y)
        position_dict[pos] = entity
    end
    self.entities = {}
    for _, entity in pairs(position_dict) do
        self:add(entity)
    end
end

--- @param n_times number
--- @return BlueprintSection
function BlueprintSection:repeat_self(n_times)
    assertAllTruthy(self, n_times)

    local unit = self:copy()
    local unit_width = unit:width()
    print_log(serpent.line(unit.entities, { maxlevel = 4 }))

    for i = 1, n_times - 1, 1 do
        self:concat(unit, unit_width * i, 0)
    end
    return self
end

-- rotate clockwise 90*n degrees
function BlueprintSection:rotate(n)
    local rotate_matrices = { [0] = function(x, y)
        return { x = x, y = y }
    end, [1] = function(x, y)
        return { x = y, y = -x }
    end, [2] = function(x, y)
        return { x = -x, y = -y }
    end, [3] = function(x, y)
        return { x = -y, y = x }
    end }

    n = -n % 4
    local rotate_func = rotate_matrices[n]
    for _, entity in ipairs(self.entities) do
        local prototype = game.entity_prototypes[entity.name]
        -- entity with even number of width/height will have a small centering offset
        local x_offset = (math.ceil(prototype.selection_box.right_bottom.x - prototype.selection_box.left_top.x + 1) % 2) / 2
        local y_offset = (math.ceil(prototype.selection_box.right_bottom.y - prototype.selection_box.left_top.y + 1) % 2) / 2
        if entity.name == "stone-furnace" then
            print_log("before position: " .. serpent.line(entity.position))
        end
        entity.position = rotate_func(entity.position.x - x_offset, entity.position.y - y_offset)
        if entity.name == "stone-furnace" then
            print_log("after position: " .. serpent.line(entity.position))
        end
        entity.direction = ((entity.direction or 0) - 2 * n) % 8
    end
end

ALL_BELTS = { "transport-belt", "fast-transport-belt", "express-transport-belt" }

--- @class AssemblerNode represent a group of crafting machines for crafting a single recipe
--- @field recipe LuaRecipePrototype
--- @field recipe_speed number how fast the recipe should be done per second
--- @field targets table<ingredient_name, AssemblerNode> target assemblers that outputs are delivered to
--- @field sources table<ingredient_name, AssemblerNode> assemblers that inputs are received from
--- @field player_index player_index
--- @type AssemblerNode
AssemblerNode = {}

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
    o.targets = o.targets or toArrayList {}
    o.sources = o.sources or toArrayList {}
    setmetatable(o, AssemblerNode)
    return o
end

--- generate a blueprint section with a single crafting machine unit
--- @return BlueprintSection, number, InternalDirectionSpec
function AssemblerNode:generate_crafting_unit()
    local section = BlueprintSection.new()
    local crafting_machine = PlayerInfo.get_crafting_machine_prototype(self.player_index, self.recipe)
    local available_inserters = PlayerInfo.unlocked_inserters(self.player_index)
    local crafter_width = math.ceil(crafting_machine.selection_box.right_bottom.x - crafting_machine.selection_box.left_top.x)
    local crafter_height = math.ceil(crafting_machine.selection_box.right_bottom.y - crafting_machine.selection_box.left_top.y)
    --- ideal crafting speed of the recipe, unit is recipe/second
    local ideal_crafting_speed = crafting_machine.crafting_speed / self.recipe.energy

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

    --- @type table<Coordinate, ConnectionSpec> connection entity specification table which is keyed by its coordinate
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
                connection_positions[Coordinate(x, y)] = {
                    replaceable = true
                }
            end
        end
    end

    --- @type table<'"input"'|'"output"', ArrayList|Coordinate[]> fluid connection point positions of the crafting machine, if available
    local fluid_box_positions = {}
    for _, connection_type in ipairs({ "output", "input" }) do
        fluid_box_positions[connection_type] = toArrayList(crafting_machine.fluid_boxes)
                :filter(
                function(box)
                    local out = type(box) == "table" and box.production_type == connection_type
                    return out
                end)
                :map(
                function(b)
                    local connection_position = Coordinate(
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
    function create_transport_line_info_list(recipe)
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
                    print_log("This mod recipe's crafting machine needs fluid box connection, which is not supported by the mod yet. Consider prioritize a built-in crafting machine instead? Failed to make blueprint :(", logging.E)
                    print_log("You can add support for this recipe by contributing it's fluid box connections in github: https://github.com/Seancheey/FactorioBlueprinter/blob/master/prototype_info.lua")
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
                                print_log(serpent.line(line_info.crafting_items) .. " requires " .. tostring(inserter_num_need) .. " " .. fastest_inserter.name)
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
            -- print_log("coordinate: " .. serpent.line(coordinate) .. " connection spec: " .. serpent.line(connection_spec))
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
                        position = Coordinate(connection_point_x, connection_spec.transport_line_y),
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
                    print_log("crafting_item_ratios = " .. serpent.line(crafting_item_ratios))
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
    --- @type ConnectionPoint[][]
    local all_connections = { section.inlets, section.outlets }
    for _, connections in ipairs(all_connections) do
        for _, connection_point in ipairs(connections) do
            local belt_lane_num = #ArrayList.new(connection_point.ingredients)
            for _, speed in pairs(connection_point.ingredients) do
                local max_belt_speed = preferred_belt.belt_speed * 480 / belt_lane_num
                print_log("max belt speed " .. tostring(preferred_belt.belt_speed * 480))
                local repetition = math.ceil(max_belt_speed / speed)
                if repetition < max_speed_unit_repetition_num then
                    max_speed_unit_repetition_num = repetition
                end
            end
        end
    end

    return section, max_speed_unit_repetition_num, direction_spec
end

--- @return BlueprintSection
function AssemblerNode:generate_section()

    -- concatenate multiple crafting units horizontally to create a section

    -- TODO use multiple units
    return self:generate_crafting_unit()
end

--- @class BlueprintGraph
--- @field inputs table<ingredient_name, AssemblerNode> input ingredients
--- @field outputs table<ingredient_name, AssemblerNode> output ingredients
--- @field dict table<recipe_name, AssemblerNode> all assembler nodes
--- @field player_index player_index
BlueprintGraph = {}
function BlueprintGraph.__index(t, k)
    return BlueprintGraph[k] or ArrayList[k] or t.dict[k]
end

--- @return BlueprintGraph
function BlueprintGraph.new(player_index)
    o = { player_index = player_index }
    o.inputs = toArrayList {}
    o.outputs = toArrayList {}
    o.dict = toArrayList {}
    setmetatable(o, BlueprintGraph)
    return o
end

--- @param output_specs OutputSpec[]
function BlueprintGraph:generate_graph_by_outputs(output_specs)
    assertAllTruthy(self, output_specs)

    for _, requirement in ipairs(output_specs) do
        if requirement.ingredient and requirement.crafting_speed then
            self:__generate_assembler(requirement.ingredient, requirement.crafting_speed, true)
        end
    end
end

function BlueprintGraph:use_products_as_input(item_name)
    self.__index = BlueprintGraph.__index
    setmetatable(self, self)
    local nodes = self:__assemblers_whose_ingredients_have(item_name)
    if nodes:any(function(x)
        return self.outputs:has(x)
    end) then
        print_log("ingredient can't be more advanced", logging.I)
        return
    end

    self.inputs[item_name] = nil
    for _, node in pairs(nodes) do
        for _, product in ipairs(node.recipe.products) do
            for _, target in pairs(self:__assemblers_whose_ingredients_have(product.name)) do
                self.inputs[product.name] = target
            end
        end
    end

    -- remove unnecessary input sources that are fully covered by other sources
    local others = shallow_copy(self.inputs)
    local to_remove = {}
    for input_name, input_node in pairs(self.inputs) do
        others[input_name] = nil
        if self:__ingredient_fully_used_by(input_name, ArrayList.fromKeys(others)) then
            to_remove[input_name] = input_node
        end
        others[input_name] = input_node
    end
    for input_name, _ in pairs(to_remove) do
        self.inputs[input_name] = nil
    end
end

function BlueprintGraph:use_ingredients_as_input(item_name)
    self.__index = BlueprintGraph.__index
    setmetatable(self, self)
    local viable = false
    for _, node in pairs(self:__assemblers_whose_products_have(item_name)) do
        for _, ingredient in pairs(node.recipe.ingredients) do
            self.inputs[ingredient.name] = node
            viable = true
        end
    end
    if viable then
        self.inputs[item_name] = nil
    end
end

--- insert a new blueprint item into player's inventory
function BlueprintGraph:generate_blueprint()
    -- TODO use full blueprint rather then first output
    for _, output_node in pairs(self.outputs) do
        PlayerInfo.insert_blueprint(self.player_index, output_node:generate_section().entities)
        break
    end
end

function BlueprintGraph:__generate_assembler(recipe_name, crafting_speed, is_final)
    assert(self and recipe_name and crafting_speed and (is_final ~= nil))
    local recipe = game.recipe_prototypes[recipe_name]
    if recipe then
        -- setup current node
        self.dict[recipe_name] = self.dict[recipe_name] or AssemblerNode.new { recipe = recipe, player_index = self.player_index }
        local node = self.dict[recipe_name]
        if is_final then
            for _, product in ipairs(node.products) do
                print_log("output:" .. product.name)
                self.outputs[product.name] = node
            end
        end
        local new_speed
        for _, product in ipairs(node.recipe.products) do
            if product.name == recipe_name then
                new_speed = crafting_speed / average_amount_of(product)
                node.recipe_speed = node.recipe_speed + new_speed
                break
            end
        end
        if new_speed == nil then
            print_log("speed setup for " .. recipe_name .. " failed", logging.E)
            new_speed = 1
        end
        -- setup children nodes
        for _, ingredient in ipairs(node.ingredients) do
            child_recipe = game.recipe_prototypes[ingredient.name]
            if child_recipe then
                local child = self:__generate_assembler(child_recipe.name, ingredient.amount * new_speed, false)
                node.sources[ingredient.name] = child
                child.targets[recipe_name] = node
            else
                self.inputs[ingredient.name] = node
            end
        end
        return node
    else
        print_log(recipe_name .. " doesn't have a recipe.", logging.E)
    end
end

--- @return AssemblerNode[]
function BlueprintGraph:__assemblers_whose_products_have(item_name)
    if self[item_name] then
        return toArrayList { self[item_name] }
    end
    local out = toArrayList {}
    for _, node in pairs(self.dict) do
        for _, product in pairs(node.recipe.products) do
            if product.name == item then
                out[#out + 1] = node
                break
            end
        end
    end
    return out
end

--- @return AssemblerNode[]
function BlueprintGraph:__assemblers_whose_ingredients_have(item_name)
    assert(self and item_name)
    local out = toArrayList {}
    if self[item_name] then
        for _, node in pairs(self[item_name].targets) do
            out[#out + 1] = node
        end
        return out
    end
    for _, node in pairs(self.dict) do
        for _, ingredient in ipairs(node.recipe.ingredients) do
            if ingredient.name == item_name then
                out[#out + 1] = node
                break
            end
        end
    end
    return out
end

function BlueprintGraph:__ingredient_fully_used_by(ingredient_name, item_list)
    if self.outputs[ingredient_name] then
        return false
    end
    if item_list:has(ingredient_name) then
        return true
    end
    products = toArrayList {}
    for _, node in ipairs(self:__assemblers_whose_ingredients_have(ingredient_name)) do
        for _, p in ipairs(node.recipe.products) do
            products[#products + 1] = p.name
        end
    end
    return products:all(function(p)
        return self:__ingredient_fully_used_by(p, item_list)
    end)
end
