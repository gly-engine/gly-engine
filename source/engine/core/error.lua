--! @file error.lua
--! @brief Centralised engine error handler factory.
--! @details
--! Contract for App.error(self, std, msg):
--!   return true  → quit the application
--!   return false/nil → error was handled, keep running
--! Without App.error: prints the message and quits immediately.

local function make_handler(engine, std, quit)
    local last_msg

    return function(msg)
        msg = tostring(msg)

        -- suppress identical consecutive errors (avoids hundreds of calls/s on loop errors)
        if msg == last_msg then return end
        last_msg = msg

        local handler = engine.root and engine.root.callbacks.error
        if not handler then
            print('[error] ' .. msg)
            quit()
            return
        end

        local ok, should_quit = pcall(handler, engine.root.data, std, msg)
        if not ok or should_quit == true then
            quit()
        end
    end
end

return { make_handler = make_handler }
