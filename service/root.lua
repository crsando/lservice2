local inspect = require "inspect"
local service = require "lservice2"

service.input(...)

local function boot()
    -- local id1 = service.spawn { source = "@service/echo.lua", config = {} }
    -- local id2 = service.spawn { source = "@service/user.lua", config = {} }
    -- local collector_id = service.spawn { source = "@service/ctp_collector.lua", config = {} }
    local trader_id = service.spawn { source = "@service/ctp_trader.lua", config = {} }

    -- print(id1, id2, trader_id)

    -- local rst = service.call(id2, "ping")
    -- print("boot, recv response", rst)

    -- local rst = service.call(id2, "ping", id1)
    -- print("boot, recv response", rst)

    print("boot ping trader")
    local rst = service.call(trader_id, "ping")
    print("ping result",rst)

    local rst = service.call(trader_id, "query_instrument")
    print("boot, recv response from trader", inspect(rst))
end

local S = {}

function S.boot()
    boot()
end

function S.tick(data)
    print("root get tick data", inspect(data))
end

service.dispatch(S)