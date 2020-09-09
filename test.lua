local test_all = true

require("gui")

function start_unit_tests(player_index)
    if test_all then
        insert_test_blueprint(player_index)
    end
end

function insert_test_blueprint(player_index)
    local graph = BlueprintGraph.new(player_index)
    --- @type OutputSpec[]
    local output_specs = { { ingredient = "coal-liquefaction", unit = 1, crafting_speed = 10 } }
    graph:generate_graph_by_outputs(output_specs)
    graph:generate_blueprint()
end