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

--- Escapes given `str` as a URI component (i.e. to be safe use it in URI).
function M.escape_uri(str)
    if not str then return nil end

    return tostring(str)
        :gsub('\n', '\r\n')
        :gsub('([^%w%-_.~ ])', function(ch)
                return string.format('%%%02X', string.byte(ch))
            end)
        :gsub(' ', '+')
end

--- Returns true if the `value` is nil or empty string.
function M.is_empty(value)
    return value == nil or value == ''
end

return M
