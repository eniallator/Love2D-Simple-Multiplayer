-- function serialise(a,b)local c={}local d=true;local e=""if not b then b=0 end;for f=1,b do e=e.." "end;local f=1;for g,h in pairs(a)do local i=""if g~=f then i="["..g.."] = "end;if type(h)=="table"then table.insert(c,i..serialise(a[g],b+2))d=false elseif type(h)=="string"then table.insert(c,i..'"'..a[g]..'"')else table.insert(c,i..tostring(a[g]))end;f=f+1 end;local j="{"if not d then j=j.."\n"end;for f=1,#c do if f~=1 then j=j..","if not d then j=j.."\n"end end;if not d then j=j..e.."  "end;j=j..c[f]end;if not d then j=j.."\n"..e end;return j.."}"end

local SynchronisedTable = require 'SynchronisedTable'
local isServer = true

local dim = {}
dim.width, dim.height = love.graphics.getDimensions()

local clientState, serverState
local client, server
local outChannel, inChannel

function love.load()
    math.randomseed(os.time())
    serverState = SynchronisedTable()
    clientState =
        SynchronisedTable(
        {
            pos = {
                x = dim.width * math.random(),
                y = dim.height * math.random()
            },
            colour = {
                r = math.random(),
                g = math.random(),
                b = math.random()
            }
        }
    )
    if isServer then
        server = love.thread.newThread('server.lua')
        server:start()
    end

    client = love.thread.newThread('client.lua')
    client:start()

    outChannel = love.thread.getChannel('outgoing')
    inChannel = love.thread.getChannel('incoming')

    outChannel:push(clientState:serialiseUpdates())
end

function love.update(dt)
    if love.keyboard.isDown('s') then
        clientState.pos.y = clientState.pos.y + 1
    end
    if love.keyboard.isDown('w') then
        clientState.pos.y = clientState.pos.y - 1
    end
    if love.keyboard.isDown('d') then
        clientState.pos.x = clientState.pos.x + 1
    end
    if love.keyboard.isDown('a') then
        clientState.pos.x = clientState.pos.x - 1
    end

    local updates = clientState.serialiseUpdates()
    if updates ~= '' then
        outChannel:push(updates)
    end

    local msg = inChannel:pop()
    while msg do
        if msg ~= '' then
            serverState:deserialiseUpdates(msg)
        end
        msg = inChannel:pop()
    end
end

local playerSize = 20

function love.draw()
    if not serverState.hasState then
        -- print('No state', serverState:serialiseUpdates(true, true))
        return
    end
    love.graphics.setColor(
        serverState.backgroundColour.r,
        serverState.backgroundColour.g,
        serverState.backgroundColour.b
    )
    love.graphics.rectangle('fill', 0, 0, dim.width, dim.height)
    for id, state in serverState.players:subTablePairs() do
        love.graphics.setColor(state.colour.r, state.colour.g, state.colour.b)
        love.graphics.rectangle(
            'fill',
            state.pos.x - playerSize / 2,
            state.pos.y - playerSize / 2,
            playerSize,
            playerSize
        )
    end
end
