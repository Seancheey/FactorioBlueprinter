---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by seancheey.
--- DateTime: 9/27/20 5:19 PM
---

require("util")
require("minheap")

--- @type Vector2D[]
local FourWayDirections = {
    Vector2D.fromDirection(defines.direction.north),
    Vector2D.fromDirection(defines.direction.east),
    Vector2D.fromDirection(defines.direction.south),
    Vector2D.fromDirection(defines.direction.west),
}

--- @class TransportChain
--- @field entity LuaEntity
--- @field prevChain TransportChain
--- @field travelDistance number
--- @type TransportChain
local TransportChain = {}

--- @param entity LuaEntityPrototype
--- @param prevChain TransportChain
--- @param travelDistance number
--- @return TransportChain
function TransportChain.new(entity, prevChain, travelDistance)
    return setmetatable({
        entity = entity,
        prevChain = prevChain,
        travelDistance = prevChain and (prevChain.travelDistance + (travelDistance or 1)) or 0
    }, { __index = TransportChain })
end

--- @return LuaEntity[]|ArrayList
function TransportChain:toEntityList()
    local list = ArrayList.new()
    local currentChain = self
    while currentChain ~= nil do
        list:add(currentChain.entity)
        currentChain = currentChain.prevChain
    end
    return list
end

--- @class TransportLineConnector
--- @type TransportLineConnector
--- @field canPlaceEntityFunc fun(position: Vector2D): boolean
local TransportLineConnector = {}

TransportLineConnector.__index = TransportLineConnector

--- @param canPlaceEntityFunc fun(position: Vector2D): boolean
--- @return TransportLineConnector
function TransportLineConnector.new(canPlaceEntityFunc)
    return setmetatable({ canPlaceEntityFunc = function()
        return true
    end }, TransportLineConnector)
end

--- @param startingEntity LuaEntity
--- @param endingEntity LuaEntity
--- @return LuaEntity[]
function TransportLineConnector:buildTransportLine(startingEntity, endingEntity)
    assertAllTruthy(self, startingEntity, endingEntity)
    local priorityQueue = MinHeap.new()
    -- A* algorithm starts from endingEntity so that we don't have to consider/change last belt's direction
    priorityQueue:push(0, TransportChain.new(endingEntity, nil))
    local tryNum = 10000
    while not priorityQueue:isEmpty() and tryNum > 0 do
        --- @type TransportChain
        local transportChain = priorityQueue:pop().val
        if transportChain.entity.position.x == startingEntity.position.x and transportChain.entity.position.y == startingEntity.position.y then
            return transportChain:toEntityList()
        end
        for entity, travelDistance in pairs(self:surroundingCandidates(transportChain, game.entity_prototypes[startingEntity.name])) do
            assert(entity and travelDistance)
            local newChain = TransportChain.new(entity, transportChain, travelDistance)
            priorityQueue:push(self:estimateDistance(entity, startingEntity) + newChain.travelDistance, newChain)
        end
        tryNum = tryNum - 1
    end
    if priorityQueue:isEmpty() then
        print_log("finding terminated early since there is no more places to find")
    else
        print_log("Failed to connect transport line within 10000 trials")
    end
    return {}
end

--- @param basePrototype LuaEntityPrototype transport line's base entity prototype
--- @param transportChain TransportChain
--- @return table<LuaEntity, number> entity to its travel distance
function TransportLineConnector:surroundingCandidates(transportChain, basePrototype)
    assertAllTruthy(self, transportChain, basePrototype)
    local underground_prototype = PrototypeInfo.underground_transport_prototype(basePrototype.name)
    local candidates = {}
    local bannedPos = Vector2D.fromDirection(transportChain.entity.direction or defines.direction.north)
    for _, direction in ipairs(FourWayDirections) do
        if direction ~= bannedPos then
            -- test if we can place it underground
            for underground_distance = underground_prototype.max_underground_distance, 2, -1 do
                local newPos = direction:scale(underground_distance) + Vector2D.fromPosition(transportChain.entity.position)
                if self:canPlace(newPos, transportChain) then
                    candidates[{
                        name = underground_prototype.name,
                        direction = direction:reverse():toDirection(),
                        position = newPos
                    }] = underground_distance
                end
            end
            -- test if we can place it on ground
            local onGroundPos = direction + Vector2D.fromPosition(transportChain.entity.position)
            if self:canPlace(onGroundPos, transportChain) then
                candidates[{
                    name = basePrototype.name,
                    direction = direction:reverse():toDirection(),
                    position = onGroundPos
                }] = 1
            end
        end
    end
    return candidates
end

--- @param position Vector2D
--- @param transportChain TransportChain
function TransportLineConnector:canPlace(position, transportChain)
    assertAllTruthy(self, position, transportChain)

    if not self.canPlaceEntityFunc(position) then
        return false
    end
    while transportChain ~= nil do
        if transportChain.entity.position.x == position.x and transportChain.entity.position.y == position.y then
            return false
        end
        transportChain = transportChain.prevChain
    end
    return true
end

--- A* algorithm's heuristics cost
--- @param entity1 LuaEntity
--- @param entity2 LuaEntity
function TransportLineConnector:estimateDistance(entity1, entity2)
    local dx = math.abs(entity1.position.x - entity2.position.x)
    local dy = math.abs(entity1.position.y - entity2.position.y)
    -- break A* cost tie by rewarding going to same y-level, but reward is no more than 1
    local reward = 1 / (dy + 2)
    return dx + dy - reward
end

return TransportLineConnector