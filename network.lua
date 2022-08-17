local SynchronisedTable = require 'SynchronisedTable'

return function(isServer, initialLocalState, sendUpdatesOnMsgReceived)
    local network = {}
    network.sendUpdatesOnMsgReceived = sendUpdatesOnMsgReceived

    if isServer then
        network.__server = love.thread.newThread('server.lua')
        network.__server:start()
    end

    network.__client = love.thread.newThread('client.lua')
    network.__client:start()

    network.__outChannel = love.thread.getChannel('outgoing')
    network.__inChannel = love.thread.getChannel('incoming')

    network.__localState = SynchronisedTable(initialLocalState)

    network.__receivedState = SynchronisedTable()
    network.__hasReceivedState = false

    function network:update()
        if not self.sendUpdatesOnMsgReceived then
            self:send(self.__localState:serialiseUpdates())
        end
        self:receiveState()
    end

    function network:send(msg)
        if msg and msg ~= '' then
            print('sent:', msg)
            self.__outChannel:push(msg)
        end
    end

    function network:receiveState()
        local msg = self.__inChannel:pop()
        local gotMsg = false
        while msg do
            gotMsg = true
            print('got:', msg)
            if msg ~= '' then
                self.__receivedState:deserialiseUpdates(msg)
                self.__hasReceivedState = true
            end
            msg = self.__inChannel:pop()
        end
        if gotMsg and self.sendUpdatesOnMsgReceived then
            self:send(self.__localState:serialiseUpdates())
        end
    end

    function network:getLocalState()
        return self.__localState
    end

    function network:getReceivedState()
        return self.__hasReceivedState and self.__receivedState or nil
    end

    network:send(network.__localState:serialiseUpdates())

    return network
end
