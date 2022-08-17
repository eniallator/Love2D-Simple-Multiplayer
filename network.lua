local SynchronisedTable = require 'SynchronisedTable'

return function(isServer, initialMsg)
    local network = {}
    if isServer then
        network.__server = love.thread.newThread('server.lua')
        network.__server:start()
    end

    network.__client = love.thread.newThread('client.lua')
    network.__client:start()

    network.__outChannel = love.thread.getChannel('outgoing')
    network.__inChannel = love.thread.getChannel('incoming')

    network.__receivedState = SynchronisedTable()
    network.__hasReceivedState = false

    if initialMsg ~= nil then
        network.__outChannel:push(initialMsg)
    end

    function network:send(msg)
        self.__outChannel:push(msg)
    end

    function network:receiveState()
        local msg = self.__inChannel:pop()
        while msg do
            if msg ~= '' then
                self.__receivedState:deserialiseUpdates(msg)
                self.__hasReceivedState = true
            end
            msg = self.__inChannel:pop()
        end
    end

    function network:getReceivedState()
        return self.__hasReceivedState and self.__receivedState or nil
    end

    return network
end
