local cfg = require 'conf'
local Client, client = require 'client.Main'

function love.load()
    if cfg.launchServer then
        local server = love.thread.newThread('server/Engine.lua')
        server:start()
    end

    math.randomseed(os.time())
    client = Client(cfg)
end

function love.update(dt)
    client:update(dt)
end

function love.draw()
    client:draw()
end
