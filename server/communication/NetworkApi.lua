local SynchronisedTable = require 'common.SynchronisedTable'
local BaseNetworkApi = require 'common.BaseNetworkApi'
local packet = require 'common.Packet'
local socket = require 'socket'
local cfg = require 'conf'
local udp = socket.udp()

udp:settimeout(0)
udp:setsockname(cfg.communication.address, cfg.communication.port)

return function(initialLocalState)
    local networkApi = BaseNetworkApi(initialLocalState)

    -- networkApi.__receivedState = SynchronisedTable()
    networkApi.addressToIdMap = {}
    networkApi.idCounter = 1

    function networkApi:checkForUpdates(age)
        local data, ip, port = udp:receivefrom()
        while data do
            self.__hasReceivedState = true
            self.__receivedState:setAge(age)
            local address = ip .. ':' .. tostring(port)
            local key = self.addressToIdMap[address]
            local headers, payload = packet.deserialise(data)
            if key == nil then
                key = self.idCounter
                self.idCounter = self.idCounter + 1

                self.__receivedState[key] = {
                    id = key,
                    ip = ip,
                    port = port,
                    clientTickAge = -1,
                    lastServerTickAge = -1,
                    sendFullState = true,
                    state = {}
                }
                self.addressToIdMap[address] = key
                print('connected id:', key)
            else
                self.__receivedState[key].sendFullState = false
            end
            self.__receivedState[key].clientTickAge, self.__receivedState[key].lastServerTickAge =
                tonumber(headers.clientTickAge or self.__receivedState[key].clientTickAge),
                tonumber(headers.serverTickAge or self.__receivedState[key].lastServerTickAge)
            self.__receivedState[key].state:deserialiseUpdates(payload, age)

            data, ip, port = udp:receivefrom()
        end
    end

    function networkApi:flushUpdates(age)
        local updatesLookup = {}
        for id, connection in self.__receivedState.subTablePairs() do
            local updatesKey = connection.sendFullState and 'fullState' or connection.lastServerTickAge
            if updatesLookup[updatesKey] == nil then
                updatesLookup[updatesKey] = self.__localState:serialiseUpdates(connection.lastServerTickAge - 1, nil)
            end
            udp:sendto(
                packet.serialise(
                    {id = connection.id, serverTickAge = age, lastClientTickAge = connection.clientTickAge},
                    updatesLookup[updatesKey]
                ),
                connection.ip,
                connection.port
            )
        end
    end

    return networkApi
end
