---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by seancheey.
--- DateTime: 9/13/20 3:32 PM
---

PlayerInfo = {}
PlayerInfo.__index = PlayerInfo

--- @return LuaEntityPrototype[]
function PlayerInfo.unlocked_crafting_machines(player_index)
    local all_factory_list = toArrayList()
    for _, entity in pairs(game.get_filtered_entity_prototypes({
        { filter = "crafting-machine" },
        { filter = "hidden", invert = true, mode = "and" },
        { filter = "blueprintable", mode = "and" } })) do
        all_factory_list[#all_factory_list + 1] = entity
    end
    local unlocked_recipes = PlayerInfo.unlocked_recipes(player_index)

    local unlocked_factories = {}
    for _, factory in ipairs(all_factory_list) do
        for _, recipe in pairs(unlocked_recipes) do
            if ArrayList.has(recipe.products, factory, function(a, b)
                return a.name == b.name
            end) then
                unlocked_factories[#unlocked_factories + 1] = factory
                break
            end
        end
    end
    return unlocked_factories
end

--- @return LuaEntityPrototype[]
function PlayerInfo.unlocked_belts(player_index)

end

--- @return table<number, LuaEntityPrototype[]> inserters table, keyed by insert arm length, list is ordered by inserter speed, ascending, this list doesn't contain any filter inserter since we are not using them anyway
function PlayerInfo.unlocked_inserters(player_index)
    --- @type LuaEntityPrototype[]
    local inserter_list = toArrayList(PlayerInfo.unlocked_recipes(player_index)):filter(function(recipe)
        return game.entity_prototypes[recipe.name] and game.entity_prototypes[recipe.name].inserter_rotation_speed ~= nil and game.entity_prototypes[recipe.name].filter_count == 0
    end)                                                                        :map(function(recipe)
        return game.entity_prototypes[recipe.name]
    end)
    local sorted_lists = toArrayList()
    for _, inserter in ipairs(inserter_list) do
        local pickup_location = inserter.inserter_pickup_position
        print_log(serpent.line(pickup_location))
        local inserter_arm_length = math.max(math.floor(math.abs(pickup_location[1])), math.floor(math.abs(pickup_location[2])))
        if not sorted_lists[inserter_arm_length] then
            sorted_lists[inserter_arm_length] = toArrayList()
        end
        sorted_lists[inserter_arm_length]:insert_by_order(inserter, function(a, b)
            return a.inserter_rotation_speed < b.inserter_rotation_speed
        end)
    end
    print_log(serpent.block(sorted_lists:map(function(list)
        return list:map(function(inserter)
            return { name = inserter.name, filter_count = inserter.filter_count }
        end)
    end)))
    return sorted_lists
end

--- @return LuaRecipePrototype[]
function PlayerInfo.unlocked_recipes(player_index)
    assertAllTruthy(player_index)

    local all_recipes = game.get_player(player_index).force.recipes
    local unlocked_recipes = ArrayList.filter(all_recipes,
            function(recipe)
                return not recipe.hidden and recipe.enabled
            end)
    return unlocked_recipes
end

--- @return LuaEntityPrototype[]
function PlayerInfo.crafting_machine_priorities(player_index)
    return global.settings[player_index].factory_priority
end