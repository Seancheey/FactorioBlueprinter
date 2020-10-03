local test_all = true

require("gui.gui")

local testing_recipes = { "copper-plate", "transport-belt", "steel-chest", "advanced-oil-processing", "coal-liquefaction", "explosives" }
local testing_speed = { 0.01, 1, 50 }

function start_unit_tests(player_index)
    if false then
        for _, recipe_name in ipairs(testing_recipes) do
            for _, speed in ipairs(testing_speed) do
                insert_assembler_node(recipe_name, player_index, speed)
            end
        end
    end
end

function insert_test_blueprint(recipe_name, player_index)
    local graph = BlueprintGraph.new(player_index)
    --- @type OutputSpec[]
    local output_specs = { { ingredient = recipe_name, unit = 1, crafting_speed = 10 } }
    graph:generate_graph_by_outputs(output_specs)
    graph:generate_blueprint()
end

function insert_assembler_node(recipe_name, player_index, recipe_speed)
    local node = AssemblerNode.new({ recipe = game.recipe_prototypes[recipe_name], player_index = player_index, recipe_speed = recipe_speed })
    local section = node:generate_section()
    PlayerInfo.insert_blueprint(player_index, section.entities)
end

