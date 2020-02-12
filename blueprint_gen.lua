RecipeNode = {name = "", item_per_sec = 0, parents= {}, children = {}}
function RecipeNode:new(o)
    o.parents = o.parents or {}
    o.children = o.children or {}
    setmetatable(o,self)
    self.__index = self
    return self
end

function RecipeNode:add_child(child)
    self.children[#self.children+1] = child
end

function RecipeNode:add_parent(parent)
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

function generate_dependency_helper(recipe_name, crafting_speed, dependency_graph, final_product)
    final_product = final_product or false

    dependency_graph.dict[recipe_name] = dependency_graph.dict[recipe_name] or RecipeNode:new{name=recipe_name, item_per_sec=0}
    local node = dependency_graph.dict[recipe_name]
    if final_product then dependency_graph.outputs[recipe_name] = node end
    node.item_per_sec = node.item_per_sec + crafting_speed

    --recursively generate its dependency
    local recipe = game.recipe_prototypes[recipe_name]
    if recipe then
        for i,ingredient in ipairs(recipe.ingredients) do
            child = generate_dependency_helper(ingredient.name, crafting_speed*ingredient.amount, dependency_graph)
            node.add_child(child)
            child.add_parent(node)
        end
    else
        dependency_graph.inputs[recipe_name] = node
    end
    return node
end
