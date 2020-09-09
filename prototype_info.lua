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

--- fields that allows prototype.field == nil to exist.
local nullable_fields = newtable({ "fluid_boxes"})

--- @return any an entity prototype with additional information if available
function get_entity_prototype(name)
    local entity = game.entity_prototypes[name]
    return setmetatable({}, {
        __index = function(_, k)
            debug_print(k)
            if nullable_fields:has(k) then
                if prototype_addition[name] then
                    return prototype_addition[name][k]
                else
                    return nil
                end
            else
                if prototype_addition[name] then
                    return prototype_addition[name][k] or entity[k]
                end
                return entity[k]
            end
        end
    })
end