local smtp = require("socket.smtp")

--
-- mail class using lua socket
--
local mail = class("mail")

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

--add an address to the reciepient table
function mail:set_rcpt(rcpt)
    local addr = cntrl:validateEmail(rcpt)
    if addr then
        table.insert(self.rcpt, "<"..addr..">")
    end
end

-- set the from address
function mail:set_from(from)
    local addr = cntrl:validateEmail(from)
    if addr then
        self.from = "<"..addr..">"
        self.headers.from = from
    end
end

-- set the to address
function mail:set_to(to)
    if cntrl:validateEmail(to) then
        self.headers.to = to
    end
end

-- set the cc address
function mail:set_cc(cc)
    if cntrl:validateEmail(cc) then
        self.headers.cc = cc
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

-- send the email, and if failed return the error msg
function mail:send()
    r, e = smtp.send{
        from = self.from,
        rcpt = self.rcpt,
        source = smtp.message({
            headers = self.headers,
            body = self.body
        }),
        server = self.server,
        domain = self.domain
    }
    if not r then
        return e
    end
end

return mail
