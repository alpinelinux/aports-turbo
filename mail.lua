local smtp = require("socket.smtp")

local M = {}

--
-- M.mail class using lua socket
--
M.mail = class("mail")

function M.mail:initialize()
    self.rcpt = {}
    self.from = ""
    self.headers =  { ["content-type"] = "text/plain; charset=UTF-8" }
    self.body = ""
end

--add an address to the reciepient table
function M.mail:set_rcpt(rcpt)
    local addr = validate_email(rcpt)
    if addr then
        table.insert(self.rcpt, "<"..addr..">")
    end
end

-- set the from address
function M.mail:set_from(from)
    local addr = validate_email(from)
    if addr then
        self.from = "<"..addr..">"
        self.headers.from = from
    end
end

-- set the to address
function M.mail:set_to(to)
    if validate_email(to) then
        self.headers.to = to
    end
end

-- set the cc address
function M.mail:set_cc(cc)
    if validate_email(cc) then
        self.headers.cc = cc
    end
end

-- set the subject
function M.mail:set_subject(subject)
    if (type(subject) == "string") then
        self.headers.subject = subject
    end
end

-- set the body
function M.mail:set_body(body)
    self.body = body
end

-- send the email, and if failed return the error msg
function M.mail:send()
    r, e = smtp.send{
        from = self.from,
        rcpt = self.rcpt,
        source = smtp.message({
            headers = self.headers,
            body = self.body
        }),
        server = conf.mail.server,
        domain = conf.mail.domain
    }
    if not r then
        return e
    end
end

return M.mail()