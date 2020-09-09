local prototype_addition = {
    ["assembling-machine-2"] = {
        fluid_boxes = {
            {
                pipe_connections = { { position = { 0, -2 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { 0, 2 }, type = "output" } },
                production_type = "output",
            },
            off_when_no_fluid_recipe = true
        },
    },
    ["assembling-machine-3"] = {
        fluid_boxes = {
            {
                pipe_connections = { { position = { 0, -2 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { 0, 2 }, type = "output" } },
                production_type = "output",
            },
            off_when_no_fluid_recipe = true
        },
    },
    ["chemical-plant"] = {
        fluid_boxes = {
            {
                pipe_connections = { { position = { -1, -2 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { 1, 2 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { -1, 2 }, type = "output" } },
                production_type = "output"
            },
            {
                pipe_connections = { { position = { 1, 2 } }, type = "output" },
                production_type = "output"
            }
        },
    },
    ["oil-refinery"] = {
        fluid_boxes = {
            {
                pipe_connections = { { position = { -1, 3 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { 1, 3 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { -2, -3 } } },
                production_type = "output"
            },
            {
                pipe_connections = { { position = { 0, -3 } } },
                production_type = "output"
            },
            {
                pipe_connections = { { position = { 2, -3 } } },
                production_type = "output"
            }
        },
    }
}

--- @return any an entity prototype with additional information if available
function get_entity_prototype(name)
    local entity = game.entity_prototypes[name]
    if prototype_addition[name] then
        return setmetatable({}, {
            __index = function(_, k)
                return prototype_addition[name][k] or entity[k]
            end
        })
    end
    return entity
end