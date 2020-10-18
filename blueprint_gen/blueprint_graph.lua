require("prototype_info")
local PlayerInfo = require("player_info")
local assertNotNull = require("__MiscLib__/assert_not_null")
--- @type Logger
local logging = require("__MiscLib__/logging")
--- @type ArrayList
local ArrayList = require("__MiscLib__/array_list")
--- @type Copier
local Copier = require("__MiscLib__/copy")
local shallow_copy = Copier.shallow_copy
local BlueprintGeneratorUtil = require("blueprint_gen.util")
local average_amount_of = BlueprintGeneratorUtil.average_amount_of
--- @type AssemblerNode
local AssemblerNode = require("blueprint_gen.assembler_node")

--- @alias recipe_name string
--- @alias ingredient_name string

--- @class Entity
--- @field entity_number number unique identifier of entity
--- @field name string entity name
--- @field position Vector2D
--- @field direction any defines.direction.east/south/west/north

--- @class ConnectionPoint
--- @field ingredients table<ingredient_name, number> ingredients that the connection point is transporting to number of items transported per second
--- @field position Vector2D
--- @field connection_entity LuaEntityPrototype


--- @class BlueprintGraph
--- @field inputs table<ingredient_name, AssemblerNode> input ingredients
--- @field outputs table<ingredient_name, AssemblerNode> output ingredients
--- @field dict table<recipe_name, AssemblerNode> all assembler nodes
--- @field player_index player_index
local BlueprintGraph = {}
function BlueprintGraph.__index(t, k)
    return BlueprintGraph[k] or ArrayList[k] or t.dict[k]
end

--- @return BlueprintGraph
function BlueprintGraph.new(player_index)
    local o = { player_index = player_index }
    o.inputs = ArrayList.new {}
    o.outputs = ArrayList.new {}
    o.dict = ArrayList.new {}
    setmetatable(o, BlueprintGraph)
    return o
end

--- @param output_specs OutputSpec[]
function BlueprintGraph:generate_graph_by_outputs(output_specs)
    assertNotNull(self, output_specs)

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
        logging.log("ingredient can't be more advanced", logging.I)
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
                logging.log("output:" .. product.name)
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
            logging.log("speed setup for " .. recipe_name .. " failed", logging.E)
            new_speed = 1
        end
        -- setup children nodes
        for _, ingredient in ipairs(node.ingredients) do
            local child_recipe = game.recipe_prototypes[ingredient.name]
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
        logging.log(recipe_name .. " doesn't have a recipe.", logging.E)
    end
end

--- @return AssemblerNode[]
function BlueprintGraph:__assemblers_whose_products_have(item_name)
    if self[item_name] then
        return ArrayList.new { self[item_name] }
    end
    local out = ArrayList.new {}
    for _, node in pairs(self.dict) do
        for _, product in pairs(node.recipe.products) do
            if product.name == item_name then
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
    local out = ArrayList.new {}
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
    local products = ArrayList.new {}
    for _, node in ipairs(self:__assemblers_whose_ingredients_have(ingredient_name)) do
        for _, p in ipairs(node.recipe.products) do
            products[#products + 1] = p.name
        end
    end
    return products:all(function(p)
        return self:__ingredient_fully_used_by(p, item_list)
    end)
end

return BlueprintGraph