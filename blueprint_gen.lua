require("helper")
AssemblerNode = {}
-- AssemblerNode class inherents Table class
function AssemblerNode.__index (t,k)
    return AssemblerNode[k] or Table[k] or t.recipe[k]
end

function AssemblerNode.new(o)
    assert(o.recipe)
    -- how fast the recipe should be done per sec
    o.recipe_speed = o.recipe_speed or 0
    -- target assembers that outputs are delivered to, in format of ingredient->node
    o.targets = o.targets or newtable{}
    -- source assembers that inputs are received from, in format of ingredient->node
    o.sources = o.sources or newtable{}
    setmetatable(o,AssemblerNode)
    return o
end

function AssemblerNode:is_sole_product_of(other)
    if self == other then
        return true
    elseif next(other.targets) == nil then
        return false
    else
        for _, parent in pairs(other.targets) do
            if not self:is_sole_product_of(parent) then
                return false
            end
        end
        return true
    end
end

function AssemblerNode:products_fully_consumed_by(nodes)
    assert(self and nodes)
    if next(self.targets) == nil then
        return false
    end
    if nodes:has(self) then
        return true
    end
    if self.targets:all(function (node) return node:products_fully_consumed_by(nodes) end) then
        return true
    end
    return false
end

function AssemblerNode:tostring()
    return "{"..self.name.."  sources:"..self.sources:keys():tostring()..", targets:"..self.targets:keys():tostring().."}"
end

BlueprintGraph = {}
function BlueprintGraph.__index(t, k)
    return BlueprintGraph[k] or Table[k] or t.dict[k]
end

function BlueprintGraph.new(o)
    o = o or {}
    -- input ingredients, in format of: ingredient name -> assembler node
    o.inputs = o.inputs or newtable{}
    -- output products, in format of: product name -> assembler node
    o.outputs = o.outputs or newtable{}
    -- all assember nodes, in format of recipe name -> assembler node
    o.dict = o.dict or newtable{}
    setmetatable(o, BlueprintGraph)
    return o
end

function BlueprintGraph:generate_graph_by_outputs(requirements)
    if is_final == nil then is_final = true end
    for _, requirement in ipairs(requirements) do
        if requirement.ingredient and requirement.crafting_speed then
            self:generate_assember(requirement.ingredient,requirement.crafting_speed, true)
        end
    end
end

function BlueprintGraph:generate_assember(recipe_name, crafting_speed, is_final)
    assert(self and recipe_name and crafting_speed and (is_final ~= nil))
    local recipe = game.recipe_prototypes[recipe_name]
    if recipe then
        -- setup current node
        self.dict[recipe_name] = self.dict[recipe_name] or AssemblerNode.new{recipe=recipe}
        local node = self.dict[recipe_name]
        if is_final then
            for _, product in ipairs(node.products) do
                debug_print("output:"..product.name)
                self.outputs[product.name] = node
            end
        end
        local new_speed = nil
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
                local child = self:generate_assember(child_recipe.name,ingredient.amount * new_speed,false)
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

function BlueprintGraph:assembers_whose_products_have(item_name)
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

function BlueprintGraph:assembers_whose_ingredients_have(item_name)
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

function BlueprintGraph:use_products_as_input(item_name)
    nodes = self:assembers_whose_ingredients_have(item_name)
    if nodes:any(function(x) return self.outputs:has(x) end) then
        debug_print("ingredient can't be more advanced")
        return
    end

    self.inputs[item_name] = nil
    for _, node in pairs(nodes) do
        for _, product in ipairs(node.products) do
            for _, target in pairs(self:assembers_whose_ingredients_have(product.name)) do
                self.inputs[product.name] = target
            end
        end
    end

    -- remove unecessary input sources that are fully covered by other sources
    local others = self.inputs:shallow_copy()
    local to_remove = {}
    for input_name, input_node in pairs(self.inputs) do
        others[input_name] = nil
        if input_node:products_fully_consumed_by(others) then
            to_remove[input_name] = input_node
        end
        others[input_name] = input_node
    end
    for input_name, node in ipairs(to_remove) do
        debug_print(input_name.." is covered")
        self.inputs[input_name] = nil
    end
end

function BlueprintGraph:use_ingredients_as_input(item_name)
    local viable = false
    for _, node in pairs(self:assembers_whose_products_have(item_name)) do
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


-- function generate_dependency_graph(player_index)
--     dependency = newtable{dict = newtable{}, outputs = newtable{}, inputs = newtable{}}
--     for k, item_choice in pairs(global.blueprint_outputs[player_index]) do
--         if item_choice.ingredient then
--             generate_dependency_helper(item_choice.ingredient, item_choice.crafting_speed, dependency, true)
--         end
--     end
--     return dependency
-- end

-- function generate_dependency_helper(ingredient_name, crafting_speed, dependency_graph, final_product)
--     final_product = final_product or false
--
--     dependency_graph.dict[ingredient_name] = dependency_graph.dict[ingredient_name] or AssemblerNode.new{name=ingredient_name, output_speed=0}
--     local node = dependency_graph.dict[ingredient_name]
--     if final_product then dependency_graph.outputs[ingredient_name] = node end
--     node.output_speed = node.output_speed + crafting_speed
--
--     --recursively generate its dependency
--     local recipe = game.recipe_prototypes[ingredient_name]
--     if recipe then
--         for i,ingredient in ipairs(recipe.sources) do
--             local child = generate_dependency_helper(ingredient.name, crafting_speed*ingredient.amount, dependency_graph)
--             node:add_child(child)
--             child:add_parent(node)
--         end
--     else
--         dependency_graph.inputs[ingredient_name] = node
--     end
--     return node
-- end
