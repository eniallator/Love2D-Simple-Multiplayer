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

local function SynchronisedMetaTable()
    local mt = {
        __dataChanged = true,
        __data = {},
        __subTables = {},
        __metatable = 'SynchronisedTable'
    }

    local SUB_TABLE_DELETED = 'deleted'

    function mt.__index(tbl, key)
        return mt.__data[key] or mt.__subTables[key]
    end

    function mt.__newindex(tbl, key, value)
        if type(value) == 'table' then
            -- Trigger update if overwriting a data value with a subTable
            mt.__dataChanged = mt.__dataChanged or mt.__data[key] ~= nil
            mt.__data[key] = nil
            if getmetatable(value) == mt.__metatable then
                mt.__subTables[key] = value
            else
                mt.__subTables[key] = SynchronisedTable(value)
            end
        else
            -- Trigger update if data value changed
            mt.__dataChanged = mt.__dataChanged or mt.__data[key] ~= value
            mt.__subTables[key] = mt.__subTables[key] ~= nil and SUB_TABLE_DELETED or nil
            mt.__data[key] = value
        end
    end

    function mt:peekUpdates()
        local updates = {}
        if self.__dataChanged then
            updates.data = {}
            for key, value in pairs(self.__data) do
                updates.data[key] = value
            end
        end
        for key, value in self.__subTables do
            if updates.subTables == nil then
                updates.subTables = {}
            end
            if value == SUB_TABLE_DELETED then
                updates.subTables[key] = value
            else
                updates.subTables[key] = value:peekUpdates()
            end
        end
        return (updates.data ~= nil or updates.subTables ~= nil) and updates or nil
    end

    function mt:popUpdates()
        -- Duplicated most of the body from above for efficiency
        local updates = {}
        if self.__dataChanged then
            updates.data = {}
            for key, value in pairs(self.__data) do
                updates.data[key] = value
            end
        end
        for key, value in self.__subTables do
            if updates.subTables == nil then
                updates.subTables = {}
            end
            if value == SUB_TABLE_DELETED then
                updates.subTables[key] = value
                self.__subTables[key] = nil
            else
                updates.subTables[key] = value:popUpdates()
            end
        end
        self.__dataChanged = false
        return (updates.data ~= nil or updates.subTables ~= nil) and updates or nil
    end

    function mt:pushUpdates(updates)
        if updates.data ~= nil then
            self.__data = updates.data
        end
        for key, value in pairs(updates.subTables or {}) do
            if value == SUB_TABLE_DELETED then
                self.__subTables[key] = nil
            else
                if self.__subTables[key] == nil then
                    self.__subTables[key] = SynchronisedTable()
                end
                self.__subTables[key]:pushUpdates(value)
            end
        end
    end

    return mt
end

local function serialiseValue(value)
    if type(value) == 'string' then
        return '"' .. value:gsub('"', '\\"') .. '"'
    end
    return tostring(value)
end

local function serialiseUpdatesTable(updates)
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

    local subTablesSerialised = {}
    for key, value in pairs(updates.subTables or {}) do
        table.insert(subTablesSerialised, {key = key, value = serialiseUpdatesTable(value)})
    end
    local subTablesStr = ''
    if #subTablesSerialised == 1 then
        subTablesStr = '.' .. subTablesSerialised[1].key .. '=' .. subTablesSerialised[1].value
    elseif #subTablesSerialised > 1 then
        subTablesStr = '['
        for i, item in ipairs(subTablesSerialised) do
            if subTablesStr ~= '[' then
                subTablesStr = subTablesStr .. ','
            end
            subTablesStr = subTablesStr .. item.key .. '=' .. item.value
        end
        subTablesStr = subTablesStr .. ']'
    end

    return dataStr .. subTablesStr
end

local function deserialiseValue(str)
    if str:sub(1, 1) == '"' then
        return str:sub(2, #str - 1):gsub('\\"', '"')
    elseif str == 'true' or str == 'false' then
        return str == 'true'
    end
    return tonumber(str)
end

local function deserialiseUpdatesString(updatesString, currentIndex)
    currentIndex = currentIndex or 1
    local updates = {}
end

local function SynchronisedTable(initialData)
    local synchronisedTable = {}
    local mt = SynchronisedMetaTable()
    setmetatable(synchronisedTable, mt)

    if initialData ~= nil then
        for key, value in pairs(initialData) do
            synchronisedTable[key] = value
        end
    end

    function synchronisedTable:serialiseUpdates(peekUpdates)
        local updates = peekUpdates and self:peekUpdates() or self:popUpdates()
        return serialiseUpdatesTable(updates)
    end

    function synchronisedTable:deserialiseUpdates(updatesString)
        local deserialisedUpdates = deserialiseUpdatesString(updatesString)
        self:pushUpdates(deserialisedUpdates)
    end

    return synchronisedTable
end

return SynchronisedTable
