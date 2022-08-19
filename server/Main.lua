local NetworkApi = require 'server.communication.NetworkApi'
local GameLoop = require 'common.GameLoop'

return function(cfg)
    local main =
        GameLoop(
        NetworkApi(
            {
                backgroundColour = {
                    r = 0.2,
                    g = 0.3,
                    b = 0.4
                }
            }
        ),
        cfg
    )

    local function setPlayerTable(localState, connections)
        if connections ~= nil then
            localState.players = {}
            for id, connection in connections.subTablePairs() do
                localState.players[id] = connection.state
            end
        end
    end

    function main:updateTick(localState, connections)
        -- All server-side game logic happening here
        setPlayerTable(localState, connections)
        localState.backgroundColour.r = (localState.backgroundColour.r + 0.05) % 1
    end

    return main
end
