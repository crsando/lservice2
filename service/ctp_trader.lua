local inspect = require "inspect"
local service = require "lservice2"
service.input(...)
local config = service.config

local R = {} -- handle trader response
local S = {} -- handle service request/response

local ctp = require "lctp2"
local ffi = ctp.ffi

ctp.log_set_level("LOG_DEBUG")

local server = ctp.servers.trader["openctp-7x24"] 

server.pass = assert(server.pass or config.pass)

local trader = ctp.new_trader(server)
    :cond( service.get_cond() )
    :start( true )

local internal_suspend_lookup = {}

local rsp_cache = {}

local function collect_rsp(rsp)
    local req_id = tonumber(rsp.req_id)
    if not req_id then return nil end
    local T = rsp_cache[req_id]

    if T then 
        T[#T+1] = rsp
    end

    if rsp.is_last == true then 
        local co = internal_suspend_lookup[rsp.req_id]
        -- print("is_last hit for req_id:", req_id, "resume_session", co)
        if co then 
            service.resume_session(co, T)
            internal_suspend_lookup[rsp.req_id] = nil
        end
    end
end

local function wait_trader_request(req_id)
    local running_thread = service.get_session()
    -- print("wait_trader_request for req_id:", req_id, "session thread", running_thread)
    internal_suspend_lookup[req_id] = running_thread
    rsp_cache[req_id] = {} -- store results
    -- print("query_instrument: on", running_thread, "req_id = ", req_id)
    local T = rsp_cache[req_id]
    while true do
        local is_last = (T[#T] or {}).is_last or false
        -- print("wait request", #T, is_last)
        if is_last then break end
        coroutine.yield()
    end
    rsp_cache[req_id] = nil
    return T
end

-- process trader internal messages
function service.on_idle()
    local i = 0
    -- print("trader on idle")
    while true do 
        i = i + 1
        -- print("idle loop ", i)
        local rsp = trader:recv(false) -- non-blocking
        if rsp == nil then break end
        local func_name = ffi.string(rsp.func_name)
        local handler = R[func_name] or collect_rsp

        -- print("handle message", func_name)

        if handler then 
            handler {
                req_id = tonumber(rsp.req_id),
                field = ctp.totable(ffi.cast( "struct " .. ffi.string(rsp.field_name) .. " *", rsp.field)),
                field_name = ffi.string(rsp.field_name),
                func_name = ffi.string(rsp.func_name),
                is_last = rsp.is_last,
            }
        end
    end -- end while
    -- print("trader exit idle")
end

-- trader logic

-- 

-- service request / response

function S.ping()
    print("PONG")
    return "PONG"
end

function S.query_account()
    local req_id = trader:query_account()
    local rst = wait_trader_request(req_id)
    print("query_account, rst", inspect(rst))
    print("query_account, avail", rst[1].field.Available)
    return rst[1].field.Available
end

function S.query_instrument(exchange_id)
    local running_thread = service.get_session()
    -- print("begin query instrument", running_thread)
    -- assert(type(exchange_id) == "string")
    local T = wait_trader_request(trader:query_instrument("SHFE"))

    -- print("query_instrument", inspect(T))
    local rst = {}
    for _, e in ipairs(T) do 
        table.insert(rst, e.field)
    end
    return rst
end

function S.start()
    return true
end

function S.quit()
    print("trader is quitting")
    service.call(0, "notify", service.get_id(), "quit")
    service.quit()
end

service.dispatch(S)