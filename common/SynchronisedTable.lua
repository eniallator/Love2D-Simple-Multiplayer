local function serialiseValue(value)
    if type(value) == 'string' then
        return '"' .. value:gsub('(["\\])', '\\%1') .. '"'
    end
    return tostring(value)
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

    local SUB_TABLE_DELETED = '$DELETED'

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

    function mt.serialiseUpdates(peek, force)
        local dataStr = ''
        if mt.__dataChanged or force then
            dataStr = ''
            for key, value in pairs(mt.__data or {}) do
                if #dataStr > 0 then
                    dataStr = dataStr .. ','
                end
                dataStr = dataStr .. key .. '=' .. serialiseValue(value)
            end
            if dataStr ~= '' then
                dataStr = '{' .. dataStr .. '}'
            end
        end
        local subTablesStr = ''
        for key, value in pairs(mt.__subTables or {}) do
            local serialisedValue = value
            if value == SUB_TABLE_DELETED and not peek then
                mt.__subTables[key] = nil
            elseif value ~= SUB_TABLE_DELETED then
                serialisedValue = value.meta_serialiseUpdates(peek, force) or ''
            end
            if serialisedValue ~= '' then
                if subTablesStr ~= '' then
                    subTablesStr = subTablesStr .. ','
                end
                subTablesStr = subTablesStr .. key .. serialisedValue
            end
        end
        mt.__dataChanged = peek and mt.__dataChanged or false
        return dataStr .. (subTablesStr == '' and '' or '[' .. subTablesStr .. ']')
    end

    function mt.deserialiseUpdates(str, i)
        i = i or 1
        if str:sub(i, i) == '{' then
            mt.__data = {}
            i = i + 1
            while str:sub(i, i) ~= '}' do
                local key, value = str:sub(i):match('%w+')
                i = i + #key
                if str:sub(i, i) ~= '=' then
                    error(
                        'Malformed updates string, expected "=" at char ' ..
                            i .. ', instead found "' .. str:sub(i, i) .. '"'
                    )
                end
                i = i + 1
                value, i = deserialiseValue(str, i)
                if str:sub(i, i) == ',' then
                    i = i + 1
                end
                mt.__data[key] = value
            end
            i = i + 1
            mt.__dataChanged = true
        end
        if str:sub(i, i) == '[' then
            i = i + 1
            while str:sub(i, i) ~= ']' do
                local subTableKey = str:sub(i):match('^%w+')
                i = i + #subTableKey
                if str:sub(i, i + #SUB_TABLE_DELETED) == SUB_TABLE_DELETED then
                    i = i + #SUB_TABLE_DELETED
                    mt.__subTables[subTableKey] = nil
                else
                    if mt.__subTables[subTableKey] == nil then
                        mt.__subTables[subTableKey] = mt.__class()
                    end
                    i = mt.__subTables[subTableKey].meta_deserialiseUpdates(str, i)
                end
                local sep = str:sub(i, i)
                if sep == ',' then
                    i = i + 1
                elseif sep ~= ']' then
                    error('Malformed updates string at character ' .. i)
                end
            end
            i = i + 1
        end
        return i
    end

    function mt.clearUpdates()
        mt.__dataChanged = false
        for _, subTable in pairs(mt.__subTables) do
            subTable.meta_clearUpdates()
        end
    end

    return mt
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

    function synchronisedTable:serialiseUpdates(peek, force)
        return mt.serialiseUpdates(peek, force)
    end

    function synchronisedTable:clearUpdates()
        mt.clearUpdates()
    end

    function synchronisedTable:deserialiseUpdates(updatesString)
        if mt.deserialiseUpdates(updatesString) < #updatesString then
            error("Didn't process entire updatesString")
        end
    end

    return synchronisedTable
end

return SynchronisedTable
