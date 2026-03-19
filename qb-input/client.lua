local TMC = exports.core:getCoreObject()

local function mapSelectOptions(opts)
    local out = {}
    for _, o in ipairs(opts or {}) do
        table.insert(out, {
            value = o.value,
            label = o.text or o.label or tostring(o.value),
        })
    end
    return out
end

local function safeInternalSuffix(v)
    return tostring(v):gsub("[^%w_]", "_")
end

---@param inputs table|nil qb-input style input list
---@return table elements, table meta (checkbox internal field tracking)
local function buildFormElements(inputs)
    local elements = {}
    local meta = { checkboxInternals = {} }

    for _, inp in ipairs(inputs or {}) do
        local t = inp.type or "text"
        local name = inp.name
        if not name then
            goto continue
        end

        if t == "text" then
            table.insert(elements, {
                type = "text",
                name = name,
                label = inp.text or name,
                placeholder = inp.text,
                required = inp.isRequired == true,
                default = inp.default,
            })
        elseif t == "password" then
            table.insert(elements, {
                type = "text",
                name = name,
                label = inp.text or name,
                placeholder = inp.text,
                required = inp.isRequired == true,
                default = inp.default,
            })
        elseif t == "number" then
            table.insert(elements, {
                type = "number",
                name = name,
                label = inp.text or name,
                required = inp.isRequired == true,
                default = inp.default,
            })
        elseif t == "radio" or t == "select" then
            local el = {
                type = "select",
                name = name,
                label = inp.text or name,
                options = mapSelectOptions(inp.options),
            }
            if inp.default ~= nil then
                el.value = inp.default
            end
            table.insert(elements, el)
        elseif t == "checkbox" and inp.options and #inp.options > 0 then
            meta.checkboxInternals[name] = {}
            for _, opt in ipairs(inp.options) do
                local internal = string.format("%s__cb_%s", name, safeInternalSuffix(opt.value))
                table.insert(meta.checkboxInternals[name], {
                    internal = internal,
                    value = opt.value,
                })
                table.insert(elements, {
                    type = "checkbox",
                    name = internal,
                    label = opt.text or tostring(opt.value),
                    value = opt.checked == true,
                })
            end
        elseif t == "checkbox" then
            table.insert(elements, {
                type = "checkbox",
                name = name,
                label = inp.text or name,
                value = inp.default == true,
            })
        end

        ::continue::
    end

    return elements, meta
end

local function buildDialogResult(close, meta)
    if not close then
        return nil
    end
    local skip = {}
    for _, list in pairs(meta.checkboxInternals or {}) do
        for _, info in ipairs(list) do
            skip[info.internal] = true
        end
    end

    local out = {}
    for k, v in pairs(close) do
        if not skip[k] then
            out[k] = v
        end
    end

    for baseName, list in pairs(meta.checkboxInternals or {}) do
        local selected = {}
        for _, info in ipairs(list) do
            if close[info.internal] then
                table.insert(selected, info.value)
            end
        end
        out[baseName] = selected
    end

    return out
end

---@param data table qb-input dialog definition
---@return table|nil dialog fields, or nil if cancelled / empty
function ShowInput(data)
    if not data or not data.inputs then
        return nil
    end

    local elements, meta = buildFormElements(data.inputs)
    if #elements == 0 then
        return nil
    end

    local p = promise.new()
    local ns = string.format("qb_input_bridge_%s_%s", GetGameTimer(), math.random(1000, 9999))

    TMC.Functions.OpenMenu({
        namespace = ns,
        title = data.header or "Input",
        subtitle = data.subtitle,
        form = true,
    }, elements, function(close, confirmed)
        if confirmed and close then
            p:resolve(buildDialogResult(close, meta))
        else
            p:resolve(nil)
        end
    end, nil, nil)

    return Citizen.Await(p)
end

exports("ShowInput", ShowInput)