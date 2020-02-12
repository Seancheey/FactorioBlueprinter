require("helper")
IngredientNode = {name = "", item_per_sec = 0, parents= {}, children = {}}
IngredientNode.__index = IngredientNode

function IngredientNode:new(o)
    o.parents = o.parents or {}
    o.children = o.children or {}
    setmetatable(o,self)
    return o
end

function IngredientNode:add_child(child)
    self.children[child.name] = child
end

function IngredientNode:add_parent(parent)
    self.parents[parent.name] = parent
end

function IngredientNode:is_sole_product_of(other)
    if self == other then
        return true
    elseif #other.parents == 0 then
        return false
    else
        for i, parent in ipairs(other.parents) do
            if not self.is_sole_product_of(parent) then
                return false
            end
        end
        return true
    end
end

function generate_dependency_graph(player_index)
    dependency = {dict = {}, outputs = {}, inputs = {}}
    for k, item_choice in pairs(global.blueprint_outputs[player_index]) do
        if item_choice.recipe then
            generate_dependency_helper(item_choice.recipe, item_choice.crafting_speed, dependency, true)
        end
    end
    return dependency
end

function generate_dependency_helper(ingredient_name, crafting_speed, dependency_graph, final_product)
    final_product = final_product or false

    dependency_graph.dict[ingredient_name] = dependency_graph.dict[ingredient_name] or IngredientNode:new{name=ingredient_name, item_per_sec=0}
    local node = dependency_graph.dict[ingredient_name]
    if final_product then dependency_graph.outputs[ingredient_name] = node end
    node.item_per_sec = node.item_per_sec + crafting_speed

    --recursively generate its dependency
    local recipe = game.recipe_prototypes[ingredient_name]
    if recipe then
        for i,ingredient in ipairs(recipe.ingredients) do
            local child = generate_dependency_helper(ingredient.name, crafting_speed*ingredient.amount, dependency_graph)
            debug_print(child.name)
            node:add_child(child)
            child:add_parent(node)
        end
    else
        dependency_graph.inputs[ingredient_name] = node
    end
    return node
end
