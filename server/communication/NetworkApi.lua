local SynchronisedTable = require 'common.SynchronisedTable'

return function(initialLocalState)
    local networkApi = {}

    networkApi.__localState = SynchronisedTable(initialLocalState)
    networkApi.__lastAge = -1

    -- receivedState is the connections table
    networkApi.__receivedState = SynchronisedTable()
    networkApi.__hasReceivedState = false

    networkApi.__server = love.thread.newThread('server/communication/Server.lua')
    networkApi.__server:start()

    networkApi.__outChannel = love.thread.getChannel('SERVER_OUT')
    networkApi.__inChannel = love.thread.getChannel('SERVER_IN')

    function networkApi:setAge(age)
        self.__localState:setAge(age)
    end

    function networkApi:flushUpdates(age, force)
        self:send(tostring(age) .. ':' .. self.__localState:serialiseUpdates(self.__lastAge - 1, force))
        self.__lastAge = age
    end

    function networkApi:send(msg)
        if msg then
            if msg ~= '' then
            -- print('SERVER sent:', msg)
            end
            self.__outChannel:push(msg)
        end
    end

    function networkApi:update()
        local msg = self.__inChannel:pop()
        while msg do
            -- print('SERVER got:', msg)
            if msg ~= '' then
                self.__receivedState:deserialiseUpdates(msg, self.tickAge)
                self.__hasReceivedState = true
            end
            msg = self.__inChannel:pop()
        end
    end

    function networkApi:getLocalState()
        return self.__localState
    end
    function networkApi:getReceivedState()
        return self.__hasReceivedState and self.__receivedState or nil
    end

    networkApi:flushUpdates(0, true)

    return networkApi
end
