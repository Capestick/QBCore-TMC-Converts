local TMC = exports.core:getCoreObject()

local currentNamespace = nil

local function copyMenuItems(data)
    local c = {}
    for i, v in ipairs(data) do
        c[i] = v
    end
    return c
end


local function sortData(data, skipfirst)
    local tempData = copyMenuItems(data)
    local header = tempData[1]
    if skipfirst then
        table.remove(tempData, 1)
    end
    table.sort(tempData, function(a, b)
        return (a.header or "") < (b.header or "")
    end)
    if skipfirst then
        table.insert(tempData, 1, header)
    end
    return tempData
end

local function clearCurrentMenu()
    if currentNamespace then
        TMC.Functions.CloseMenu(currentNamespace)
        currentNamespace = nil
    end
end


local function dispatchItem(item)
    if not item then
        return
    end
    if item.action ~= nil then
        item.action()
        return
    end
    local params = item.params
    if not params or not params.event then
        return
    end

    local ev = params.event
    local args = params.args

    if params.isServer then
        TriggerServerEvent(ev, args)
    elseif params.isCommand then
        ExecuteCommand(ev)
    elseif params.isQBCommand then
        ExecuteCommand(ev)
    elseif params.isAction and type(ev) == "function" then
        ev(args)
    elseif type(ev) == "string" then
        TriggerEvent(ev, args)
    end
end



local function buildElements(items, skipFirstSubtitle)
    local elements = {}
    local byName = {}
    local idx = 0

    for i, item in ipairs(items) do
        if item.hidden then
            goto continue
        end

        if item.isMenuHeader then
            if skipFirstSubtitle and i == 1 then
                goto continue
            end
            table.insert(elements, {
                type = "subtitle",
                label = item.header or "",
                size = 1.05,
            })
        else
            idx = idx + 1
            local name = string.format("qbmenu_%d", idx)
            byName[name] = item

            table.insert(elements, {
                type = "button",
                name = name,
                label = item.header or ("Option " .. tostring(i)),
                description = item.txt or "",
                disabled = item.disabled == true,
                icon = item.icon,
            })
        end

        ::continue::
    end

    return elements, byName
end

local function fireMenuClosed()
    TriggerEvent("qb-menu:client:menuClosed")
end




function openMenu(data, sort, skipFirst)
    if not data or not next(data) then
        return
    end

    local items = data
    if sort then
        items = sortData(data, skipFirst == true)
    end

    local title
    if items[1] and items[1].isMenuHeader and items[1].header then
        title = items[1].header
    end

    local elements, byName = buildElements(items, title ~= nil)
    if #elements == 0 then
        if not title then
            return
        end
        table.insert(elements, {
            type = "subtitle",
            label = "No menu entries",
            size = 0.9,
        })
    end

    clearCurrentMenu()
    Citizen.Wait(50)

    local ns = string.format("qb_menu_bridge_%s_%s", GetGameTimer(), math.random(10000, 99999))
    currentNamespace = ns

    TMC.Functions.OpenMenu({
        namespace = ns,
        title = title,
        searchable = false,
    }, elements, function(_, _)
        currentNamespace = nil
        fireMenuClosed()
    end, nil, function(change)
        if not change or not change.elementChanged then
            return
        end
        local item = byName[change.elementChanged]
        if not item or item.disabled or item.isMenuHeader then
            return
        end

        TMC.Functions.CloseMenu(ns)

        Citizen.SetTimeout(0, function()
            dispatchItem(item)
        end)
    end)
end

function closeMenu()
    clearCurrentMenu()
end

function showHeader(data)
    openMenu(data, false, false)
end

exports("openMenu", openMenu)
exports("closeMenu", closeMenu)
exports("showHeader", showHeader)

RegisterNetEvent("qb-menu:client:openMenu", function(data, sort, skipFirst)
    openMenu(data, sort, skipFirst)
end)

RegisterNetEvent("qb-menu:client:closeMenu", function()
    closeMenu()
end)
