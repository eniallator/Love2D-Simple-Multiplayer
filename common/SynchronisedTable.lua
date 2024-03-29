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

local function SynchronisedMetaTable(class, initialAge)
    local SUB_TABLE_DELETED = '$DELETED'
    local AGE_KEY = '__AGE'

    local mt = {
        __newAge = initialAge or 0,
        __data = {[AGE_KEY] = initialAge or 0},
        __otherTypes = {},
        __subTables = {},
        __metatable = 'SynchronisedTable',
        __class = class
    }

    local DATA_VALUE_TYPES = {
        number = true,
        boolean = true,
        string = true,
        ['nil'] = true
    }

    function mt.__index(tbl, key)
        local metaPrefix = 'meta_'
        if tostring(key):sub(1, #metaPrefix) == metaPrefix then
            return mt[key:sub(#metaPrefix + 1)]
        end
        return mt.__data[key] or mt.__subTables[key] or mt.__otherTypes[key]
    end

    function mt.__newindex(tbl, key, value)
        if key == AGE_KEY then
            mt.__data[key] = value
            return
        end
        local valType = type(value)
        if valType == 'table' then
            -- Trigger update if overwriting a data value with a subTable
            if mt.__data[key] ~= nil then
                mt.__data[AGE_KEY] = mt.__newAge
                mt.__data[key] = nil
            end
            if getmetatable(value) == mt.__metatable then
                mt.__subTables[key] = value
            else
                mt.__subTables[key] = mt.__class(value, mt.__data[AGE_KEY])
            end
        elseif DATA_VALUE_TYPES[valType] then
            -- Trigger update if data value changed
            if mt.__data[key] ~= value then
                mt.__data[AGE_KEY] = mt.__newAge
            end
            mt.__subTables[key] = mt.__subTables[key] ~= nil and SUB_TABLE_DELETED or nil
            mt.__data[key] = value
        else
            mt.__otherTypes[key] = value
        end
    end

    function mt.serialiseUpdates(age, force)
        local dataStr = ''
        if age <= mt.__data[AGE_KEY] or force then
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
            if value == SUB_TABLE_DELETED then
                mt.__subTables[key] = nil
            else
                serialisedValue = value.meta_serialiseUpdates(age, force) or ''
            end
            if serialisedValue ~= '' then
                if subTablesStr ~= '' then
                    subTablesStr = subTablesStr .. ','
                end
                subTablesStr = subTablesStr .. key .. serialisedValue
            end
        end
        return dataStr .. (subTablesStr == '' and '' or '[' .. subTablesStr .. ']')
    end

    function mt.deserialiseUpdates(str, age, i)
        i = i or 1
        if str:sub(i, i) == '{' then
            mt.__data = {}
            i = i + 1
            while str:sub(i, i) ~= '}' do
                local key, value = str:sub(i):match('^[%w_]+')
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
                if key == AGE_KEY then
                    age = age or value
                else
                    mt.__data[key] = value
                end
            end
            i = i + 1
            if age then
                mt.__data[AGE_KEY] = age
            end
        end
        if str:sub(i, i) == '[' then
            i = i + 1
            while str:sub(i, i) ~= ']' do
                local subTableKey = str:sub(i):match('^[^,%]{%[]+')
                i = i + #subTableKey
                if str:sub(i, i + #SUB_TABLE_DELETED) == SUB_TABLE_DELETED then
                    i = i + #SUB_TABLE_DELETED
                    mt.__subTables[subTableKey] = nil
                else
                    if mt.__subTables[subTableKey] == nil then
                        mt.__subTables[subTableKey] = mt.__class()
                    end
                    i = mt.__subTables[subTableKey].meta_deserialiseUpdates(str, age, i)
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

    return mt
end

local function SynchronisedTable(initialData, initialAge)
    local synchronisedTable = {}
    local mt = SynchronisedMetaTable(SynchronisedTable, initialAge)
    setmetatable(synchronisedTable, mt)

    if initialData ~= nil then
        for key, value in pairs(initialData) do
            synchronisedTable[key] = value
        end
    end

    function synchronisedTable:setAge(age)
        mt.__newAge = age
        for _, subTable in pairs(mt.__subTables) do
            subTable:setAge(age)
        end
    end

    function synchronisedTable:dataPairs()
        return pairs(mt.__data)
    end
    function synchronisedTable:subTablePairs()
        return pairs(mt.__subTables)
    end

    function synchronisedTable:serialiseUpdates(age, force)
        return mt.serialiseUpdates(age, force)
    end

    function synchronisedTable:deserialiseUpdates(updatesString, age)
        if mt.deserialiseUpdates(updatesString, age) < #updatesString then
            error("Didn't process entire updatesString")
        end
    end

    return synchronisedTable
end

return SynchronisedTable
