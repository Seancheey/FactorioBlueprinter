--- @class OutputSpec one blueprint output specification
--- @field crafting_speed number speed
--- @field unit number crafting speed unit multiplier, with item/s as 1
--- @field ingredient string recipe name of specification

--- @class GuiRootChildrenNames
--- @type GuiRootChildrenNames
local GuiRootChildrenNames = {}

GuiRootChildrenNames.main_function_frame = "bp-outputs-frame"
GuiRootChildrenNames.inputs_select_frame = "bp-inputs-frame"
GuiRootChildrenNames.main_button = "bp-main-button"

return GuiRootChildrenNames