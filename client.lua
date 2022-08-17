local socket = require 'socket'
local udp = socket.udp()

udp:settimeout(0)
udp:setpeername('localhost', 3000)
udp:send('connect')

local id

while true do
    data, msg = udp:receive()
    if data then
        if data:match('id:') then
            id = data:match('id:(%d+)')
        else
            love.thread.getChannel('incoming'):push(data)
        end
    end

    if id then
        local msg = love.thread.getChannel('outgoing'):pop()
        while msg do
            udp:send(id .. ':' .. msg)
            msg = love.thread.getChannel('outgoing'):pop()
        end
    end
end
