PlayerInfo = {}
PlayerInfo.__index = PlayerInfo

--- @class PlayerSetting
--- @field factory_priority LuaEntityPrototype[] factory prototype
--- @field belt number
--- @field direction_spec BlueprintDirectionSpec

--- @class BlueprintDirectionSpec
--- @field ingredientDirection defines.direction player UI visible transformation
--- @field productPosition defines.direction player UI visible transformation
--- @field productDirection defines.direction player UI visible transformation

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

--- @return table<number, LuaEntityPrototype[]> inserters table, keyed by insert arm length, list is ordered by inserter speed, ascending, this list doesn't contain any filter/burner inserter since we are not using them anyway
function PlayerInfo.unlocked_inserters(player_index)
    --- @type LuaEntityPrototype[]
    local inserter_list = toArrayList(PlayerInfo.unlocked_recipes(player_index)):filter(function(recipe)
        return game.entity_prototypes[recipe.name] and game.entity_prototypes[recipe.name].inserter_rotation_speed ~= nil and game.entity_prototypes[recipe.name].filter_count == 0 and recipe.name ~= "burner-inserter"
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
    --print_log(serpent.block(sorted_lists:map(function(list)
    --    return list:map(function(inserter)
    --        return { name = inserter.name, filter_count = inserter.filter_count, inserter_rotation_speed = inserter.inserter_rotation_speed}
    --    end)
    --end)))
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

--- get a crafting machine prototype that user preferred
--- @return LuaEntityPrototype crafting machine prototype
function PlayerInfo.get_crafting_machine_prototype(player_index, recipe)
    -- get all crafting machines
    local filter = { filter = "crafting-machine" }
    local crafting_machines = game.get_filtered_entity_prototypes({ filter })
    -- get recipe category
    local recipe_category = recipe.category
    -- match category
    local matching_prototypes = {}
    for _, prototype in pairs(crafting_machines) do
        if prototype.crafting_categories[recipe_category] ~= nil then
            matching_prototypes[#matching_prototypes + 1] = prototype
        end
    end

    -- select first preferred
    for _, crafting_machine in ipairs(PlayerInfo.crafting_machine_priorities(player_index)) do
        for _, matching_prototype in ipairs(matching_prototypes) do
            if crafting_machine.name == matching_prototype.name then
                return get_entity_prototype(matching_prototype.name)
            end
        end
    end
    -- if there is no player preference, select first available
    print_log("no player preference matches recipe prototype, the recipe is probably uncraftable for now.", logging.D)
    return get_entity_prototype(matching_prototypes[1].name)
end

--- @return LuaEntityPrototype
function PlayerInfo.get_preferred_belt(player_index)
    return game.entity_prototypes[ALL_BELTS[global.settings[player_index].belt]]
end

--- @return LuaTechnology[]|ArrayList
function PlayerInfo.researched_technologies(player_index)
    local all_technologies = game.players[player_index].force.technologies
    local researched_technologies = ArrayList.new()
    for _, technology in pairs(all_technologies) do
        if technology.researched then
            researched_technologies:add(technology)
        end
    end
    return researched_technologies
end

--- @param inserter_prototype LuaEntityPrototype
--- @return number stack size
function PlayerInfo.inserter_stack_size(player_index, inserter_prototype)
    assertAllTruthy(player_index, inserter_prototype)
    --- @type LuaForce
    local force = game.players[player_index].force
    return inserter_prototype.stack and (force.stack_inserter_capacity_bonus + 2) or (force.inserter_stack_size_bonus + 1)
end

--- @param inserter_prototype LuaEntityPrototype
--- @return number number of items that the inserter can transfer per second
function PlayerInfo.inserter_items_speed(player_index, inserter_prototype)
    assertAllTruthy(player_index, inserter_prototype)
    return (inserter_prototype.inserter_rotation_speed * 60) * PlayerInfo.inserter_stack_size(player_index, inserter_prototype)
end

--- @class InternalDirectionSpec
--- @field linearIngredientDirection defines.direction internal specification
--- @field linearOutputDirection defines.direction internal specification
--- @field blueprintRotation number num of 90 degrees to rotate

--- @param original_output_position defines.direction
--- @return InternalDirectionSpec
function PlayerInfo.get_internal_direction_spec(player_index, original_output_position)
    assertAllTruthy(player_index, original_output_position)

    local ui_spec = PlayerInfo.direction_settings(player_index)
    --- @type InternalDirectionSpec
    local internal_spec = {}

    internal_spec.blueprintRotation = ((ui_spec.productPosition - original_output_position) % 8) / 2
    internal_spec.linearIngredientDirection = (ui_spec.ingredientDirection - (internal_spec.blueprintRotation * 2)) % 8
    internal_spec.linearOutputDirection = (ui_spec.productDirection - (internal_spec.blueprintRotation * 2)) % 8

    return internal_spec
end

--- @return BlueprintDirectionSpec a modifiable direction specification
function PlayerInfo.direction_settings(player_index)
    return global.settings[player_index].direction_spec
end

function PlayerInfo.set_default_settings(player_index)
    global.settings[player_index] = {
        belt = 1,
        factory_priority = {},
        direction_spec = { ingredientDirection = defines.direction.east, productDirection = defines.direction.east, productPosition = defines.direction.north }
    }
end