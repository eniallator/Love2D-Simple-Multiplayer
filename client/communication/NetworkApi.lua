local SynchronisedTable = require 'common.SynchronisedTable'
local BaseNetworkApi = require 'common.BaseNetworkApi'

return function(initialLocalState)
    local networkApi = BaseNetworkApi(initialLocalState)

    networkApi.__client = love.thread.newThread('client/communication/Client.lua')
    networkApi.__client:start()

    networkApi.__outChannel = love.thread.getChannel('CLIENT_OUT')
    networkApi.__inChannel = love.thread.getChannel('CLIENT_IN')

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

    networkApi:flushUpdates(0, true)

    return networkApi
end
