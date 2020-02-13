require("helper")
IngredientNode = {name = "", item_per_sec = 0, parents= newtable{}, children = newtable{}}
-- IngredientNode class inherents Table class
function IngredientNode.__index (t,k)
    return IngredientNode[k] or Table[k]
end

function IngredientNode:new(o)
    o.parents = o.parents or newtable{}
    o.children = o.children or newtable{}
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
    elseif next(other.parents) == nil then
        return false
    else
        for _, parent in pairs(other.parents) do
            if not self:is_sole_product_of(parent) then
                return false
            end
        end
        return true
    end
end

function IngredientNode:produce_only(nodes)
    assert(self and nodes)
    if nodes:has(self) then
        return true
    end
    if next(self.parents) == nil then
        return false
    end
    if self.parents:values():all(function (node) return node:produce_only(nodes) end) then
        return true
    end
    return false
end

function generate_dependency_graph(player_index)
    dependency = newtable{dict = newtable{}, outputs = newtable{}, inputs = newtable{}}
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
            node:add_child(child)
            child:add_parent(node)
        end
    else
        dependency_graph.inputs[ingredient_name] = node
    end
    return node
end
