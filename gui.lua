main_button = "bp-main-button"
main_frame = "bp-outputs-frame"
output_units = {"item/s", "item/min"}

function register_gui_event_handler(elem_name, event, handler)
    if not global.handles then global.handlers = {} end
    if not global.handlers[event] then
        global.handlers[event] = {}
        script.on_event(event,
            function(e)
                for name, handle in pairs(global.handlers[event]) do
                    if e.element and e.element.name == name then
                        handle(e)
                    end
                end
            end
        )
    end
    global.handlers[event][elem_name] = handler
end

function clear_mod_gui(player)
    for i, to_remove in ipairs{main_button,main_frame} do
        if player.gui.left[to_remove] then
            player.gui.left[to_remove].destroy()
        end
        if player.gui.left[to_remove] then
            player.gui.left[to_remove].destroy()
        end
    end
end

function create_blueprinter_button(parent)
    local button = parent.add{
        type = "button",
        tooltip = "Click to open Blueprinter.",
        caption = "Blueprinter",
        name = main_button
    }
    register_gui_event_handler(main_button, defines.events.on_gui_click,
        function(e)
            local player = game.players[e.player_index]
            player.gui.left[main_frame].visible = not player.gui.left[main_frame].visible
        end
    )
end

function create_new_output_item_choice(parent)
    parent.add{type = "choose-elem-button", elem_type = "recipe"}
    parent.add{type = "textfield", text = "1", numeric = true, allow_negative = false}
    parent.add{type = "drop-down", items = output_units, selected_index = 1}
end

function create_outputs_frame(parent)
    local frame = parent.add{type = "frame",name = main_frame,caption = "Blueprinter"}
        local tab_pane = frame.add{type = "tabbed-pane",name = outputs_tab_pane,caption = "outputs",direction = "vertical"}
            local output_tab = tab_pane.add{type = "tab",name = "outputs_tab",caption = "outputs"}
            local output_flow = tab_pane.add{type = "flow", direction = "vertical"}
                local output_table = output_flow.add{type = "table", name = "output_table", caption = "select output items",column_count = 3}
                    create_new_output_item_choice(output_table)
                local confirm_button = output_flow.add{type = "button", caption = "confirm"}
            local setting_tab = tab_pane.add{type = "tab",name = "setting_tab",caption = "settings"}
                local test = tab_pane.add{type = "label",name = "test",caption = "test setting"}
            tab_pane.add_tab(output_tab, output_flow)
            tab_pane.add_tab(setting_tab, test)
            tab_pane.selected_tab_index = 1
    return frame
end
