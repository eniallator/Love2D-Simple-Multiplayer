local SynchronisedTable = require 'SynchronisedTable'
local Network = require 'Network'
local isServer = true

local dim = {}
dim.width, dim.height = love.graphics.getDimensions()

local network
local clientState, serverState

function love.load()
    math.randomseed(os.time())
    network =
        Network(
        isServer,
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
end

function love.update(dt)
    local state = network:getLocalState()
    if love.keyboard.isDown('s') then
        state.pos.y = state.pos.y + 1
    end
    if love.keyboard.isDown('w') then
        state.pos.y = state.pos.y - 1
    end
    if love.keyboard.isDown('d') then
        state.pos.x = state.pos.x + 1
    end
    if love.keyboard.isDown('a') then
        state.pos.x = state.pos.x - 1
    end

    network:update()
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
