local SynchronisedTable = require 'common.SynchronisedTable'

return function(initialLocalState)
    local baseNetworkApi = {}

    baseNetworkApi.__localState = SynchronisedTable(initialLocalState)
    baseNetworkApi.__lastAge = -1

    baseNetworkApi.__receivedState = SynchronisedTable()
    baseNetworkApi.__hasReceivedState = false

    function baseNetworkApi:setAge(age)
        self.__localState:setAge(age)
    end

    function baseNetworkApi:flushUpdates(age, force)
        self:send(tostring(age) .. ':' .. self.__localState:serialiseUpdates(self.__lastAge - 1, force))
        self.__lastAge = age
    end

    function baseNetworkApi:send(msg)
        error('NetworkApi must implement a send method')
    end

    function baseNetworkApi:update()
        error('NetworkApi must implement an update method')
    end

    function baseNetworkApi:getLocalState()
        return self.__localState
    end
    function baseNetworkApi:getReceivedState()
        return self.__hasReceivedState and self.__receivedState or nil
    end

    return baseNetworkApi
end
