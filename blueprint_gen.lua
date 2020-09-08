require("helper")

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

--- @class BlueprintSection
--- @field entities Entity[]
--- @field inlets Entity[] each element is one of entities
--- @field outlets Entity[] each element is one of entities

ALL_BELTS = {"transport-belt", "fast-transport-belt", "express-transport-belt"}
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
            factories[#factories+1] = entity
        end
    end
    return factories
end

function factories_of_recipe(recipe_name)
    local factories = {}
    for _, factory in pairs(all_factories()) do
        for entity_crafting_categories in next, factory.crafting_categories do
            if entity_crafting_categories == game.recipe_prototypes[recipe_name].category then
                factories[#factories+1] = factory
            end
        end
    end
    return factories
end

function preferred_factory_of_recipe(recipe_name, player_index)
    for _, factory in ipairs(global.settings[player_index].factory_priority) do
        for _, available in ipairs(factories_of_recipe(recipe_name)) do
            if factory == available then
                return factory
            end
        end
    end
    assert(false, recipe_name.." has no preferred factory")
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
function AssemblerNode.__index (t,k)
    return AssemblerNode[k] or Table[k] or t.recipe[k]
end

function AssemblerNode.new(o)
    assert(o.recipe and o.player_index)
    o.recipe_speed = o.recipe_speed or 0
    o.targets = o.targets or newtable{}
    o.sources = o.sources or newtable{}
    setmetatable(o,AssemblerNode)
    return o
end

function create_crafting_unit(entities, recipe_name, factory_name, belt_name, xoff, yoff, belt_positions, factory_off, inserter_positions)
    local factory_size = 3 -- should be determined from prototype
    if belt_positions == nil or factory_off == nil or inserter_positions == nil then
        -- three templates
        local input_num = #game.recipe_prototypes[recipe_name].ingredients
        local output_num = #game.recipe_prototypes[recipe_name].products
        local item_speeds = {}
        for _, ingredient in ipairs(game.recipe_prototypes[recipe_name].ingredients) do
            item_speeds[ingredient.name] = ingredient.amount * game.entity_prototypes[factory_name].crafting_speed
        end
        for _, product in ipairs(game.recipe_prototypes[recipe_name].products) do
            item_speeds[product.name] = product.amount * game.entity_prototypes[factory_name].crafting_speed
        end
        -- TODO: adjust inserter type according to item speeds
        if input_num == 1 and output_num == 1 then
            belt_positions = {[0]=defines.direction.north, [factory_size+3]=defines.direction.north}
            inserter_positions = {[1]={{name="fast-inserter", direction=defines.direction.south}}, [factory_size+2]={{name="fast-inserter", direction=defines.direction.south}}}
            factory_off = 2
        elseif input_num == 2 and output_num == 1 then
            belt_positions = {[0]=defines.direction.north, [factory_size+3]=defines.direction.north, [factory_size+4]=defines.direction.north}
            inserter_positions = {[1]={{name="fast-inserter", direction=defines.direction.south}}, [factory_size+2]={{name="fast-inserter", direction=defines.direction.south}, {name="long-handed-inserter", direction=defines.direction.south}}}
            factory_off = 2
        elseif input_num == 3 and output_num == 1 then
            belt_positions = {[0]=defines.direction.north, [1]=defines.direction.south, [factory_size+4]=defines.direction.north, [factory_size+5]=defines.direction.north}
            inserter_positions = {[2]={{name="fast-inserter", direction=defines.direction.north}, {name="long-handed-inserter", direction=defines.direction.south}}, [factory_size+3]={{name="fast-inserter", direction=defines.direction.south}, {name="long-handed-inserter", direction=defines.direction.south}}}
            factory_off = 3
        else
            debug_print("Unsupported recipe "..recipe_name.."with "..input_num.." inputs and "..output_num.." outputs")
        end
    end
    local eid = #entities+1
    -- setup belts
    for x = 0, factory_size-1 do
        for y, direction in pairs(belt_positions) do
            entities[eid] = {
                entity_number = eid,
                name = belt_name,
                position = {x=x+xoff,y=y+yoff},
                direction = defines.direction.east,
            }
            eid = eid + 1
        end
    end
    -- -- setup factory
    entities[eid] = {
        entity_number = eid,
        name = factory_name,
        position = {x=xoff+math.floor(factory_size/2),y=math.floor(factory_size/2)+factory_off+yoff},
        recipe = recipe_name
    }
    eid = eid + 1
    -- setup inserters
    for y, inserters in pairs(inserter_positions) do
        for x, config in ipairs(inserters) do
            entities[eid] = {
                entity_number = eid,
                name = config.name,
                position = {x=x-1+xoff, y=y+yoff},
                direction = config.direction
            }
            eid = eid + 1
        end
    end
    return belt_positions, factory_off
end

function AssemblerNode:tostring()
    return "{"..self.recipe.."  sources:"..self.sources:keys():tostring()..", targets:"..self.targets:keys():tostring().."}"
end

function AssemblerNode:generate_blueprint(player_index, item, eid, xoff, yoff)
    if not xoff then xoff = 0 end
    if not yoff then yoff = 0 end
    -- determine if there is belt bottleneck for single row layout
    local belt_speed = belt_speed_of(ALL_BELTS[global.settings[player_index].belt]) --[[ should become player's preference later ]]
    local max_row = 1
    for _, product in ipairs(self.recipe.products) do
        if product.type == "item" then
            local row_num = product.amount * self.recipe_speed / belt_speed
            if row_num > max_row then max_row = row_num end
        end
    end
    for _, ingredient in ipairs(self.recipe.ingredients) do
        if ingredient.type == "item" then
            local row_num = ingredient.amount * self.recipe_speed / belt_speed
            if row_num > max_row then max_row = row_num end
        end
    end

    --return {inputs={ingre1={{x=1,y=2},{x=6,y=8}, ingre2={{x=1,y=2}}}, outputs={...}, width=, height=}
end

--- get a crafting machine prototype that user preferred
--- @return any crafting machine prototype
function AssemblerNode:get_crafting_machine_prototype()
    -- get all crafting machines
    local filter = {filter="crafting-machine"}
    local crafting_machines = game.get_filtered_entity_prototypes({filter})
    -- get recipe category
    local recipe_category = self.recipe.category
    -- match category
    local matching_prototypes = newtable(crafting_machines):filter(function (prototype)
        return newtable(prototype.crafting_categories):has(recipe_category)
    end)
    -- select first preferred
    for _, crafting_machine in ipairs(global.settings[self.player_index].factory_priority) do
        for _, matching_prototype in ipairs(matching_prototypes) do
            if crafting_machine == matching_prototype.name then
                return matching_prototype
            end
        end
    end
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
    o = {player_index = player_index}
    o.inputs = newtable{}
    o.outputs = newtable{}
    o.dict = newtable{}
    setmetatable(o, BlueprintGraph)
    return o
end

function BlueprintGraph:generate_graph_by_outputs(requirements)
    if is_final == nil then is_final = true end
    for _, requirement in ipairs(requirements) do
        if requirement.ingredient and requirement.crafting_speed then
            self:generate_assembler(requirement.ingredient,requirement.crafting_speed, true)
        end
    end
end

function BlueprintGraph:generate_assembler(recipe_name, crafting_speed, is_final)
    assert(self and recipe_name and crafting_speed and (is_final ~= nil))
    local recipe = game.recipe_prototypes[recipe_name]
    if recipe then
        -- setup current node
        self.dict[recipe_name] = self.dict[recipe_name] or AssemblerNode.new{recipe=recipe, player_index=self.player_index}
        local node = self.dict[recipe_name]
        if is_final then
            for _, product in ipairs(node.products) do
                debug_print("output:"..product.name)
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
        if new_speed == nil then debug_print("speed setup for "..recipe_name.." failed") end
        -- setup children nodes
        for _, ingredient in ipairs(node.ingredients) do
            child_recipe = game.recipe_prototypes[ingredient.name]
            if child_recipe then
                local child = self:generate_assembler(child_recipe.name,ingredient.amount * new_speed,false)
                node.sources[ingredient.name] = child
                child.targets[recipe_name] = node
            else
                self.inputs[ingredient.name] = node
            end
        end
        return node
    else
        debug_print(recipe_name.." doesn't have a recipe. Error")
    end
end

function BlueprintGraph:assemblers_whose_products_have(item_name)
    if self[item_name] then return newtable{self[item_name]} end
    local out = newtable{}
    for _, node in pairs(self.dict) do
        for _, product in pairs(node.products) do
            if product.name == item then
                out[#out+1] = node
                break
            end
        end
    end
    return out
end

function BlueprintGraph:assemblers_whose_ingredients_have(item_name)
    assert(self and item_name)
    local out = newtable{}
    if self[item_name] then
        for _, node in pairs(self[item_name].targets) do
            out[#out+1] = node
        end
        return out
    end
    for _, node in pairs(self.dict) do
        for _, ingredient in ipairs(node.ingredients) do
            if ingredient.name == item_name then
                out[#out+1] = node
                break
            end
        end
    end
    return out
end

function BlueprintGraph:ingredient_fully_used_by(ingredient_name, item_list)
    if self.outputs[ingredient_name] then
        return false
    end
    if item_list:has(ingredient_name) then
        return true
    end
    products = newtable{}
    for _, node in ipairs(self:assemblers_whose_ingredients_have(ingredient_name)) do
        for _, p in ipairs(node.products) do
            products[#products+1] = p.name
        end
    end
    --debug_print(ingredient_name.."'s products:"..products:tostring())
    return products:all(function(p) return self:ingredient_fully_used_by(p, item_list) end)
end

function BlueprintGraph:use_products_as_input(item_name)
    self.__index = BlueprintGraph.__index
    setmetatable(self, self)
    nodes = self:assemblers_whose_ingredients_have(item_name)
    if nodes:any(function(x) return self.outputs:has(x) end) then
        debug_print("ingredient can't be more advanced")
        return
    end

    self.inputs[item_name] = nil
    for _, node in pairs(nodes) do
        for _, product in ipairs(node.products) do
            for _, target in pairs(self:assemblers_whose_ingredients_have(product.name)) do
                self.inputs[product.name] = target
            end
        end
    end

    -- remove unnecessary input sources that are fully covered by other sources
    local others = self.inputs:shallow_copy()
    local to_remove = {}
    for input_name, input_node in pairs(self.inputs) do
        others[input_name] = nil
        if self:ingredient_fully_used_by(input_name, others:keys()) then
            to_remove[input_name] = input_node
        end
        others[input_name] = input_node
    end
    for input_name, node in pairs(to_remove) do
        --debug_print(input_name.." is covered")
        self.inputs[input_name] = nil
    end
end

function BlueprintGraph:use_ingredients_as_input(item_name)
    self.__index = BlueprintGraph.__index
    setmetatable(self, self)
    local viable = false
    for _, node in pairs(self:assemblers_whose_products_have(item_name)) do
        for _, ingredient in pairs(node.ingredients) do
            self.inputs[ingredient.name] = node
            viable = true
        end
    end
    if viable then
        self.inputs[item_name] = nil
    end
end

function BlueprintGraph:tostring(nodes, indent)
    local indent = indent or 0
    local nodes = nodes or self.outputs
    local indent_str = ""
    for i=1,indent do indent_str = indent_str.."  " end
    local out = ""
    for _, node in pairs(nodes) do
        out = out..indent_str..node:tostring().."\n"
        out = out..self:tostring(node.sources,indent+1).."\n"
    end
    return out:sub(1,-2)
end

function BlueprintGraph:generate_blueprint()
    -- insert a new item into player's inventory
    game.players[self.player_index].insert("blueprint")
    local item = game.players[self.player_index].get_main_inventory().find_item_stack("blueprint")
    local entities={}
    create_crafting_unit(entities, "inserter", factories_of_recipe("inserter")[1].name, preferred_belt(self.player_index), 0, 0)
    item.set_blueprint_entities(entities)
end
