--- Since we cannot access prototype information outside game loading stage, we need extra prototype information to support any crafting machines with fluid boxes.
local prototype_addition = {
    -- Below is fluid prototypes of the base game
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
                pipe_connections = { { position = { 1, -2 }, type = "input" } },
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
                pipe_connections = { { position = { 1, 3 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { -1, 3 }, type = "input" } },
                production_type = "input"
            },
            {
                pipe_connections = { { position = { 2, -3 } } },
                production_type = "output"
            },
            {
                pipe_connections = { { position = { 0, -3 } } },
                production_type = "output"
            },
            {
                pipe_connections = { { position = { -2, -3 } } },
                production_type = "output"
            }
        },
    }
    -- Below is prototypes of mods, add your mod fluid box prototype here
}

-- TODO:  remove this field and replace it with automatic inferred belts
ALL_BELTS = { "transport-belt", "fast-transport-belt", "express-transport-belt" }


--- fields that allows prototype.field == nil to exist.
local nullable_fields = toArrayList({ "fluid_boxes" })

--- @return any an entity prototype with additional information if available
function get_entity_prototype(name)
    local entity = game.entity_prototypes[name]
    return setmetatable({}, {
        __index = function(_, k)
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


local PrototypeInfo = {}
--- @param prototype LuaEntityPrototype
--- @return Vector2D
function PrototypeInfo.get_size(prototype)
    return Vector2D.new(
            math.floor(prototype.selection_box.right_bottom.x - prototype.selection_box.left_top.x + 0.5),
            math.floor(prototype.selection_box.right_bottom.y - prototype.selection_box.left_top.y + 0.5)
    )
end

local corresponding_underground_transport_line_table = {
    ["pipe"] = "pipe-to-ground",
    ["transport-belt"] = "underground-belt",
    ["fast-transport-belt"] = "fast-underground-belt",
    ["express-transport-belt"] = "express-underground-belt"
}

--- @param transport_name string prototype name of either a transport belt or a pipe
--- @return LuaEntityPrototype
function PrototypeInfo.underground_transport_prototype(transport_name)
    if corresponding_underground_transport_line_table[transport_name] ~= nil then
        return game.entity_prototypes[corresponding_underground_transport_line_table[transport_name]]
    else
        if game.entity_prototypes[transport_name].belt_speed then
            print_log(transport_name .. " is not one of known transport belt with underground version")
            return game.entity_prototypes["express-underground-belt"]
        elseif game.entity_prototypes[transport_name].fluid_capacity then
            print_log(transport_name .. "is not one of known pipe with underground version")
            return game.entity_prototypes["pipe-to-ground"]
        end
    end

    assert(false, transport_name .. " is neither a transport belt nor a pipe, and hence shall not have a corresponding underground version of it")
end

function PrototypeInfo.is_underground_transport(name)
    if game.entity_prototypes[name].max_underground_distance then
        return true
    end
    return false
end

function sprite_of(name)
    assert(type(name) == "string")
    if game.item_prototypes[name] then
        return "item/" .. name
    elseif game.fluid_prototypes[name] then
        return "fluid/" .. name
    elseif game.entity_prototypes[name] then
        return "entity/" .. name
    else
        print_log("failed to find sprite path for name " .. name)
    end
end

return PrototypeInfo