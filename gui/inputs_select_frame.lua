--- @type BlueprintGraph
local BlueprintGraph = require("blueprint_gen.blueprint_graph")
local assertNotNull = require("__MiscLib__/assert_not_null")
--- @type GuiLib
local GuiLib = require("__MiscLib__/guilib")
local gui_root = GuiLib.gui_root
--- @type GuiRootChildrenNames
local GuiRootNames = require("gui.root_names")

--- @param gui_parent LuaGuiElement
local function create_input_buttons(player_index, gui_parent, blueprint_graph)
    local function recreate_input_buttons()
        -- clear frame's all child element buttons
        for _, child in ipairs(gui_parent.children) do
            GuiLib.removeGuiElement(child)
        end
        create_input_buttons(player_index, gui_parent, blueprint_graph)
    end
    for ingredient_name, _ in pairs(blueprint_graph.inputs) do
        GuiLib.addGuiElementWithHandler(gui_parent,
                {
                    type = "sprite-button",
                    name = "left_button_" .. ingredient_name,
                    sprite = "utility/left_arrow",
                    tooltip = "use it's ingredient instead"
                },
                {
                    [defines.events.on_gui_click] = function()
                        BlueprintGraph.use_ingredients_as_input(blueprint_graph, ingredient_name)
                        recreate_input_buttons()
                    end
                }
        )
        gui_parent.add { type = "sprite", name = "sprite_" .. ingredient_name, sprite = sprite_of(ingredient_name) }
        GuiLib.addGuiElementWithHandler(gui_parent,
                { type = "sprite-button",
                  name = "right_button_" .. ingredient_name,
                  sprite = "utility/right_arrow",
                  tooltip = "use it's targets instead"
                }, {
                    [defines.events.on_gui_click] = function()
                        BlueprintGraph.use_products_as_input(blueprint_graph, ingredient_name)
                        recreate_input_buttons()
                    end
                }
        )
    end
end

function create_inputs_select_frame(player_index, output_specs)
    assertNotNull(player_index, output_specs)
    local blueprint_graph = BlueprintGraph.new(player_index)
    blueprint_graph:generate_graph_by_outputs(output_specs)
    local frame = gui_root(player_index).add { name = GuiRootNames.inputs_select_frame, type = "frame", caption = "Input Source Select", direction = "vertical" }
    local hori_flow = frame.add { type = "table", name = "hori_flow", column_count = 2 }
    local input_select_frame = hori_flow.add { type = "frame", name = "input_select_frame", caption = "Input Items Select" }
    local inputs_flow = input_select_frame.add { type = "flow", name = "inputs_flow", direction = "vertical" }
    local inputs_table = inputs_flow.add { type = "table", name = "inputs_table", column_count = 3 }
    create_input_buttons(player_index, inputs_table, blueprint_graph)
    inputs_flow.style.vertically_stretchable = true
    local outputs_frame = hori_flow.add { type = "frame", name = "outputs_frame", caption = "Final Products" }
    local outputs_view_flow = outputs_frame.add { type = "flow", name = "outputs_view_flow", direction = "vertical", caption = "target outputs" }
    for output_name, _ in pairs(blueprint_graph.outputs) do
        outputs_view_flow.add { type = "sprite", sprite = sprite_of(output_name) }
    end
    outputs_view_flow.style.vertically_stretchable = true
    GuiLib.addGuiElementWithHandler(frame, { type = "button", name = "confirm_button", caption = "confirm" },
            {
                [defines.events.on_gui_click] = function(e)
                    -- TODO generate a real blueprint
                    game.players[e.player_index].print("This function is currently not yet completed, it's under active development.")
                end
            })
end

