IngredientNode = {name = "", item_per_sec = 0, parents= {}, children = {}}
function IngredientNode:new(o)
    o.parents = o.parents or {}
    o.children = o.children or {}
    setmetatable(o,self)
    self.__index = self
    return self
end

function IngredientNode:add_child(child)
    self.children[#self.children+1] = child
end

function IngredientNode:add_parent(parent)
    self.parents[#self.parents+1] = parent
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

function generate_dependency_helper(ingredient, crafting_speed, dependency_graph, final_product)
    final_product = final_product or false

    dependency_graph.dict[ingredient] = dependency_graph.dict[ingredient] or IngredientNode:new{name=ingredient, item_per_sec=0}
    local node = dependency_graph.dict[ingredient]
    if final_product then dependency_graph.outputs[ingredient] = node end
    node.item_per_sec = node.item_per_sec + crafting_speed

    --recursively generate its dependency
    local recipe = game.recipe_prototypes[ingredient]
    if recipe then
        for i,ingredient in ipairs(recipe.ingredients) do
            child = generate_dependency_helper(ingredient.name, crafting_speed*ingredient.amount, dependency_graph)
            node.add_child(child)
            child.add_parent(node)
        end
    else
        dependency_graph.inputs[ingredient] = node
    end
    return node
end
