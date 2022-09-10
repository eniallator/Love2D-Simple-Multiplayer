local NetworkApi = require 'client.communication.NetworkApi'
local GameLoopController = require 'common.GameLoopController'

local dim = {}
dim.width, dim.height = love.graphics.getDimensions()

-- CLIENT GAME LOGIC HAPPENING ON MAIN THREAD
--   so no need to define own engine logic, since it can use Love2D's engine
return function(cfg)
    local main =
        GameLoopController(
        NetworkApi(
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
        ),
        cfg
    )

    function main:updateTick(localState, receivedState)
        -- All client-side game logic happening here
        localState.colour.r = (localState.colour.r + 0.01) % 1

        if love.keyboard.isDown('s') then
            localState.pos.y = localState.pos.y + 5
        end
        if love.keyboard.isDown('w') then
            localState.pos.y = localState.pos.y - 5
        end
        if love.keyboard.isDown('d') then
            localState.pos.x = localState.pos.x + 5
        end
        if love.keyboard.isDown('a') then
            localState.pos.x = localState.pos.x - 5
        end
    end

    function main:drawWithDt(localState, receivedState, dt)
        -- All client-side drawing happening here
        local playerSize = 20
        if receivedState == nil then
            return
        end
        love.graphics.setColor(
            receivedState.backgroundColour.r,
            receivedState.backgroundColour.g,
            receivedState.backgroundColour.b
        )
        love.graphics.rectangle('fill', 0, 0, dim.width, dim.height)

        love.graphics.setColor(localState.colour.r, localState.colour.g, localState.colour.b)
        love.graphics.rectangle(
            'fill',
            localState.pos.x - playerSize / 2,
            localState.pos.y - playerSize / 2,
            playerSize,
            playerSize
        )

        for id, state in receivedState.players:subTablePairs() do
            if id ~= self.networkApi.id then
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
    end

    return main
end
