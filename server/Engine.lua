local cfg = require 'conf'
local Server, server = require 'server.Main'

server = Server(cfg)

-- Handle all dt/game enginey type things here

local lastTicked = os.clock()

while true do
    local currTime = os.clock()
    local dt = currTime - lastTicked
    lastTicked = currTime

    server:update(dt)
end
