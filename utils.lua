---------
-- General utility functions.

local M = {}

--- Returns the `value` if not nil or empty, otherwise returns the
-- `default_value`.
function M.default(value, default_value)
    if M.is_empty(value) then
        return default_value
    end
    return value
end

--- Returns true if the `value` is nil or empty string.
function M.is_empty(value)
    return value == nil or value == ''
end

return M
