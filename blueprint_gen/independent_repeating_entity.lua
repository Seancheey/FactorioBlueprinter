local assertNotNull = require("__MiscLib__/assert_not_null")
--- @type Vector2D
local Vector2D = require("__MiscLib__/vector2d")

--- @class IndependentRepeatingEntity
--- @field preferredStepSize number
--- @field entityName string
--- @field nextPosition Vector2D
--- @field repeatingDirection defines.direction
--- @field additionalEntitySpec table additional specifications for the entity, such as entity direction/beacon's module etc.
local IndependentRepeatingEntity = {}
IndependentRepeatingEntity.__index = IndependentRepeatingEntity

--- @param o IndependentRepeatingEntity
--- @return IndependentRepeatingEntity
function IndependentRepeatingEntity:new(o)
    assertNotNull(o.entityName, o.nextPosition, o.preferredStepSize)
    o.repeatingDirection = o.repeatingDirection or defines.direction.east
    setmetatable(o, IndependentRepeatingEntity)
    return o
end

--- @param blueprintSection BlueprintSection
--- @return boolean true if we can still place next entity
function IndependentRepeatingEntity:placeNextEntity(blueprintSection)
    assertNotNull(self, blueprintSection)
    if not self.nextPosition then
        return
    end
    local newEntitySpec = {
        name = self.entity,
        position = self.nextPosition
    }
    if self.additionalEntitySpec then
        for k, v in pairs(self.additionalEntitySpec) do
            newEntitySpec[k] = v
        end
    end
    blueprintSection:add(newEntitySpec)
    local leftTop, rightBottom = blueprintSection:boundingBox()
    -- infer next position
    for tryStepSize = self.preferredStepSize, 1, -1 do
        local newNextPosition = Vector2D.fromDirection(self.repeatingDirection):scale(tryStepSize)
        if newNextPosition.x >= leftTop.x and newNextPosition.y >= leftTop.y and
                newNextPosition.x <= rightBottom.x and newNextPosition.y <= rightBottom.y then
            if not blueprintSection:positionIsOccupied(newNextPosition) then
                self.nextPosition = newNextPosition
                return true
            end
        end
    end
    self.nextPosition = nil
    return false
end
