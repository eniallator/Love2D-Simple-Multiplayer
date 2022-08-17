local SynchronisedTable = require 'SynchronisedTable'
local socket = require 'socket'
local udp = socket.udp()

udp:settimeout(0)
udp:setsockname('localhost', 3000)

local connections = {}
local state =
    SynchronisedTable(
    {
        players = {},
        backgroundColour = {
            r = 0.2,
            g = 0.3,
            b = 0.4
        }
    }
)
local id = 1

while true do
    local data, ip, port = udp:receivefrom()
    if data then
        if data == 'connect' then
            connections[tostring(id)] = {
                initialized = false,
                ip = ip,
                port = port,
                sendFullState = true,
                state = SynchronisedTable()
            }
            udp:sendto('id:' .. tostring(id), ip, port)
            print('connected id:', id)
            id = id + 1
        else
            local key, data = data:match('(%d+):(.*)')
            connections[key].state:deserialiseUpdates(data)
            if not connections[key].initialized then
                state.players[key] = connections[key].state
                connections[key].initialized = true
            end
        end

        local updates, fullState = state:serialiseUpdates()
        for id, connection in pairs(connections) do
            if connection.initialized then
                if connection.sendFullState then
                    if fullState == nil then
                        fullState = state:serialiseUpdates(true, true)
                    end
                    udp:sendto(fullState, connection.ip, connection.port)
                    connection.sendFullState = false
                else
                    udp:sendto(updates, connection.ip, connection.port)
                end
            end
        end
    end
end
