local assertNotNull = require("__MiscLib__/assert_not_null")
--- @type Logger
local logging = require("__MiscLib__/logging")
--- @type ArrayList
local ArrayList = require("__MiscLib__/array_list")
--- @type Copier
local Copier = require("__MiscLib__/copy")
local deep_copy = Copier.deep_copy
--- @class BlueprintSection
--- @field entities Entity[]
--- @field inlets ConnectionPoint[]
--- @field outlets ConnectionPoint[]
--- @type BlueprintSection
local BlueprintSection = {}
BlueprintSection.__index = BlueprintSection


--- @return BlueprintSection
function BlueprintSection.new()
    --- @type BlueprintSection
    local o = { entities = ArrayList.new {}, inlets = ArrayList.new {}, outlets = ArrayList.new {} }
    setmetatable(o, BlueprintSection)
    return o
end

function BlueprintSection:copy(xoff, yoff)
    assert(self)
    xoff = xoff or 0
    yoff = yoff or 0
    --- @param old Entity
    local function shift_func(old)
        local new = deep_copy(old)
        new.position.x = new.position.x + xoff
        new.position.y = new.position.y + yoff
        return new
    end
    local new_section = BlueprintSection.new()
    new_section.entities = ArrayList.new(self.entities):map(shift_func)
    new_section.inlets = ArrayList.new(self.inlets):map(shift_func)
    new_section.outlets = ArrayList.new(self.outlets):map(shift_func)
    return new_section
end

--- @param entity Entity
function BlueprintSection:add(entity)
    assertNotNull(self, entity)
    entity.entity_number = #self.entities + 1
    self.entities[entity.entity_number] = entity
end

--- @param section BlueprintSection
function BlueprintSection:addSection(section)
    assertNotNull(self, section)

    for _, entity in ipairs(section.entities) do
        self:add(deep_copy(entity))
    end
    for _, inlet in ipairs(section.inlets) do
        self.inlets:add(deep_copy(inlet))
    end
    for _, outlet in ipairs(section.outlets) do
        self.inlets:add(deep_copy(outlet))
    end
end

--- concatenate with another section, assuming that self's outlets and other's inlets are connected.
--- If no offsets are provided, default to concatenate other to right side.
--- @param other BlueprintSection
--- @param xoff number optional, x-offset of the other section, default to width of self
--- @return BlueprintSection new self
function BlueprintSection:concat(other, xoff)
    assertNotNull(self, other)
    xoff = xoff or self:width()

    self.outlets = {}
    for _, entity in ipairs(other.entities) do
        local new_entity = deep_copy(entity)
        new_entity.position.x = new_entity.position.x + xoff
        self:add(new_entity)
    end

    local outlet_increase = other:width()
    for _, outlet in ipairs(self.outlets) do
        outlet.position.x = outlet.position.x + outlet_increase
    end

    return self
end

function BlueprintSection:width()
    local min, max
    for _, entity in ipairs(self.entities) do
        local test_min = entity.position.x + game.entity_prototypes[entity.name].selection_box.left_top.x
        if not min or test_min < min then
            min = test_min
        end
        local test_max = entity.position.x + game.entity_prototypes[entity.name].selection_box.right_bottom.x
        if not max or test_max > max then
            max = test_max
        end
    end
    local width = math.floor((max or 0) - (min or 0) + 0.5)
    return width
end

function BlueprintSection:height()
    local min, max
    for _, entity in ipairs(self.entities) do
        local test_min = entity.position.y + game.entity_prototypes[entity.name].selection_box.left_top.y
        if not min or test_min < min then
            min = test_min
        end
        local test_max = entity.position.y + game.entity_prototypes[entity.name].selection_box.right_bottom.y
        if not max or test_max > max then
            max = test_max
        end
    end
    local height = math.floor((max or 0) - (min or 0) + 0.5)
    return height
end

function BlueprintSection:shift(x_off, y_off)
    for _, entity in ipairs(self.entities) do
        entity.position.x = entity.position.x + x_off
        entity.position.y = entity.position.y + y_off
    end
    for _, inlet in ipairs(self.inlets) do
        inlet.position.x = inlet.position.x + x_off
        inlet.position.y = inlet.position.y + y_off
    end
    for _, outlet in ipairs(self.outlets) do
        outlet.position.x = outlet.position.x + x_off
        outlet.position.y = outlet.position.y + y_off
    end
end

--- clear overlapped units, last-in entity get saved
function BlueprintSection:clear_overlap()
    local position_dict = {}
    for _, entity in ipairs(self.entities) do
        local pos = tostring(entity.position[1] or entity.position.x) .. "," .. tostring(entity.position[2] or entity.position.y)
        position_dict[pos] = entity
    end
    self.entities = {}
    for _, entity in pairs(position_dict) do
        self:add(entity)
    end
end

--- @param n_times number
--- @return BlueprintSection
function BlueprintSection:repeat_self(n_times)
    assertNotNull(self, n_times)

    local unit = self:copy()
    local unit_width = unit:width()
    logging.log(serpent.line(unit.entities, { maxlevel = 4 }))

    for i = 1, n_times - 1, 1 do
        self:concat(unit, unit_width * i, 0)
    end
    return self
end

-- rotate clockwise 90*n degrees
function BlueprintSection:rotate(n)
    local rotate_matrices = { [0] = function(x, y)
        return { x = x, y = y }
    end, [1] = function(x, y)
        return { x = y, y = -x }
    end, [2] = function(x, y)
        return { x = -x, y = -y }
    end, [3] = function(x, y)
        return { x = -y, y = x }
    end }

    n = -n % 4
    local rotate_func = rotate_matrices[n]
    for _, entity in ipairs(self.entities) do
        local prototype = game.entity_prototypes[entity.name]
        -- entity with even number of width/height will have a small centering offset
        local x_offset = (math.ceil(prototype.selection_box.right_bottom.x - prototype.selection_box.left_top.x + 1) % 2) / 2
        local y_offset = (math.ceil(prototype.selection_box.right_bottom.y - prototype.selection_box.left_top.y + 1) % 2) / 2
        if entity.name == "stone-furnace" then
            logging.log("before position: " .. serpent.line(entity.position))
        end
        entity.position = rotate_func(entity.position.x - x_offset, entity.position.y - y_offset)
        if entity.name == "stone-furnace" then
            logging.log("after position: " .. serpent.line(entity.position))
        end
        entity.direction = ((entity.direction or 0) - 2 * n) % 8
    end
end

return BlueprintSection