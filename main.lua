local dim = {}
local isServer = true

dim.width, dim.height = love.graphics.getDimensions()
local pos = {x = dim.width / 2, y = dim.height / 2}
local gameTable = {}
local client
local server

function love.load()
    if isServer then
        server = love.thread.newThread("server.lua")
        server:start()
    end

    client = love.thread.newThread("client.lua")
    client:start()
end

function unserialise(msg)
    local tbl = {}
    for msgPos in msg:gmatch("[^p]+") do
        local pos = {}
        pos.x, pos.y = msgPos:match("x(%d+)y(%d+)")
        pos.x = tonumber(pos.x)
        pos.y = tonumber(pos.y)
        table.insert(tbl, pos)
    end
    return tbl
end

function love.update(dt)
    out = love.thread.getChannel("outgoing")
    inc = love.thread.getChannel("incoming")
    if love.keyboard.isDown("s") then
        out:push("s")
    end
    if love.keyboard.isDown("w") then
        out:push("w")
    end
    if love.keyboard.isDown("d") then
        out:push("d")
    end
    if love.keyboard.isDown("a") then
        out:push("a")
    end

    local msg = inc:pop()
    while msg do
        gameTable = unserialise(msg)
        msg = inc:pop()
    end
end

function love.draw()
    for id, pos in pairs(gameTable) do
        love.graphics.rectangle("fill", pos.x - 10, pos.y - 10, 20, 20)
    end
end
