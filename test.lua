local test_all = true

require("gui.gui")

local TransportLineConnector = require("transport_line_connector")

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
    test_transport_line_connector()
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

function test_transport_line_connector()
    local surface = game.surfaces[1]
    function canPlace(position)
        return surface.can_place_entity("transport-belt", position)
    end
    local surfaceConnector = TransportLineConnector.new(canPlace)
    local entities = surfaceConnector:buildTransportLine({ name = "transport-belt", position = { x = 0, y = 0 } }, { name = "transport-belt", position = { x = 10, y = 10 } })
    print_log(serpent.line(ArrayList.map(entities, function(entity)
        return entity.position
    end)))
    for _, entity in ipairs(entities) do
        surface.create_entity {
            name = entity.name,
            position = entity.position,
            direction = entity.direction
        }
    end
end