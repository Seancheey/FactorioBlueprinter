require("helper")
require("prototype_info")

--- @alias recipe_prototype any
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

function all_factories()
    local factories = {}
    for _, entity in pairs(game.entity_prototypes) do
        if entity.crafting_categories and not entity.flags["hidden"] and entity.name ~= "character" then
            factories[#factories + 1] = entity
        end
    end
    return factories
end

function belt_speed_of(item_name)
    return game.entity_prototypes[item_name].belt_speed
end

function preferred_belt(player_index)
    return ALL_BELTS[global.settings[player_index].belt]
end

--- @class AssemblerNode represent a group of assemblers for crafting a single recipe
--- @field recipe recipe_prototype
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
        name = crafting_machine.name
    })

    -- specify available parallel transporting lines
    --- @class fulfilled_line
    --- @field item boolean true if it is unavailable
    --- @field fluid boolean true if fluid is unavailable

    --- @type table<number, fulfilled_line> key is y coordinate of the line
    fulfilled_lines = {}
    --- @type number[]
    line_check_order = {}
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

    --- @type table<"'input'"|"output", table[]> fluid boxes position of the crafting machine, if available
    local fluid_box_positions = {}
    for _, connection_type in ipairs({ "output", "input" }) do
        fluid_box_positions[connection_type] = newtable(crafting_machine.fluid_boxes)
                :filter(
                function(box)
                    local out = type(box) == "table" and box.production_type == connection_type
                    debug_print(serpent.line(box) .. " == " .. serpent.line(out))
                    return out
                end)
                :map(
                function(b)
                    return b.pipe_connections[1].position
                end)
    end
    local input_fluid_index = 1
    -- concatenate ingredients and products together
    for is_output, crafting_item_list in pairs({ [false] = self.recipe.ingredients, [true] = self.recipe.products }) do
        for _, crafting_item in ipairs(crafting_item_list) do
            -- find next available transporting line to fill
            for _, y in ipairs(line_check_order) do
                local line = fulfilled_lines[y]
                if not line[crafting_item.type] then
                    local y_closer_to_factory = y - (y > 0 and 1 or -1)
                    if crafting_item.type == "fluid" and
                            -- fluid box's connection position and transport line is at same side
                            fluid_box_positions[(is_output and "output" or "input")][input_fluid_index][2] * y > 0 and
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
                        -- TODO add connection pipe

                        break
                    elseif crafting_item.type == "item" then
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
                        -- TODO add inserter

                        break
                    end
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
    debug_print("W: no player preference matches recipe prototype")
    return get_entity_prototype(matching_prototypes[1].name)
end

--- @return any belt prototype
function AssemblerNode:get_preferred_belt()
    return game.entity_prototypes["transport-belt"]
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
    nodes = self:__assemblers_whose_ingredients_have(item_name)
    if nodes:any(function(x)
        return self.outputs:has(x)
    end) then
        debug_print("I: ingredient can't be more advanced")
        return
    end

    self.inputs[item_name] = nil
    for _, node in pairs(nodes) do
        for _, product in ipairs(node.products) do
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
        for _, ingredient in pairs(node.ingredients) do
            self.inputs[ingredient.name] = node
            viable = true
        end
    end
    if viable then
        self.inputs[item_name] = nil
    end
end

function BlueprintGraph:generate_blueprint()
    -- insert a new item into player's inventory
    game.players[self.player_index].insert("blueprint")
    local item = game.players[self.player_index].get_main_inventory().find_item_stack("blueprint")
    for _, output_node in pairs(self.outputs) do
        item.set_blueprint_entities(output_node:generate_section().entities)
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
                debug_print("output:" .. product.name)
                self.outputs[product.name] = node
            end
        end
        local new_speed
        for _, product in ipairs(node.products) do
            if product.name == recipe_name then
                new_speed = crafting_speed / product.amount
                node.recipe_speed = node.recipe_speed + new_speed
                break
            end
        end
        if new_speed == nil then
            debug_print("E: speed setup for " .. recipe_name .. " failed")
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
        debug_print(recipe_name .. " doesn't have a recipe. Error")
    end
end

function BlueprintGraph:__assemblers_whose_products_have(item_name)
    if self[item_name] then
        return newtable { self[item_name] }
    end
    local out = newtable {}
    for _, node in pairs(self.dict) do
        for _, product in pairs(node.products) do
            if product.name == item then
                out[#out + 1] = node
                break
            end
        end
    end
    return out
end

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
        for _, ingredient in ipairs(node.ingredients) do
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
        for _, p in ipairs(node.products) do
            products[#products + 1] = p.name
        end
    end
    --debug_print(ingredient_name.."'s products:"..products:tostring())
    return products:all(function(p)
        return self:__ingredient_fully_used_by(p, item_list)
    end)
end
