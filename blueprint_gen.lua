require("helper")
require("prototype_info")

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
--- @field ingredients ingredient_name[] ingredients that the connection point is transporting
--- @field entity Entity

--- @class BlueprintSection
--- @field entities Entity[]
--- @field inlets ConnectionPoint[]
--- @field outlets ConnectionPoint[]

--- @type BlueprintSection
BlueprintSection = {}
BlueprintSection.__index = BlueprintSection

--- @return BlueprintSection
function BlueprintSection.new()
    --- @type BlueprintSection
    o = { entities = {}, inlets = {}, outlets = {} }
    setmetatable(o, BlueprintSection)
    return o
end

function BlueprintSection:copy_with_offset(xoff, yoff)
    function shifted_entity(old)
        local entity = Table.shallow_copy(old)
        entity.position.x = entity.position.x + xoff
        entity.position.y = entity.position.y + yoff
        return entity
    end
    local new_section = BlueprintSection.new()
    new_section.entities = newtable(self.entities):map(shifted_entity)
    new_section.inlets = newtable(self.entities):map(shifted_entity)
    new_section.outlets = newtable(self.entities):map(shifted_entity)

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
    xoff = xoff or self.width()
    yoff = yoff or 0

    self.outlets = {}
    for _, entity in ipairs(other.entities) do
        local new_entity = Table.shallow_copy(entity)
        new_entity.xoff = new_entity.xoff + xoff
        new_entity.yoff = new_entity.yoff + yoff
        self.entities[#self.entities + 1] = new_entity
        for _, connection in ipairs(other.outlets) do
            if connection.entity == entity then
                self.outlets[#self.outlets + 1] = { entity = new_entity, ingredients = connection.ingredients }
            end
        end
    end

    self:organize_entity_uid()
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
    return (max or 0) - (min or 0)
end

function BlueprintSection:organize_entity_uid()
    for i, entity in ipairs(self.entities) do
        entity.entity_number = i
    end
end

ALL_BELTS = { "transport-belt", "fast-transport-belt", "express-transport-belt" }
INSERTER_SPEEDS = {
    ["burner-inserter"] = 0.6,
    ["inserter"] = 0.83,
    ["long-handed-inserter"] = 1.2,
    ["fast-inserter"] = 2.31,
    ["filter-inserter"] = 2.31,
    ["stack-inserter"] = 2.31,
    ["stack-filter-inserter"] = 2.31
}

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
    return AssemblerNode[k] or Table[k] or t.recipe[k]
end

function AssemblerNode.new(o)
    assert(o.recipe and o.player_index)
    o.recipe_speed = o.recipe_speed or 0
    o.targets = o.targets or newtable {}
    o.sources = o.sources or newtable {}
    setmetatable(o, AssemblerNode)
    return o
end

function AssemblerNode:tostring()
    return "{" .. self.recipe .. "  sources:" .. self.sources:keys():tostring() .. ", targets:" .. self.targets:keys():tostring() .. "}"
end

--- generate a blueprint section with a single crafting machine unit
--- @return BlueprintSection
function AssemblerNode:generate_crafting_unit()
    local section = BlueprintSection.new()
    local crafting_machine = self:get_crafting_machine_prototype()
    local crafter_width = math.ceil(crafting_machine.selection_box.right_bottom.x - crafting_machine.selection_box.left_top.x)
    local crafter_height = math.ceil(crafting_machine.selection_box.right_bottom.y - crafting_machine.selection_box.left_top.y)

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
    local preferred_belt = self:get_preferred_belt()

    -- connection positions at sides of a factory that's been occupied by a insert or a pipe
    local occupied_connection_positions = newtable()

    --- @type table<"'input'"|"output", table[]> fluid connection point positions of the crafting machine, if available
    local fluid_box_positions = {}
    for _, connection_type in ipairs({ "output", "input" }) do
        fluid_box_positions[connection_type] = newtable(crafting_machine.fluid_boxes)
                :filter(
                function(box)
                    local out = type(box) == "table" and box.production_type == connection_type
                    return out
                end)
                :map(
                function(b)
                    local connection_position = {
                        b.pipe_connections[1].position[1] + math.floor(crafter_width / 2),
                        b.pipe_connections[1].position[2] + math.floor(crafter_height / 2)
                    }
                    occupied_connection_positions[#occupied_connection_positions + 1] = connection_position
                    return connection_position
                end)
    end
    --- true for output fluid box index, false for input fluid box index
    local fluid_box_indices = { ["output"] = 1, ["input"] = 1 }

    --- @class TransportLineInfo
    --- @field crafting_items (Product|Ingredient)[]
    --- @field direction "input" | "output"
    --- @field type "'fluid'" | "'item'"

    --- @param recipe LuaRecipePrototype
    --- @return TransportLineInfo[]
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
                item_info_list:add { type = "item", direction = "output", crafting_items = product }
            else
                fluid_info_list:add { type = "fluid", direction = "output", crafting_items = product }
            end
        end
        item_info_list:addAll(fluid_info_list)
        return item_info_list
    end

    local transport_line_infos = create_transport_line_info_list(self.recipe)

    -- TODO should iterate items before fluids so that item line is closer to factory
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
                    print_log("This mod recipe needs fluid box connection, which is not supported by the mod yet. Failed to make blueprint :(", logging.E)
                    print_log("You can add support for this recipe by contributing it's fluid box connections in github: https://github.com/Seancheey/FactorioBlueprinter/blob/master/prototype_info.lua")
                    return
                end
                if line_info.type == "fluid" and
                        -- fluid box's connection position and transport line is at same side
                        corresponding_fluid_box_position[2] * y > 0 and
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
                            position = { x = x, y = y },
                            direction = defines.direction.east
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
                            position = { x = corresponding_fluid_box_position[1], y = y_closer_to_factory },
                            direction = y > 0 and defines.direction.south or defines.direction.north
                        })
                        section:add({
                            name = "pipe-to-ground",
                            position = corresponding_fluid_box_position,
                            direction = y > 0 and defines.direction.north or defines.direction.south
                        })
                    end
                    fluid_box_indices[line_info.direction] = fluid_box_indices[line_info.direction] + 1
                    -- TODO add connection_position
                    break
                elseif line_info.type == "item" then
                    line.item = true
                    line.fluid = true
                    -- populate transportation line to section
                    for x = 0, crafter_width - 1, 1 do
                        section:add({
                            name = preferred_belt.name,
                            position = { x = x, y = y },
                            direction = defines.direction.east
                        })
                    end
                    local factory_side_y = y > 0 and crafter_height or -1
                    local transport_line_distance = math.abs(y - factory_side_y)
                    local inserter_type = transport_line_distance <= 1 and "inserter" or "long-handed-inserter"
                    -- TODO should handle transport_line_distance = 3 situation
                    -- iterate through possible positions for placing inserter
                    for x = 0, crafter_width - 1, 1 do
                        if not occupied_connection_positions:any(function(occupied_pos)
                            return occupied_pos[1] == x and occupied_pos[2] == factory_side_y
                        end) then
                            local inserter_position = { x, factory_side_y }
                            local to_south = (line_info.direction == "output" and 1 or -1) * (inserter_position[2] < 0 and 1 or -1)
                            occupied_connection_positions[#occupied_connection_positions + 1] = inserter_position
                            section:add({
                                name = inserter_type,
                                position = inserter_position,
                                direction = to_south > 0 and defines.direction.south or defines.direction.north
                            })
                            break
                        end
                    end
                    -- TODO add connection position
                    break
                end
            end
        end
    end

    return section
end

--- @return BlueprintSection
function AssemblerNode:generate_section()

    -- concatenate multiple crafting units horizontally to create a section

    -- TODO use multiple units
    return self:generate_crafting_unit()
end

--- get a crafting machine prototype that user preferred
--- @return any crafting machine prototype
function AssemblerNode:get_crafting_machine_prototype()
    -- get all crafting machines
    local filter = { filter = "crafting-machine" }
    local crafting_machines = game.get_filtered_entity_prototypes({ filter })
    -- get recipe category
    local recipe_category = self.recipe.category
    -- match category
    local matching_prototypes = {}
    for _, prototype in pairs(crafting_machines) do
        if prototype.crafting_categories[recipe_category] ~= nil then
            matching_prototypes[#matching_prototypes + 1] = prototype
        end
    end

    -- select first preferred
    for _, crafting_machine in ipairs(global.settings[self.player_index].factory_priority) do
        for _, matching_prototype in ipairs(matching_prototypes) do
            if crafting_machine.name == matching_prototype.name then
                return get_entity_prototype(matching_prototype.name)
            end
        end
    end
    -- if there is no player preference, select first available
    print_log("no player preference matches recipe prototype, the recipe is probably uncraftable for now.", logging.D)
    return get_entity_prototype(matching_prototypes[1].name)
end

--- @return LuaRecipePrototype belt prototype
function AssemblerNode:get_preferred_belt()
    return game.recipe_prototypes[ALL_BELTS[global.settings[self.player_index].belt]]
end

--- @class BlueprintGraph
--- @field inputs table<ingredient_name, AssemblerNode> input ingredients
--- @field outputs table<ingredient_name, AssemblerNode> output ingredients
--- @field dict table<recipe_name, AssemblerNode> all assembler nodes
--- @field player_index player_index
BlueprintGraph = {}
function BlueprintGraph.__index(t, k)
    return BlueprintGraph[k] or Table[k] or t.dict[k]
end

--- @return BlueprintGraph
function BlueprintGraph.new(player_index)
    o = { player_index = player_index }
    o.inputs = newtable {}
    o.outputs = newtable {}
    o.dict = newtable {}
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
    local others = self.inputs:shallow_copy()
    local to_remove = {}
    for input_name, input_node in pairs(self.inputs) do
        others[input_name] = nil
        if self:__ingredient_fully_used_by(input_name, others:keys()) then
            to_remove[input_name] = input_node
        end
        others[input_name] = input_node
    end
    for input_name, _ in pairs(to_remove) do
        --debug_print(input_name.." is covered")
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
        insert_blueprint(self.player_index, output_node:generate_section().entities)
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
                new_speed = crafting_speed / (product.amount or ((product.amount_max + product.amount_min) / 2) or 1)
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
        return newtable { self[item_name] }
    end
    local out = newtable {}
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
    local out = newtable {}
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
    products = newtable {}
    for _, node in ipairs(self:__assemblers_whose_ingredients_have(ingredient_name)) do
        for _, p in ipairs(node.recipe.products) do
            products[#products + 1] = p.name
        end
    end
    return products:all(function(p)
        return self:__ingredient_fully_used_by(p, item_list)
    end)
end

--- insert an blueprint to player's inventory, fail if inventory is full
--- @param player_index player_index
--- @param entities Entity[]
--- @return nil|LuaItemStack nilable, item stack representing the blueprint in the player's inventory
function insert_blueprint(player_index, entities)
    local player_inventory = game.players[player_index].get_main_inventory()
    if not player_inventory.can_insert("blueprint") then
        print_log("player's inventory is full, can't insert a new blueprint", logging.I)
        return
    end
    player_inventory.insert("blueprint")
    for i = 1, #player_inventory, 1 do
        if player_inventory[i].is_blueprint and not player_inventory[i].is_blueprint_setup() then
            player_inventory[i].set_blueprint_entities(entities)
            return player_inventory[i]
        end
    end
end

function update_player_crafting_machine_priorities(player_index)
    --- @return HelperTable|LuaEntityPrototype[]
    local function all_factories()
        local factories = newtable()
        for _, entity in pairs(game.get_filtered_entity_prototypes({
            { filter = "crafting-machine" },
            { filter = "hidden", invert = true, mode = "and" },
            { filter = "blueprintable", mode = "and" } })) do
            factories[#factories + 1] = entity
        end
        return factories
    end
    --- @type LuaRecipePrototype[]|ArrayList
    local unlocked_recipes = Table.filter(game.players[player_index].force.recipes, function(recipe)
        return not recipe.hidden and recipe.enabled
    end)

    local all_factory_list = all_factories()
    local unlocked_factories = {}
    for _, factory in ipairs(all_factory_list) do
        for _, recipe in pairs(unlocked_recipes) do
            if Table.has(recipe.products, factory, function(a, b)
                return a.name == b.name
            end) then
                unlocked_factories[#unlocked_factories + 1] = recipe
                break
            end
        end
    end

    local factory_priority = global.settings[player_index].factory_priority

    for _, unlocked_factory in ipairs(unlocked_factories) do
        if not Table.has(factory_priority, unlocked_factory, function(a, b)
            return a.name == b.name
        end) then
            ArrayList.insert(factory_priority, unlocked_factory)
        end
    end
end