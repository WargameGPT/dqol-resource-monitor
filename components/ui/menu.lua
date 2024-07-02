local UiMenu = {
    ROOT_FRAME = Ui.ROOT_FRAME .. '-menu',
    BUTTON_NAME = Ui.ROOT_FRAME .. '-menu-show',
    WINDOW_ID = 'menu',
    tabs = {},
    filters = {},
    surfaces = {},
    dashboard = {},
}

---@param LuaPlayer
function UiMenu.bootPlayer(player)
    UiMenu.createButton(player)
end

---@param player LuaPlayer
function UiMenu.createButton(player)
    local flow = Ui.mod_gui.get_button_flow(player)
    if flow[UiMenu.BUTTON_NAME] ~= nil then
        flow[UiMenu.BUTTON_NAME].destroy()
    end

    flow.add {
        type = 'sprite-button',
        name = UiMenu.BUTTON_NAME,
        tooltip = { 'dqol-resource-monitor.ui-menu-button-tooltip' },
        sprite = 'item/rocket-control-unit',
        style = Ui.mod_gui.button_style,
        tags = {
            _module = 'menu',
            _action = 'show',
        }
    }
end

---Display the main window
---@param player LuaPlayer
---@param window LuaGuiElement?
function UiMenu.show(player, window)
    if window == nil then
        window = Ui.Window.create(player, UiMenu.WINDOW_ID, { 'dqol-resource-monitor.ui-menu-title' })
    end

    if window.titlebar ~= nil and window.titlebar.reload == nil then
        -- create the reload button
        window.titlebar.add {
            name = 'reload',
            index = #(window.titlebar.children),
            type = 'sprite-button',
            style = 'frame_action_button',
            sprite = 'utility/reset_white',
            tooltip = {'dqol-resource-monitor.ui-menu-reload-tooltip'},
            tags = {
                _module = 'menu',
                _action = 'show',
            },
        }
    end

    if window.inner ~= nil then window.inner.destroy() end
    local inner = window.add { name = 'inner', type = 'frame', style = 'inside_deep_frame' }
    local tabs = inner.add {
        name = 'tabbed',
        type = 'tabbed-pane',
        tags = {
            _module = 'menu',
            _action = 'tab_select',
            _only = defines.events.on_gui_selected_tab_changed,
        },
    }
    
    -- add all tabs here
    for name, func in pairs(UiMenu.tabs) do
        local caption = tabs.add { type = 'tab', caption = { 'dqol-resource-monitor.ui-menu-tab-' .. name } }
        local tab = tabs.add { name = name, type = 'flow', direction = 'vertical' }
        func(tab)
        tabs.add_tab(caption, tab)
    end

    tabs.selected_tab_index = Ui.State.get(player.index).menu.tab or 1
end

function UiMenu.tabs.sites(tab)
    -- add filter with state
    local state = Ui.State.get(tab.player_index).menu.sites_filters
    UiMenu.filters.add(tab, state, 'sites_filters')

    local main = tab.add { name = 'main', type = 'flow', direction = 'horizontal' }
    main.style.horizontally_stretchable = 'stretch_and_expand'
    main.style.vertically_stretchable = 'stretch_and_expand'
    
    -- left side
    local sites_frame = main.add { name = 'sites', type = 'frame', style = 'deep_frame_in_shallow_frame' }
    sites_frame.style.width = 450
    sites_frame.style.natural_height = 600
    sites_frame.style.margin = 8
    sites_frame.style.horizontally_stretchable = 'stretch_and_expand'
    sites_frame.style.vertically_stretchable = 'stretch_and_expand'
    local sites_scroll = sites_frame.add { type = 'scroll-pane' }
    sites_scroll.vertical_scroll_policy = 'always'
    sites_scroll.style.horizontally_stretchable = "stretch_and_expand"
    sites_scroll.style.vertically_stretchable = "stretch_and_expand"
    local sites = sites_scroll.add { name = 'sites', type = 'flow', direction = 'vertical' }

    -- right side
    local preview = main.add { name = 'preview', type = 'frame', style = 'deep_frame_in_shallow_frame', direction = 'vertical' }
    preview.style.natural_width = 400
    preview.style.natural_height = 600
    preview.style.margin = 8
    preview.style.left_margin = 0
    preview.style.padding = 4
    preview.style.vertically_stretchable = 'stretch_and_expand'

    -- fill sites
    local filteredSites = UiMenu.filters.getSites(state)
    local lastSurface = 0

    local showSurfaceSubheading = state.orderBy == nil and state.surface == nil
    local appendSurfaceName = state.orderBy ~= nil and state.surface == nil and #game.surfaces > 1
    for key, site in pairs(filteredSites) do
        -- check if we should print the surface name
        if showSurfaceSubheading and lastSurface ~= site.surface then
            -- surface label row
            local row = sites.add { type = 'flow', style = 'dqol_resource_monitor_table_row_subheading' }

            lastSurface = site.surface
            row.add {
                type = 'label',
                style = 'caption_label',
                caption = game.surfaces[site.surface].name
            }
        end

        -- site row
        local row_button = sites.add {
            type = 'button',
            style = 'dqol_resource_monitor_table_row_button',
            tags = {
                _module = 'menu_site',
                _action = 'show',
                site_id = site.id,
            },
        }
        
        local row = row_button.add{ type = 'flow', style = 'dqol_resource_monitor_table_row_flow', ignored_by_interaction = true }
        local type = Resources.types[site.type]
        local name = site.name
        if appendSurfaceName then
            name = game.surfaces[site.surface].name .. ' ' .. name
        end
        row.add { type = 'label', caption = '[' .. type.type .. '=' .. type.name .. ']', style = 'dqol_resource_monitor_table_cell_resource' }
        row.add { type = 'label', caption = name, style = 'dqol_resource_monitor_table_cell_name' }
        row.add { type = 'label', style = 'dqol_resource_monitor_table_cell_padding' }
        row.add { type = 'label', caption = Util.Integer.toExponentString(site.amount), style = 'dqol_resource_monitor_table_cell_number' }
        row.add { type = 'label', style = 'dqol_resource_monitor_table_cell_padding' }
        local percentLabel = row.add { type = 'label', caption = Util.Integer.toPercent(site.amount / site.initial_amount) }
        percentLabel.style.font_color = Util.Integer.toColor(site.amount / site.initial_amount)
    end
    
    if #filteredSites == 0 then
        sites_scroll.add {
            type = 'label',
            caption = {'dqol-resource-monitor.ui-menu-sites-empty'}
        }
    end
end

function UiMenu.tabs.surfaces(tab)
    local main = tab.add { name = 'main', type = 'flow', direction = 'horizontal' }
    main.style.horizontally_stretchable = 'stretch_and_expand'
    main.style.vertically_stretchable = 'stretch_and_expand'

    -- left side
    local surfaces_frame = main.add { name = 'sites', type = 'frame', style = 'deep_frame_in_shallow_frame' }
    surfaces_frame.style.width = 500
    surfaces_frame.style.natural_height = 600
    surfaces_frame.style.margin = 8
    local surfaces_scroll = surfaces_frame.add { type = 'scroll-pane' }
    surfaces_scroll.vertical_scroll_policy = 'always'
    surfaces_scroll.style.horizontally_stretchable = 'stretch_and_expand'
    surfaces_scroll.style.vertically_stretchable = 'stretch_and_expand'
    local surfaces = surfaces_scroll.add { name = 'surfaces', type = 'flow', direction = 'vertical' }

    -- right side
    local preview = main.add { name = 'preview', type = 'frame', style = 'deep_frame_in_shallow_frame', direction = 'vertical' }
    preview.style.minimal_width = 400
    preview.style.natural_height = 600
    preview.style.margin = 8
    preview.style.left_margin = 0
    preview.style.padding = 4
    preview.style.vertically_stretchable = 'stretch_and_expand'

    for index, surface in pairs(Surfaces.getVisibleSurfaces()) do
        local row_button = surfaces.add {
            type = 'button',
            style = 'dqol_resource_monitor_table_row_button',
            tags = {
                _module = 'surface',
                _action = 'show',
                surface_id = surface.id,
            },
        }
        
        local row = row_button.add{ type = 'flow', style = 'dqol_resource_monitor_table_row_flow', ignored_by_interaction = true }
        
        -- add resources
        local resources_string = ''
        for _, resource in pairs(surface.resources) do
            local type = Resources.types[resource]
            resources_string = resources_string .. '[' .. type.type .. '=' .. type.name .. ']'
        end

        row.add { type = 'label', caption = Surfaces.surface.getName(surface), style = 'dqol_resource_monitor_table_cell_name' }
        row.add { type = 'label', style = 'dqol_resource_monitor_table_cell_padding' }
        local resources_label = row.add { type = 'label', caption = resources_string, style = 'dqol_resource_monitor_table_cell' }
        resources_label.style.width = 200
    end
end

function UiMenu.tabs.dashboard(tab)
    local note = tab.add { type = 'label', caption = { 'dqol-resource-monitor.ui-menu-dashboard-note' } }
    note.style.margin = 8

    -- add filter with state
    local state = Ui.State.get(tab.player_index)
    UiMenu.filters.add(tab, state.menu.dashboard_filters, 'dashboard_filters')

    tab.add { type = 'line', style = 'inside_shallow_frame_with_padding_line' }
    local settings = tab.add { type = 'flow', direction = 'vertical' }
    settings.style.margin = 8

    settings.add {
        type = 'checkbox',
        state = state.dashboard.show_headers or false,
        caption = {'dqol-resource-monitor.ui-menu-dashboard-show-headers'},
        tooltip = {'dqol-resource-monitor.ui-menu-dashboard-show-headers-tooltip'},
        tags = {
            _module = 'menu_dashbaord',
            _action = 'toggle_value',
            _only = defines.events.on_gui_checked_state_changed,
            state_key = 'show_headers',
        }
    }
    settings.add {
        type = 'checkbox',
        state = state.dashboard.prepend_surface_name or false,
        caption = {'dqol-resource-monitor.ui-menu-dashboard-prepend-surface-name'},
        tooltip = {'dqol-resource-monitor.ui-menu-dashboard-prepend-surface-name-tooltip'},
        tags = {
            _module = 'menu_dashbaord',
            _action = 'toggle_value',
            _only = defines.events.on_gui_checked_state_changed,
            state_key = 'prepend_surface_name',
        }
    }
end

function UiMenu.tabs.other(tab)
    local info = tab.add { type = 'table', column_count = 2 }
    info.add { type = 'label', caption = {'dqol-resource-monitor.ui-menu-other-info-headline'}, style = 'caption_label' }
    info.add { type = 'label', caption = '' }
    
    if global.sites and global.sites.updater then
        local queueLength = #global.sites.updater.queue 
        local chunksPerUpdate = settings.global['dqol-resource-monitor-site-chunks-per-update'].value
        local ticksBetweenUpdates = settings.global['dqol-resource-monitor-site-ticks-between-updates'].value
        local ticksToFinishQueue = ticksBetweenUpdates * (queueLength + 1)
        info.add { type = 'label', caption = { 'dqol-resource-monitor.ui-menu-other-updater-queue-length' } }
        info.add { type = 'label', caption = queueLength}
        info.add { type = 'label', caption = { 'dqol-resource-monitor.ui-menu-other-updater-queue-position' } }
        info.add { type = 'label', caption = global.sites.updater.pointer }
        info.add { type = 'label', caption = {'dqol-resource-monitor.ui-menu-other-updater-queue-total-chunks'}}
        info.add { type = 'label', caption = ((queueLength - 1) * chunksPerUpdate) + (#(global.sites.updater.queue[#global.sites.updater.queue] or {})) }
        info.add { type = 'label', caption = {'dqol-resource-monitor.ui-menu-other-updater-chunks-per-update'}}
        info.add { type = 'label', caption = chunksPerUpdate }
        info.add { type = 'label', caption = {'dqol-resource-monitor.ui-menu-other-updater-ticks-between-updates'}}
        info.add { type = 'label', caption = ticksBetweenUpdates }
        info.add { type = 'label', caption = {'dqol-resource-monitor.ui-menu-other-updater-queue-duration'}}
        info.add { type = 'label', caption = Util.Integer.toTimeString(ticksToFinishQueue) .. ' (' .. ticksToFinishQueue .. ')' }
    else
        info.add { type = 'label', caption = 'Updater is not initialized yet. If the mod was just loaded, you may need to wait a little. Otherwise, check that there are sites with tracking enabled.' }
        info.add { type = 'label', caption = '' }
    end

    if _DEBUG then
        local table = tab.add { type = 'table', column_count = 3 }
        for _, type in pairs(Resources.types) do
            table.add { type = 'label', caption = type.name }
            table.add { type = 'label', caption = type.type }
            table.add { type = 'label', caption = type.resource_name }
        end
    end
end

---@param player LuaPlayer
---@return LuaGuiElement?
function UiMenu.getSitePreview(player)
    local window = Ui.Window.get(player, UiMenu.WINDOW_ID)
    if window == nil then
        UiMenu.show(player)
        window = Ui.Window.get(player, UiMenu.WINDOW_ID)
    end

    if window == nil then return nil end
    if window['inner'] == nil or window['inner']['tabbed'] == nil then return nil end -- todo change this
    return window['inner']['tabbed']['sites']['main']['preview'] or nil
end

---@param player LuaPlayer
---@return LuaGuiElement?
function UiMenu.getSurfacePreview(player)
    local window = Ui.Window.get(player, UiMenu.WINDOW_ID)
    if window == nil then
        UiMenu.show(player)
        window = Ui.Window.get(player, UiMenu.WINDOW_ID)
    end

    if window == nil then return nil end
    if window['inner'] == nil or window['inner']['tabbed'] == nil then return nil end -- todo change this
    return window['inner']['tabbed']['surfaces']['main']['preview'] or nil
end

---@param tab LuaGuiElement
---@param state UiStateMenuFilter
---@param filter_group 'sites_filters'|'dashboard_filters'
function UiMenu.filters.add(tab, state, filter_group)
    local filterGroup = tab.add { type = 'flow', direction = 'vertical', }
    filterGroup.style.margin = 8

    local showResourceFilterReset = table_size(state.resources) > 0
    local resources = Resources.clean()
    local resourceFilter = filterGroup.add {
        name = 'filters',
        type = 'table',
        style = 'compact_slot_table',
        column_count = table_size(resources) + ((showResourceFilterReset and 1) or 0),
    }

    for key, resource in pairs(resources) do
        resourceFilter.add {
            type = 'sprite-button',
            style = 'compact_slot_sized_button',
            toggled = state.resources[resource.resource_name] ~= nil,
            sprite = resource.type .. '/' .. resource.name,
            tooltip = { 'dqol-resource-monitor.ui-menu-filter-resource-tooltip', { resource.type .. '-name.' .. resource.name }},
            tags = {
                _module = 'menu_filters',
                _action = 'toggle_resource',
                filter_group = filter_group,
                resource_name = resource.resource_name,
            }
        }
    end
    -- add reset button if needed
    if showResourceFilterReset then
        local reset = resourceFilter.add {
            type = 'sprite-button',
            style = 'red_button',
            sprite = 'utility/reset',
            tooltip = { 'dqol-resource-monitor.ui-menu-filter-resource-reset-tooltip' },
            tags = {
                _module = 'menu_filters',
                _action = 'toggle_resource',
                filter_group = filter_group,
                reset = true,
            },
        }
        reset.style.size = 36
    end

    -- generate surfaces
    local surfaces = {}
    local surfaceIndex = nil
    local selectToSurfaceId = {}
    for index, surface in pairs(Surfaces.getVisibleSurfaces()) do
        table.insert(surfaces, Surfaces.surface.getName(surface))
        table.insert(selectToSurfaceId, index, surface.id)
        if surface.id == state.surface then surfaceIndex = index end
    end
    
    -- select default surface if there is only one
    if #surfaces == 1 then
        surfaceIndex = 1
    end
    
    local surfaceFilter = filterGroup.add { type = 'flow', direction = 'horizontal' }
    local surfaceSelect = surfaceFilter.add {
        name = 'surface',
        type = 'drop-down',
        items = surfaces,
        selected_index = surfaceIndex,
        tooltip = {'dqol-resource-monitor.ui-menu-filter-surface-tooltip'},
        tags = {
            _module = 'menu_filters',
            _action = 'select_surface',
            _only = defines.events.on_gui_selection_state_changed,
            filter_group = filter_group,
            selectToSurfaceId = selectToSurfaceId,
        },
    }
    -- show reset button if needed
    if state.surface ~= nil then
        surfaceFilter.add {
            type = 'sprite-button',
            style = 'tool_button_red',
            sprite = 'utility/reset',
            tooltip = {'dqol-resource-monitor.ui-menu-filter-surface-reset-tooltip'},
            tags = {
                _module = 'menu_filters',
                _action = 'select_surface',
                filter_group = filter_group,
                reset = true,
            },
        }
    end

    local percentFilter = filterGroup.add { type = 'flow', direction = 'horizontal' }
    percentFilter.add { type = 'label', caption = {'dqol-resource-monitor.ui-menu-filter-max-percent'}}
    percentFilter.add {
        type = 'textfield',
        text = state.maxPercent or 100,
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        lose_focus_on_confirm = true,
        style = 'very_short_number_textfield',
        tags = {
            _module = 'menu_filters',
            _action = 'set_max_percent',
            _only = defines.events.on_gui_confirmed,
            filter_group = filter_group,
        },
    }
    percentFilter.add { type = 'label', caption = '%' }
    
    local searchFilter = filterGroup.add { type = 'flow', direction = 'horizontal' }
    searchFilter.add { type = 'label', caption = { 'dqol-resource-monitor.ui-menu-filter-search' } }
    searchFilter.add {
        type = 'textfield',
        text = state.search or '',
        lose_focus_on_confirm = true,
        tags = {
            _module = 'menu_filters',
            _action = 'set_search',
            _only = defines.events.on_gui_confirmed,
            filter_group = filter_group,
        },
    }

    local stateFilter = filterGroup.add { type = 'flow', direction = 'horizontal' }
    stateFilter.add {
        type = 'checkbox',
        state = state.onlyTracked or false,
        caption = {'dqol-resource-monitor.ui-menu-filter-only-tracked'},
        tooltip = {'dqol-resource-monitor.ui-menu-filter-only-tracked-tooltip'},
        tags = {
            _module = 'menu_filters',
            _action = 'toggle_only_tracked',
            _only = defines.events.on_gui_checked_state_changed,
            filter_group = filter_group,
        },
    }
    stateFilter.add {
        type = 'checkbox',
        state = state.onlyEmpty or false,
        caption = {'dqol-resource-monitor.ui-menu-filter-only-empty'},
        tooltip = {'dqol-resource-monitor.ui-menu-filter-only-empty-tooltip'},
        tags = {
            _module = 'menu_filters',
            _action = 'toggle_only_empty',
            _only = defines.events.on_gui_checked_state_changed,
            filter_group = filter_group,
        }
    }
    
    -- nil|'resource'|'name'|'amount'|'percent'|'rate'
    local orderBy = {
        { value = nil },
        { value = 'resource' },
        { value = 'name' },
        { value = 'amount' },
        { value = 'percent' },
        { value = 'rate' },
    }
    local orderByFilter = filterGroup.add {
        type = 'table',
        style = 'compact_slot_table',
        column_count = #orderBy,
    }

    for _, item in pairs(orderBy) do
        local toggled = state.orderBy == item.value
        local direction = 'asc'
        if toggled then
            -- check for the state to find direction
            if state.orderByDesc ~= true then
                direction = 'desc'    
            end
        end

        orderByFilter.add {
            type = 'sprite-button',
            style = 'compact_slot_sized_button',
            toggled = toggled,
            -- sprite = 'entity/copper',
            tooltip = { 'dqol-resource-monitor.ui-menu-filter-order-' .. (item.value or 'default') .. '-' .. direction },
            tags = {
                _module = 'menu_filters',
                _action = 'set_order_by',
                filter_group = filter_group,
                order_by = item.value,
                order_by_direction = direction,
            }
        }
    end

end

---@param state UiStateMenuFilter
---@return Site[]
function UiMenu.filters.getSites(state)
    local filterSurface = state.surface ~= nil
    local filterResources = table_size(state.resources) > 0

    ---@type Site[]
    local sites = {}

    for surfaceId, types in pairs(Sites.storage.getSurfaceList()) do
        -- filter for surface type
        if filterSurface == false or state.surface == surfaceId then
            for type, typeSites in pairs(types) do
                -- filter for resource type
                if filterResources == false or state.resources[type] ~= nil then
                    for key, site in pairs(typeSites) do
                        -- filter for only tracking
                        local insert = true
                        if state.onlyTracked == true and site.tracking == false then
                            insert = false
                        elseif state.onlyEmpty == true and site.amount > 0 then
                            insert = false
                        elseif (site.amount / site.initial_amount) * 100 > (state.maxPercent or 100) then
                            insert = false
                        elseif state.search ~= nil and string.find(string.lower(site.name), string.lower(state.search)) == nil then
                            insert = false
                        end

                        if insert then
                            table.insert(sites, site)
                        end
                    end
                end
            end
        end
    end

    -- deal with ordering
    if state.orderBy == 'resource' then
        local function compare(siteA, siteB)
            return siteA.type < siteB.type
        end
        table.sort(sites, compare)
    elseif state.orderBy == 'name' then
        local function compare(siteA, siteB)
            return siteA.name < siteB.name
        end
        table.sort(sites, compare)
    elseif state.orderBy == 'amount' then
        local function compare(siteA, siteB)
            return siteA.amount < siteB.amount
        end
        table.sort(sites, compare)
    elseif state.orderBy == 'percent' then
    elseif state.orderBy == 'rate' then
    end

    if state.orderByDesc then
        -- quick reverse
        for i = 1, math.floor(#sites/2), 1 do
            sites[i], sites[#sites-i+1] = sites[#sites-i+1], sites[i]
        end
    end

    return sites
end

function UiMenu.onShow(event)
    UiMenu.show(game.players[event.player_index])
end

function UiMenu.onSelectedTabChanged(event)
    local state = Ui.State.get(event.player_index)
    state.menu.tab = event.element.selected_tab_index or nil
end

function UiMenu.onSiteShow(site, player)
    local preview = UiMenu.getSitePreview(player)
    if preview ~= nil then
        preview.clear()
        Ui.Window.createInner(preview, 'previewsite' .. site.id, site.name)
    end
    Ui.Site.show(site, player, preview[Ui.Window.ROOT_FRAME .. 'previewsite' .. site.id])
end


---@param surface Surface
---@param player LuaPlayer
function UiMenu.onSurfaceShow(surface, player)
    local window = Ui.Menu.getSurfacePreview(player)
    if window then
        window.clear()
        Ui.Window.createInner(window, 'previewsurface' .. surface.id, Surfaces.surface.getName(surface))
        Ui.Surface.show(surface, window)
    end    
end

---@param player LuaPlayer
---@param state UiStateMenuFilter
function UiMenu.filters.onToggleResource(event, player, state)
    if event.element.tags.reset == true then
        state.resources = {}
    else
        local resource = event.element.tags.resource_name
        if state.resources[resource] == nil then
            state.resources[resource] = true
        else
            state.resources[resource] = nil
        end
    end

    UiMenu.show(player)
end

---@param player LuaPlayer
---@param state UiStateMenuFilter
function UiMenu.filters.onSelectSurface(event, player, state)
    if event.element.tags.reset == nil then
        state.surface = (event.element.tags.selectToSurfaceId and event.element.tags.selectToSurfaceId[event.element.selected_index]) or nil
    else
        state.surface = nil
    end

    UiMenu.show(player)
end

---@param player LuaPlayer
---@param state UiStateMenuFilter
function UiMenu.filters.onToggleOnlyTracked(event, player, state)
    state.onlyTracked = event.element.state or false
    UiMenu.show(player)
end

---@param player LuaPlayer
---@param state UiStateMenuFilter
function UiMenu.filters.onToggleOnlyEmpty(event, player, state)
    state.onlyEmpty = event.element.state or false
    UiMenu.show(player)
end

---@param player LuaPlayer
---@param state UiStateMenuFilter
function UiMenu.filters.onSetMaxPercent(event, player, state)
    state.maxPercent = tonumber(event.element.text)
    if state.maxPercent > 100 then state.maxPercent = 100 end
    UiMenu.show(player)
end

---@param player LuaPlayer
---@param state UiStateMenuFilter
function UiMenu.filters.onSetSearch(event, player, state)
    state.search = event.element.text
    if state.search == '' then state.search = nil end
    UiMenu.show(player)
end

---@param player LuaPlayer
---@param state UiStateMenuFilter
function UiMenu.filters.onSetOrderBy(event, player, state)
    state.orderBy = event.element.tags.order_by
    state.orderByDesc = event.element.tags.order_by_direction == 'desc'
    UiMenu.show(player)
end

---@param state UiStateDashboard
function UiMenu.dashboard.onToggleValue(event, state)
    state[event.element.tags.state_key] = event.element.state
    UiMenu.show(game.players[event.player_index])
end

return UiMenu
