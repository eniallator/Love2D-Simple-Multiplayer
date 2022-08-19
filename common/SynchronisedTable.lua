local function copyTbl(tbl, innerTblFunc)
    local newTbl = {}
    for key, value in pairs(tbl) do
        if type(value) == 'table' then
            newTbl[key] = innerTblFunc(key, value)
        else
            newTbl[key] = value
        end
    end
    return newTbl
end

local function SynchronisedMetaTable(class)
    local mt = {
        __dataChanged = true,
        __data = {},
        __otherTypes = {},
        __subTables = {},
        __metatable = 'SynchronisedTable',
        __class = class
    }

    local DATA_VALUE_TYPES = {
        number = true,
        boolean = true,
        string = true
    }

    local SUB_TABLE_DELETED = 'deleted'

    function mt.__index(tbl, key)
        local metaPrefix = 'meta_'
        if key:sub(1, #metaPrefix) == metaPrefix then
            return mt[key:sub(#metaPrefix + 1)]
        end
        return mt.__data[key] or mt.__subTables[key] or mt.__otherTypes[key]
    end

    function mt.__newindex(tbl, key, value)
        local valType = type(value)
        if valType == 'table' then
            -- Trigger update if overwriting a data value with a subTable
            mt.__dataChanged = mt.__dataChanged or mt.__data[key] ~= nil
            mt.__data[key] = nil
            if getmetatable(value) == mt.__metatable then
                mt.__subTables[key] = value
            else
                mt.__subTables[key] = mt.__class(value)
            end
        elseif DATA_VALUE_TYPES[valType] or valType == 'nil' then
            -- Trigger update if data value changed
            mt.__dataChanged = mt.__dataChanged or mt.__data[key] ~= value
            mt.__subTables[key] = mt.__subTables[key] ~= nil and SUB_TABLE_DELETED or nil
            mt.__data[key] = value
        else
            mt.__otherTypes[key] = value
        end
    end

    function mt.peekUpdates(force)
        local updates = {hasData = false}
        if mt.__dataChanged or force then
            updates.data = {}
            for key, value in pairs(mt.__data or {}) do
                updates.hasData = true
                updates.data[key] = value
            end
        end
        for key, value in pairs(mt.__subTables or {}) do
            if updates.subTables == nil then
                updates.subTables = {}
            end
            if value == SUB_TABLE_DELETED then
                updates.subTables[key] = value
            else
                local subUpdates = value.meta_peekUpdates(force)
                if subUpdates ~= nil and subUpdates.hasData then
                    updates.hasData = true
                    updates.subTables[key] = subUpdates
                end
            end
        end
        return (updates.data ~= nil or updates.subTables ~= nil) and updates or nil
    end

    function mt.popUpdates(force)
        -- Duplicated most of the body from above for efficiency
        local updates = {hasData = false}
        if mt.__dataChanged or force then
            updates.data = {}
            for key, value in pairs(mt.__data or {}) do
                updates.hasData = true
                updates.data[key] = value
            end
        end
        for key, value in pairs(mt.__subTables or {}) do
            if updates.subTables == nil then
                updates.subTables = {}
            end
            if value == SUB_TABLE_DELETED then
                updates.subTables[key] = value
                mt.__subTables[key] = nil
            else
                local subUpdates = value.meta_popUpdates(force)
                if subUpdates ~= nil and subUpdates.hasData then
                    updates.hasData = true
                    updates.subTables[key] = subUpdates
                end
            end
        end
        mt.__dataChanged = false
        return (updates.data ~= nil or updates.subTables ~= nil) and updates or nil
    end

    function mt.pushUpdates(updates)
        if updates.data ~= nil then
            mt.__data = updates.data
            mt.__dataChanged = true
        end
        for key, value in pairs(updates.subTables or {}) do
            if value == SUB_TABLE_DELETED then
                mt.__subTables[key] = nil
            else
                if mt.__subTables[key] == nil then
                    mt.__subTables[key] = mt.__class()
                end
                mt.__subTables[key].meta_pushUpdates(value)
            end
        end
    end

    function mt.clearUpdates()
        mt.__dataChanged = false
        for _, subTable in pairs(mt.__subTables) do
            subTable.meta_clearUpdates()
        end
    end

    return mt
end

local function serialiseValue(value)
    if type(value) == 'string' then
        return '"' .. value:gsub('["\\]', '\\"') .. '"'
    end
    return tostring(value)
end

local function serialiseUpdates(updates)
    local dataStr = ''
    for key, value in pairs(updates.data or {}) do
        if #dataStr > 0 then
            dataStr = dataStr .. ','
        end
        dataStr = dataStr .. key .. '=' .. serialiseValue(value)
    end
    if dataStr ~= '' then
        dataStr = '{' .. dataStr .. '}'
    end
    local subTablesStr = ''
    for key, value in pairs(updates.subTables or {}) do
        if subTablesStr ~= '' then
            subTablesStr = subTablesStr .. ','
        end
        local serialisedValue = serialiseUpdates(value)
        subTablesStr = subTablesStr .. key .. serialisedValue
    end
    return dataStr .. (subTablesStr == '' and '' or '[' .. subTablesStr .. ']')
end

local function deserialiseValue(str, i)
    if str:sub(i, i) == '"' then
        i = i + 1
        local val = ''
        local escaped = false
        local char = str:sub(i, i)
        while i <= #str and (char ~= '"' or escaped) do
            escaped = char == '\\'
            val = val .. char
            i = i + 1
            char = str:sub(i, i)
        end
        return val:gsub('\\(["\\])', '%1'), i + 1
    elseif str:sub(i, i + 3) == 'true' or str:sub(i, i + 4) == 'false' then
        local val = str:sub(i, i + 3) == 'true'
        return val, val and i + 4 or i + 5
    else
        -- Splitting pattern up since no optional group captures
        local wholePart = str:sub(i):match('^[+-]?%d+')
        i = i + #wholePart
        local decimalPart = str:sub(i):match('^%.%d+') or ''
        i = i + #decimalPart
        local exponentialPart = str:sub(i):match('^e[+-]?%d+') or ''
        i = i + #exponentialPart
        return tonumber(wholePart .. decimalPart .. exponentialPart), i
    end
end

local function deserialiseData(str, i)
    local data = {}
    i = i + 1
    while str:sub(i, i) ~= '}' do
        local key, value = str:sub(i):match('%w+')
        i = i + #key
        if str:sub(i, i) ~= '=' then
            error('Malformed updates string, expected "=" at char ' .. i .. ', instead found "' .. str:sub(i, i) .. '"')
        end
        i = i + 1

        value, i = deserialiseValue(str, i)
        if str:sub(i, i) == ',' then
            i = i + 1
        end

        data[key] = value
    end
    return data, i + 1
end

local function deserialiseUpdatesString(str, i)
    -- Return updates table
    -- Recurse at the deserialiseData bit, where the key of the subTable is the last bit this knows about
    -- then if it comes across a , or a ] at the same level as the current subTable it will return
    i = i or 1
    local updates = {}

    if str:sub(i, i) == '{' then
        updates.data, i = deserialiseData(str, i)
    end
    if str:sub(i, i) == '[' then
        i = i + 1
        while str:sub(i, i) ~= ']' do
            if updates.subTables == nil then
                updates.subTables = {}
            end
            local subTableKey = str:sub(i):match('^%w+')
            updates.subTables[subTableKey], i = deserialiseUpdatesString(str, i + #subTableKey)
            local sep = str:sub(i, i)
            if sep == ',' then
                i = i + 1
            elseif sep ~= ']' then
                error('Malformed updates string at character ' .. i)
            end
        end
        i = i + 1
    end
    return updates, i
end

local function SynchronisedTable(initialData)
    local synchronisedTable = {}
    local mt = SynchronisedMetaTable(SynchronisedTable)
    setmetatable(synchronisedTable, mt)

    if initialData ~= nil then
        for key, value in pairs(initialData) do
            synchronisedTable[key] = value
        end
    end

    function synchronisedTable:dataPairs()
        return pairs(mt.__data)
    end
    function synchronisedTable:subTablePairs()
        return pairs(mt.__subTables)
    end

    function synchronisedTable:serialiseData()
        local data = mt.peekUpdates(true)
        return serialiseUpdates(data)
    end

    function synchronisedTable:serialiseUpdates(peekUpdates, force)
        local updates = peekUpdates and mt.peekUpdates(force) or mt.popUpdates(force)
        return serialiseUpdates(updates)
    end

    function synchronisedTable:clearUpdates()
        mt.clearUpdates()
    end

    function synchronisedTable:deserialiseUpdates(updatesString)
        local deserialisedUpdates, i = deserialiseUpdatesString(updatesString)
        if i < #updatesString then
            error("Didn't process entire updatesString")
        end
        mt.pushUpdates(deserialisedUpdates)
    end

    return synchronisedTable
end

return SynchronisedTable
