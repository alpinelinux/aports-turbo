local smtp = require("socket.smtp")

local utils = require("utils")

local parse_email_addr = utils.parse_email_addr
local format_email_addr = utils.format_email_addr

--
-- mail class using lua socket
--
local mail = {}

function mail:initialize(conf)
    self.server = conf.mail.server
    self.domain = conf.mail.domain
    self.rcpt = {}
    self.headers =  {
        ["content-type"] = "text/plain; charset=UTF-8"
    }
    self.body = ""
    self:set_from(conf.mail.from)
end

-- set the from address
function mail:set_from(from)
    local name, email = parse_email_addr(from)
    if email then
        self.from = "<"..email..">"
        self.headers.from = format_email_addr(name, email)
    end
end

-- set the to address
function mail:set_to(to)
    local name, email = parse_email_addr(to)
    if email then
        table.insert(self.rcpt, "<"..email..">")
        self.headers.to = format_email_addr(name, email)
    end
end

-- set the subject
function mail:set_subject(subject)
    if (type(subject) == "string") then
        self.headers.subject = subject
    end
end

-- set the body
function mail:set_body(body)
    self.body = body
end

-- Send the email and return 1 if successful, otherwise return nil followed by
-- an error message.
function mail:send()
    return smtp.send {
        from = self.from,
        rcpt = self.rcpt,
        source = smtp.message({
            headers = self.headers,
            body = self.body
        }),
        server = self.server,
        domain = self.domain
    }
end

return mail
