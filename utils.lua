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

--- Returns a value from (nested) table at the specified path.
--
-- @tparam table tab The table to operate on.
-- @tparam string path A dot separated sequence of fields.
-- @treturn A value of the last field specified in `path`, or `nil` if some
--   field doesn't exist in `tab`.
function M.get(tab, path)
    local res = tab
    for field in string.gmatch(path, '[^%.]+') do
        if res == nil then return nil end
        res = res[field]
    end
    return res
end

--- Formats email address as "Display Name <address@domain.tld>" or
-- "address@domain.tld" if `display_name` is empty.
function M.format_email_addr(display_name, email)
    if M.is_empty(email) then
        return nil
    elseif M.is_empty(display_name) then
        return email
    else
        return ("%s <%s>"):format(display_name, email)
    end
end

--- Returns true if the `value` is nil or empty string.
function M.is_empty(value)
    return value == nil or value == ''
end

--- Returns true if the given `str` looks like a valid email address.
-- Note: This is only rough validation, not RFC compliant! Proper validation of
-- email addresses is quite complex task.
function M.is_valid_email(str)
    return str and str:match('^[%w%._%+%-%%%]+@[%w%._%-]+%.%w+$') ~= nil
end

--- Parses email address in format "Display Name <address@domain.tld>" or
-- "address@domain.tld" and returns pair: display name, email. If display name
-- is not found, then the first value is nil. If nothing that looks like
-- a valid email is found, then it returns nil.
function M.parse_email_addr(addr)
    if not addr then return nil end

    local name, email = addr:match('%s*(.-)%s*<([^>]+)>')
    email = email or addr:match('%S+@%S+')

    if M.is_valid_email(email) then
        return name, email
    end
end

function M.in_table(e, t)
    for _,v in pairs(t) do
        if (v==e) then return true end
    end
    return false
end

---
-- copy table to a new table and optional filter keys
function M.copy_table(tbl, fk)
    local res = {}
    for k,v in pairs(tbl) do
        if type(fk) == "table" and not M.in_table(k, fk) then
            res[k] = v
        end
    end
    return res
end

function M.file_exists(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end

function M.split(s,d)
    local r = {}
    for i in s:gmatch(d) do table.insert(r,i) end
    return r
end

return M
