local SynchronisedTable = require 'common.SynchronisedTable'

return function(initialLocalState)
    local networkApi = {}

    networkApi.__localState = SynchronisedTable(initialLocalState)

    -- receivedState is the connections table
    networkApi.__receivedState = SynchronisedTable()
    networkApi.__hasReceivedState = false

    networkApi.__server = love.thread.newThread('server/communication/Server.lua')
    networkApi.__server:start()

    networkApi.__outChannel = love.thread.getChannel('SERVER_OUT')
    networkApi.__inChannel = love.thread.getChannel('SERVER_IN')

    function networkApi:flushUpdates()
        self:send(self.__localState:serialiseUpdates())
    end

    function networkApi:send(msg)
        if msg then
            if msg ~= '' then
                print('SERVER sent:', msg)
            end
            self.__outChannel:push(msg)
        end
    end

    function networkApi:update()
        local msg = self.__inChannel:pop()
        while msg do
            print('SERVER got:', msg)
            if msg ~= '' then
                self.__receivedState:deserialiseUpdates(msg)
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

    networkApi:send(networkApi.__localState:serialiseUpdates())

    return networkApi
end
