local socket = require 'socket'
local udp = socket.udp()
local cfg = require 'conf'

udp:settimeout(0)
udp:setpeername(cfg.communication.address, cfg.communication.port)
udp:send('connect')

local inChannel = love.thread.getChannel('CLIENT_IN')
local outChannel = love.thread.getChannel('CLIENT_OUT')

local id

while true do
    data, msg = udp:receive()
    if data then
        if data:match('^id:') then
            id = data:match('id:(%d+)')
            inChannel:push(data)
        else
            inChannel:push(data)
        end
    end

    if id then
        local msg = outChannel:pop()
        while msg do
            udp:send(id .. ':' .. msg)
            msg = outChannel:pop()
        end
    end
end
