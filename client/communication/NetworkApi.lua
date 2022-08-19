local SynchronisedTable = require 'common.SynchronisedTable'

return function(initialLocalState)
    local networkApi = {}

    networkApi.__localState = SynchronisedTable(initialLocalState)

    networkApi.__receivedState = SynchronisedTable()
    networkApi.__hasReceivedState = false

    networkApi.__client = love.thread.newThread('client/communication/Client.lua')
    networkApi.__client:start()

    networkApi.__outChannel = love.thread.getChannel('CLIENT_OUT')
    networkApi.__inChannel = love.thread.getChannel('CLIENT_IN')

    function networkApi:flushUpdates()
        self:send(self.__localState:serialiseUpdates())
    end

    function networkApi:send(msg)
        if msg and msg ~= '' then
            print('CLIENT sent:', msg)
            self.__outChannel:push(msg)
        end
    end

    function networkApi:update()
        local msg = self.__inChannel:pop()
        while msg do
            if msg ~= '' then
                print('CLIENT got:', msg)
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
