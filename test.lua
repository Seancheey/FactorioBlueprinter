local test_all = true

require("gui")

function start_unit_tests(player_index)
    if test_all then
        insert_test_blueprint("coal-liquefaction",player_index)
    end
end

function insert_test_blueprint(recipe_name, player_index)
    local graph = BlueprintGraph.new(player_index)
    --- @type OutputSpec[]
    local output_specs = { { ingredient = recipe_name, unit = 1, crafting_speed = 10 } }
    graph:generate_graph_by_outputs(output_specs)
    graph:generate_blueprint()
end