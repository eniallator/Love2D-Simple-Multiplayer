function love.conf(t)
    t.console = true
end

return {
    tps = 30,
    launchServer = true,
    communication = {
        address = 'localhost',
        port = 3000
    }
}
