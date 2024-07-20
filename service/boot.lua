local inspect = require "inspect"
local service = require "lservice2"

service.input(...)

local S = {}

function S.boot()
    local id1 = service.spawn { source = "@service/hello.lua", config = {} }
    local id2 = service.spawn { source = "@service/user.lua", config = {} }

    -- service.call(service.get_id(addr2), )

    local msg, sz = service.pack ( "ping", "arg1", 2 )

    local rst = service.call(id2, "ping", "arg1", 2)
    print("boot, recv response", rst)
end


service.dispatch(S)