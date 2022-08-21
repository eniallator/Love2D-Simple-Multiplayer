local SynchronisedTable = require 'common.SynchronisedTable'
local packet = require 'common.Packet'
local socket = require 'socket'
local cfg = require 'conf'
local udp = socket.udp()

udp:settimeout(0)
udp:setpeername(cfg.communication.address, cfg.communication.port)

local inChannel = love.thread.getChannel('CLIENT_IN')
local outChannel = love.thread.getChannel('CLIENT_OUT')

local tickAge, serverTickAge, serverLastClientTickAge = -1, -1, -1
local clientState = SynchronisedTable()
local updateServer = false

while true do
    local msg = outChannel:pop()
    while msg do
        updateServer = true
        local updates
        tickAge, updates = msg:match('^(%d+):(.*)')
        clientState:deserialiseUpdates(updates)
        msg = outChannel:pop()
    end
    tickAge = tonumber(tickAge)

    data, msg = udp:receive()
    if data then
        local headers, payload = packet.deserialise(data)
        serverTickAge, serverLastClientTickAge = tonumber(headers.serverTickAge), tonumber(headers.lastClientTickAge)
        inChannel:push(headers.id .. ':' .. payload)
    end

    if updateServer then
        updateServer = false
        udp:send(
            packet.serialise(
                {clientTickAge = tickAge, serverTickAge = serverTickAge},
                clientState:serialiseUpdates(serverLastClientTickAge)
            )
        )
    end
end
