local SynchronisedTable = require 'SynchronisedTable'
local Network = require 'Network'
local isServer = true

local dim = {}
dim.width, dim.height = love.graphics.getDimensions()

local network
local clientState, serverState

function love.load()
    math.randomseed(os.time())
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
    network = Network(isServer, clientState:serialiseUpdates())
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

    local updates = clientState:serialiseUpdates()
    if updates ~= '' then
        network:send(updates)
    end

    network:receiveState()
end

local playerSize = 20

function love.draw()
    local serverState = network:getReceivedState()
    if serverState == nil then
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
