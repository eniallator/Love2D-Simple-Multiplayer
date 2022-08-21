local SynchronisedTable = require 'common.SynchronisedTable'
local packet = require 'common.Packet'
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
local connectionsAge = -1
-- Keeping own state table, for the case where one of the clients needs the full state
--   and the other thread doesn't know to send the full state or not
-- Also for the case of packet loss
local serverState = SynchronisedTable()
local id, tickAge = 1
local updateClients = false

while true do
    local msg, updates = outChannel:pop()
    while msg do
        updateClients = true
        tickAge, updates = msg:match('^(%d+):(.*)')
        serverState:deserialiseUpdates(updates)
        msg = outChannel:pop()
    end
    tickAge = tonumber(tickAge)

    local data, ip, port = udp:receivefrom()
    if data then
        connectionsAge = connectionsAge + 1
        connections:setAge(connectionsAge)
        local key = ip .. ':' .. tostring(port)
        local headers, payload = packet.deserialise(data)
        if connections[key] == nil then
            -- Packet loss for the connect message - handle that
            connections[key] = {
                id = id,
                ip = ip,
                port = port,
                clientTickAge = -1,
                lastServerTickAge = -1,
                state = {}
            }
            print('connected id:', id)
            id = id + 1
        elseif data then
            connections[key].clientTickAge, connections[key].lastServerTickAge =
                tonumber(headers.clientTickAge or connections[key].clientTickAge),
                tonumber(headers.serverTickAge or connections[key].lastServerTickAge)
            if headers.tickAge then
                connections[key].tickAge = tonumber(headers.tickAge)
            end
            connections[key].state:deserialiseUpdates(payload)
        end
        inChannel:push(connections:serialiseUpdates(connectionsAge - 1))
    end

    if updateClients then
        updateClients = false
        local updatesLookup = {}
        for address, connection in connections.subTablePairs() do
            if updatesLookup[connection.lastServerTickAge] == nil then
                updatesLookup[connection.lastServerTickAge] = serverState:serialiseUpdates(connection.lastServerTickAge)
            end
            udp:sendto(
                packet.serialise(
                    {id = connection.id, serverTickAge = tickAge, lastClientTickAge = connection.clientTickAge},
                    updatesLookup[connection.lastServerTickAge]
                ),
                connection.ip,
                connection.port
            )
        end
    end
end
