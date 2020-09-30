---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by seancheey.
--- DateTime: 9/27/20 5:19 PM
---

require("util")
require("minheap")
require("prototype_info")

--- @class TransportChain
--- @field entity LuaEntity
--- @field entityDistance number
--- @field prevChain TransportChain
--- @field cumulativeDistance number
--- @type TransportChain
local TransportChain = {}

--- @param entity LuaEntityPrototype
--- @param prevChain TransportChain
--- @param travelDistance number
--- @return TransportChain
function TransportChain.new(entity, prevChain, travelDistance)
    travelDistance = travelDistance or 1
    return setmetatable({
        entity = entity,
        prevChain = prevChain,
        cumulativeDistance = prevChain and (prevChain.cumulativeDistance + travelDistance) or 0,
        entityDistance = travelDistance
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

--- @class VectorDict
--- @type VectorDict
local VectorDict = {}

function VectorDict.new()
    return setmetatable({}, { __index = VectorDict })
end

--- @param vector Vector2D
function VectorDict:put(vector, val)
    assertAllTruthy(self, vector, val)
    if self[vector.x] == nil then
        self[vector.x] = {}
    end
    self[vector.x][vector.y] = val
end

function VectorDict:get(vector)
    if self[vector.x] == nil then
        return nil
    end
    return self[vector.x][vector.y]
end

function VectorDict:forEach(f)
    for x, ys in pairs(self) do
        for y, val in pairs(ys) do
            f(Vector2D.new(x, y), val)
        end
    end
end

--- @param transportChain TransportChain
--- @param placeFunc fun(entity: LuaEntityPrototype)
local function placeAllEntities(transportChain, placeFunc)
    while transportChain ~= nil do
        if game.entity_prototypes[transportChain.entity.name].max_underground_distance then
            transportChain.entity.type = "input"
            placeFunc(transportChain.entity)
            -- if the entity is underground line, also place its complement
            placeFunc {
                name = transportChain.entity.name,
                position = Vector2D.fromDirection(transportChain.entity.direction or defines.direction.north):scale(transportChain.entityDistance - 1) + Vector2D.fromPosition(transportChain.entity.position),
                direction = transportChain.entity.direction,
                type = "output"
            }
        else
            placeFunc(transportChain.entity)
        end
        transportChain = transportChain.prevChain
    end
end

local function debug_visited_position(connector, visitedPositions)
    visitedPositions:forEach(
            function(vector)
                if connector.canPlaceEntityFunc(vector) then
                    connector.placeEntityFunc({ name = "small-lamp", position = vector })
                end
            end)
end

--- @class TransportLineConnector
--- @type TransportLineConnector
--- @field canPlaceEntityFunc fun(position: Vector2D): boolean
--- @field placeEntityFunc fun(entity: LuaEntityPrototype)
local TransportLineConnector = {}

TransportLineConnector.__index = TransportLineConnector

--- @param canPlaceEntityFunc fun(position: Vector2D): boolean
--- @return TransportLineConnector
function TransportLineConnector.new(canPlaceEntityFunc, placeEntityFunc)
    assert(canPlaceEntityFunc and placeEntityFunc)
    return setmetatable(
            { canPlaceEntityFunc = canPlaceEntityFunc,
              placeEntityFunc = placeEntityFunc
            }, TransportLineConnector)
end

--- @class LineConnectConfig
--- @field allowUnderground boolean default true
--- @field preferHorizontal boolean default true

--- @param startingEntity LuaEntity
--- @param endingEntity LuaEntity
--- @param additionalConfig LineConnectConfig optional
function TransportLineConnector:buildTransportLine(startingEntity, endingEntity, additionalConfig)
    assertAllTruthy(self, startingEntity, endingEntity)
    startingEntity = {
        name = startingEntity.name,
        position = Vector2D.fromPosition(startingEntity.position),
        direction = startingEntity.direction or defines.direction.north
    }
    endingEntity = {
        name = endingEntity.name,
        position = Vector2D.fromPosition(endingEntity.position),
        direction = endingEntity.direction or defines.direction.north
    }
    local allowUnderground = true
    if additionalConfig and additionalConfig.allowUnderground ~= nil then
        allowUnderground = additionalConfig.allowUnderground
    end
    local preferHorizontal = (additionalConfig and (additionalConfig.preferHorizontal ~= nil)) and additionalConfig.preferHorizontal or true
    local visitedPositions = VectorDict.new()
    local priorityQueue = MinHeap.new()
    local startingEntityTargetPos = Vector2D.fromPosition(startingEntity.position) + Vector2D.fromDirection(startingEntity.direction or defines.direction.north)
    if not self.canPlaceEntityFunc(startingEntityTargetPos) then
        print_log("starting entity's target position is blocked")
        return
    end
    -- A* algorithm starts from endingEntity so that we don't have to consider/change last belt's direction
    priorityQueue:push(0, TransportChain.new(endingEntity, nil))
    local maxTryNum = 1000000
    local tryNum = 0
    while not priorityQueue:isEmpty() and tryNum < maxTryNum do
        --- @type TransportChain
        local transportChain = priorityQueue:pop().val
        if transportChain.entity.position.x == startingEntityTargetPos.x and transportChain.entity.position.y == startingEntityTargetPos.y then
            placeAllEntities(transportChain, self.placeEntityFunc)
            print_log("Algorithm spent " .. tostring(tryNum) .. " number of tries to find solution")
            return
        end
        for entity, travelDistance in pairs(self:surroundingCandidates(transportChain, visitedPositions, game.entity_prototypes[startingEntity.name], allowUnderground)) do
            assert(entity and travelDistance)
            local newChain = TransportChain.new(entity, transportChain, travelDistance)
            priorityQueue:push(self:estimateDistance(entity.position, startingEntityTargetPos, preferHorizontal, not preferHorizontal) + newChain.cumulativeDistance, newChain)
            visitedPositions:put(transportChain.entity.position, newChain.cumulativeDistance)
        end
        tryNum = tryNum + 1
    end
    if priorityQueue:isEmpty() then
        print_log("finding terminated early since there is no more places to find")
    else
        print_log("Failed to connect transport line within " .. tostring(maxTryNum) .. " trials")
    end
    return
end

--- @param basePrototype LuaEntityPrototype transport line's base entity prototype
--- @param transportChain TransportChain
--- @return table<LuaEntity, number> entity to its travel distance
function TransportLineConnector:surroundingCandidates(transportChain, visitedPositions, basePrototype, allowUnderground)
    assertAllTruthy(self, transportChain, basePrototype, allowUnderground)

    local underground_prototype = PrototypeInfo.underground_transport_prototype(basePrototype.name)
    --- @type table<LuaEntity, number>
    local candidates = {}
    --- @type table<defines.direction, boolean>
    local legalDirections
    if PrototypeInfo.is_underground_transport(transportChain.entity.name) then
        -- underground belt's input only allows one direction
        legalDirections = { [Vector2D.fromDirection(transportChain.entity.direction):reverse():toDirection()] = true }
    else
        -- normal belt would allow 3 legal directions
        legalDirections = {
            [defines.direction.north] = true,
            [defines.direction.west] = true,
            [defines.direction.south] = true,
            [defines.direction.east] = true
        }
        legalDirections[transportChain.entity.direction or defines.direction.north] = nil
    end
    for direction, _ in pairs(legalDirections) do
        local directionVector = Vector2D.fromDirection(direction)
        -- test if we can place it underground
        if allowUnderground then
            for underground_distance = underground_prototype.max_underground_distance + 1, 2, -1 do
                local newPos = directionVector:scale(underground_distance) + Vector2D.fromPosition(transportChain.entity.position)
                if self:canPlace(newPos, transportChain.cumulativeDistance + underground_distance, visitedPositions, transportChain.entity.position) then
                    candidates[{
                        name = underground_prototype.name,
                        direction = directionVector:reverse():toDirection(),
                        position = newPos
                    }] = underground_distance
                end
            end
        end
        -- test if we can place it on ground
        local onGroundPos = directionVector + Vector2D.fromPosition(transportChain.entity.position)
        if self:canPlace(onGroundPos, transportChain.cumulativeDistance + 1, visitedPositions, transportChain.entity.position) then
            candidates[{
                name = basePrototype.name,
                direction = directionVector:reverse():toDirection(),
                position = onGroundPos
            }] = 1
        end
    end
    local candidates_string = ""
    for candidate, _ in pairs(candidates) do
        candidates_string = candidates_string .. serpent.line(candidate.position) .. ", "
    end
    print_log("belt " .. serpent.line(transportChain.entity.position) .. "'s candidates = " .. candidates_string)
    return candidates
end

--- @param position Vector2D
--- @param visitedPositions VectorDict
function TransportLineConnector:canPlace(position, cumulativeDistance, visitedPositions, targetPos)
    assertAllTruthy(self, position, visitedPositions)
    local currentMinDistance = visitedPositions:get(targetPos)
    if currentMinDistance and currentMinDistance <= cumulativeDistance then
        return false
    end
    if not self.canPlaceEntityFunc(position) then
        return false
    end
    return true
end

--- A* algorithm's heuristics cost
--- @param entity1 LuaEntity
--- @param entity2 LuaEntity
function TransportLineConnector:estimateDistance(position1, position2, rewardHorizontalFirst, rewardVerticalFirst)
    local dx = math.abs(position1.x - position2.x)
    local dy = math.abs(position1.y - position2.y)
    -- break A* cost tie by rewarding going to same y-level, but reward is no more than 1
    local reward = (rewardHorizontalFirst and (1 / (dy + 2)) or 0) + (rewardVerticalFirst and (1 / (dx + 2)) or 0)
    print_log("reward = " .. tostring(reward))
    return (dx + dy - reward) * 1.5
end

return TransportLineConnector