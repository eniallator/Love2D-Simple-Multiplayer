local SynchronisedTable = require 'common.SynchronisedTable'

return function(initialLocalState)
    local networkApi = {}

    networkApi.__localState = SynchronisedTable(initialLocalState)
    networkApi.__lastAge = -1

    -- receivedState is the serverState table
    networkApi.__receivedState = SynchronisedTable()
    networkApi.__hasReceivedState = false

    networkApi.__client = love.thread.newThread('client/communication/Client.lua')
    networkApi.__client:start()

    networkApi.__outChannel = love.thread.getChannel('CLIENT_OUT')
    networkApi.__inChannel = love.thread.getChannel('CLIENT_IN')

    function networkApi:setAge(age)
        self.__localState:setAge(age)
    end

    function networkApi:flushUpdates(age, force)
        self:send(tostring(age) .. ':' .. self.__localState:serialiseUpdates(self.__lastAge - 1, force))
        self.__lastAge = age
    end

    function networkApi:send(msg)
        if msg and msg ~= '' then
            -- print('CLIENT sent:', msg)
            self.__outChannel:push(msg)
        end
    end

    function networkApi:update()
        local msg, updates = self.__inChannel:pop()
        while msg do
            self.id, updates = msg:match('(%d*):(.*)')
            self.__receivedState:deserialiseUpdates(updates)
            self.__hasReceivedState = true
            -- if msg ~= '' then
            --     print('CLIENT got:', msg)
            -- end
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
