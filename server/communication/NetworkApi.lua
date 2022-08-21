local SynchronisedTable = require 'common.SynchronisedTable'
local BaseNetworkApi = require 'common.BaseNetworkApi'

return function(initialLocalState)
    local networkApi = BaseNetworkApi(initialLocalState)

    networkApi.__server = love.thread.newThread('server/communication/Server.lua')
    networkApi.__server:start()

    networkApi.__outChannel = love.thread.getChannel('SERVER_OUT')
    networkApi.__inChannel = love.thread.getChannel('SERVER_IN')

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

    networkApi:flushUpdates(0, true)

    return networkApi
end
