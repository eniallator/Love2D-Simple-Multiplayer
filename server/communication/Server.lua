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

local addressToIdMap = {}
local connections = SynchronisedTable()
-- Keeping own state table, for the case where one of the clients needs the full state
--   and the other thread doesn't know to send the full state or not
-- Also for the case of packet loss
local serverState = SynchronisedTable()
local id, tickAge = 1
local ticked = false

while true do
    local msg, updates = outChannel:pop()
    while msg do
        ticked = true
        tickAge, updates = msg:match('^(%d+):(.*)')
        serverState:deserialiseUpdates(updates)
        msg = outChannel:pop()
    end
    tickAge = tonumber(tickAge)

    local data, ip, port = udp:receivefrom()
    if data then
        connections:setAge(tickAge)
        local address = ip .. ':' .. tostring(port)
        local key = addressToIdMap[address]
        local headers, payload = packet.deserialise(data)
        if key == nil then
            connections[id] = {
                id = id,
                ip = ip,
                port = port,
                clientTickAge = -1,
                lastServerTickAge = -1,
                state = {}
            }
            addressToIdMap[address] = id
            print('connected id:', id)
            id = id + 1
        else
            connections[key].clientTickAge, connections[key].lastServerTickAge =
                tonumber(headers.clientTickAge or connections[key].clientTickAge),
                tonumber(headers.serverTickAge or connections[key].lastServerTickAge)
            if headers.tickAge then
                connections[key].tickAge = tonumber(headers.tickAge)
            end
            connections[key].state:deserialiseUpdates(payload, tickAge)
        end
    end

    if ticked then
        ticked = false
        inChannel:push(connections:serialiseUpdates(tickAge - 1))
        local updatesLookup = {}
        for address, connection in connections.subTablePairs() do
            if updatesLookup[connection.lastServerTickAge] == nil then
                updatesLookup[connection.lastServerTickAge] =
                    serverState:serialiseUpdates(connection.lastServerTickAge - 1)
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
