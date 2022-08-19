local SynchronisedTable = require 'common.SynchronisedTable'
local socket = require 'socket'
local cfg = require 'conf'
local udp = socket.udp()

udp:settimeout(0)
udp:setsockname(cfg.communication.address, cfg.communication.port)

-- Look into having server logic, where it controls when the server communicates (tps)
--   Also has code for doing things with the state

local inChannel = love.thread.getChannel('SERVER_IN')
local outChannel = love.thread.getChannel('SERVER_OUT')

local connections = SynchronisedTable()
-- Keeping own state table, for the case where one of the clients needs the full state
--   and the other thread doesn't know to send the full state or not
local serverState = SynchronisedTable()
local id = 1

while true do
    local msg = outChannel:pop()
    local updateClients = false
    while msg do
        updateClients = true
        serverState:deserialiseUpdates(msg)
        msg = outChannel:pop()
    end

    local data, ip, port = udp:receivefrom()
    if data then
        if data == 'connect' then
            connections[tostring(id)] = {
                ip = ip,
                port = port,
                initialized = false,
                sendFullState = true,
                state = {}
            }
            udp:sendto('id:' .. tostring(id), ip, port)
            print('connected id:', id)
            id = id + 1
        else
            local key, data = data:match('(%d+):(.*)')
            connections[key].initialized = true
            connections[key].state:deserialiseUpdates(data)
        end

        inChannel:push(connections:serialiseUpdates())
    end

    if updateClients then
        local updates, fullState
        updates = serverState:serialiseUpdates()
        for id, connection in connections.subTablePairs() do
            if connection.initialized then
                if connection.sendFullState then
                    if fullState == nil then
                        fullState = serverState:serialiseUpdates(true, true)
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
