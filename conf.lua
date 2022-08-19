function love.conf(t)
    t.console = true
end

return {
    tps = 20,
    launchServer = true,
    communication = {
        address = 'localhost',
        port = 3000
    }
}
