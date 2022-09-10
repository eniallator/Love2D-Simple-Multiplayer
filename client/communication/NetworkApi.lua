local SynchronisedTable = require 'common.SynchronisedTable'
local BaseNetworkApi = require 'common.BaseNetworkApi'
local packet = require 'common.Packet'
local socket = require 'socket'
local cfg = require 'conf'
local udp = socket.udp()

udp:settimeout(0)
udp:setpeername(cfg.communication.address, cfg.communication.port)

return function(initialLocalState)
    local networkApi = BaseNetworkApi(initialLocalState)

    networkApi.serverTickAge = -1
    networkApi.serverLastClientTickAge = -1

    function networkApi:checkForUpdates()
        local data, msg = udp:receive()
        while data do
            local headers, payload = packet.deserialise(data)
            self.id, self.serverTickAge, self.serverLastClientTickAge =
                headers.id,
                tonumber(headers.serverTickAge),
                tonumber(headers.lastClientTickAge)
            -- if payload ~= '' then
            --     print('CLIENT got:', payload)
            -- end
            self.__receivedState:deserialiseUpdates(payload)
            self.__hasReceivedState = true
            data, msg = udp:receive()
        end
    end

    function networkApi:flushUpdates(age, force)
        local headers = {clientTickAge = age, serverTickAge = self.serverTickAge}
        local payload = self.__localState:serialiseUpdates(self.serverLastClientTickAge - 1, force)
        -- print('CLIENT sent:', payload)
        udp:send(packet.serialise(headers, payload))
    end

    networkApi:flushUpdates(0, true)

    return networkApi
end
