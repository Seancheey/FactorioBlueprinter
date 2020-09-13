local test_all = true

require("gui.gui")

function start_unit_tests()
    if test_all then
        test_array_list()
    end
end

function insert_test_blueprint(recipe_name, player_index)
    local graph = BlueprintGraph.new(player_index)
    --- @type OutputSpec[]
    local output_specs = { { ingredient = recipe_name, unit = 1, crafting_speed = 10 } }
    graph:generate_graph_by_outputs(output_specs)
    graph:generate_blueprint()
end

function test_array_list()
    local a = ArrayList.new()
    a:add(1)
    a:add(2)
    a:addAll({ 3, 4 })
    assert(a == { 1, 2, 3, 4 })
end