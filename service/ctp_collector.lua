local inspect = require "inspect"
local service = require "lservice2"
service.input(...)


local config = service.config

local ffi = service.ffi

local symbol = service.config.symbol or "IF2409"

local ctp = require "lctp2"
local ffi = ctp.ffi

ctp.log_set_level("LOG_DEBUG")

local server = config.server or ctp.servers.md["openctp"]
print("collector server", inspect(server))

print("service cond", service.get_cond())

local collector = ctp.new_collector(server)
    :cond( service.get_cond() )
    -- :hook(function(md, msg) service.loopback("tick") end)
    :subscribe( { symbol } )
    :start()

--

local S = {}

function service.on_idle()
    while true do 
        local tick = collector:recv(false)
        if not tick then return end
        local ts = tonumber(ctp.ctpc.ctp_date_time_to_msec(tick.ActionDay, tick.UpdateTime, tick.UpdateMillisec))

        local symbol = ffi.string(tick.InstrumentID)
        local data = {
            ts = ts,
            symbol = ffi.string(tick.InstrumentID),
            volume = tonumber(tick.Volume),
            price = tonumber(tick.LastPrice)
        }

        -- print("tick", inspect(data))

        service.send(0, "tick", data)
    end
end

function S.echo(msg)
    print("echo", msg)
    return msg
end


service.dispatch(S)