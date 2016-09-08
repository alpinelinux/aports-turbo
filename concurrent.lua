local ioloop = require 'turbo.ioloop'

local M = {}

--- Runs function for each value concurrently with optional limit
-- of concurrent tasks.
--
-- @tparam function iterator The iterator that yields values to be passed
--   into `func`.
-- @tparam function func The function to run.
-- @tparam int limit Maximum number of tasks to run concurrently.
function M.foreach(iterator, func, limit)
    local io = ioloop.instance()
    local scheduled = 1  -- number of scheduled tasks (callbacks)

    io:add_callback(function()
        for value in iterator do
            -- Do not schedule more callbacks than the limit.
            while limit ~= nil and scheduled > limit do
                coroutine.yield()
            end

            io:add_callback(function()
                local ok, res = pcall(func, value)
                scheduled = scheduled - 1
                if not ok then error(res, 2) end
            end)

            scheduled = scheduled + 1
        end

        scheduled = scheduled - 1
    end)

    -- Close IO loop when all work is done.
    io:set_interval(250, function()
        if scheduled == 0 then
            io:close()
        end
    end)

    io:start()
end

return M
