local inspect = require "inspect"
local service = require "lservice2"

local S = {}

function S.boot()
    local addr1 = service.spawn { source = "@service/hello.lua", config = {} }
    local addr2 = service.spawn { source = "@service/user.lua", config = {} }

    service.call(service.get_id(addr2), )

    local msg, sz = service.pack ( "ping", "arg1", 2 )

    service._send_message(
        service.pool,
        service.get_id(), -- from
        service.get_id(addr2), -- to
        1,
        MESSAGE_REQUEST,
        msg,
        sz
    )

end


service.dispatch(S)