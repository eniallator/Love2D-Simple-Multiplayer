-- Base class which is inherited from for the update tick method
return function(networkApi, cfg)
    local gameLoopController = {}

    gameLoopController.networkApi = networkApi
    gameLoopController.tickLength = 1 / cfg.tps

    gameLoopController.dtAccumulated = 0

    function gameLoopController:update(dt)
        self.dtAccumulated = self.dtAccumulated + dt
        local ticked = false
        while self.dtAccumulated > self.tickLength do
            self.dtAccumulated = self.dtAccumulated - self.tickLength
            ticked = true
            self:updateTick(self.networkApi:getLocalState(), self.networkApi:getReceivedState())
        end

        if ticked then
            self.networkApi:flushUpdates()
        end

        self.networkApi:update()
    end

    function gameLoopController:updateTick(localState, receivedState)
        error('Must define an updateTick method on the game loop sub class')
    end

    function gameLoopController:draw()
        self:drawWithDt(
            self.networkApi:getLocalState(),
            self.networkApi:getReceivedState(),
            self.dtAccumulated / self.tickLength
        )
    end

    function gameLoopController:drawWithDt(localState, receivedState, dt)
        error('Must define a draw method on the game loop sub class')
    end

    return gameLoopController
end
