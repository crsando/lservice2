local inspect = require "inspect"
local service = require "lservice2"

service.input(...)
local config = service.config

local function slice(t, k)
    local o = {}
    for i, e in ipairs(t) do 
        o[i] = e[k]
    end
    return o
end

local function filter_instruments(lst)
    local R = {}
    for _, symbol in ipairs(lst) do 
        if #symbol == 6 and string.sub(symbol, 1, 2) == "cu" then 
            table.insert(R, symbol)
        end
    end
    return R
end

local bots = {
    trader_1 = nil,
    trader_2 = nil,
}

local function boot()
    -- local id1 = service.spawn { source = "@service/echo.lua", config = {} }
    -- local id2 = service.spawn { source = "@service/user.lua", config = {} }
    -- local collector_id = service.spawn { source = "@service/ctp_collector.lua", config = {} }
    bots.trader_1 = service.spawn { source = "@service/ctp_trader.lua", config = { account = config.accounts.trader["gtja-1"] } }
    bots.trader_2 = service.spawn { source = "@service/ctp_trader.lua", config = { account = config.accounts.trader["gtja-2"] } }

    -- print(id1, id2, trader_id)

    -- local rst = service.call(id2, "ping")
    -- print("boot, recv response", rst)

    -- local rst = service.call(id2, "ping", id1)
    -- print("boot, recv response", rst)

    -- local rst = service.call(trader_id, "ping")
    -- print("ping result",rst)

    -- local rst = service.call(trader_id, "start")
    -- assert(rst == true)

    -- local rst = service.call(trader_id, "query_instrument")
    -- local sub_lst = filter_instruments(slice(rst, "InstrumentID"))
    -- print(inspect(sub_lst))

    -- --
    -- local symbols = { "IF2409" }
    -- local rst = assert(service.call(collector_id, "start", symbols))

    local rst = service.call(bots.trader_1, "query_position")
    for _, pos in ipairs(rst) do 
        print(pos.InvestorID, pos.InstrumentID, pos.Position, pos.PosiDirection - 49)
    end
    local rst = service.call(bots.trader_2, "query_position")
    for _, pos in ipairs(rst) do 
        print(pos.InvestorID, pos.InstrumentID, pos.Position, pos.PosiDirection - 49)
    end

    service.send(0, "total_account")

    -- -- local rst = service.call(trader_id, "query_instrument")
    -- -- print("boot, recv response from trader", inspect(rst))

    --  service.call(trader_id, "quit")
end

local S = {}

function S.boot()
    boot()
end

function S.total_account()
    local info1 = service.call(bots.trader_1, "query_account")
    local info2 = service.call(bots.trader_2, "query_account") 

    print("account", info1.Balance, info2.Balance)
end

function S.tick(data)
    print("root get tick data", inspect(data))
end

function S.notify(from, info)
    print("root get notified from ", from, "with msg: ", info)
end

service.dispatch(S)