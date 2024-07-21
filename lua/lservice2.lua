local service = require "lservice2_c"
local inspect = require "inspect"

--[[
    common conventions:

    addr: lightuserdata of service_t (actually, pointer)
    from, to : service_id (integer)
]]

-- constants

local MESSAGE_SYSTEM = 0
local MESSAGE_REQUEST = 1
local MESSAGE_RESPONSE = 2
local MESSAGE_ERROR = 3
local MESSAGE_SIGNAL = 4

local MESSAGE_RECEIPT_NONE = 0
local MESSAGE_RECEIPT_DONE = 1
local MESSAGE_RECEIPT_ERROR = 2
local MESSAGE_RECEIPT_BLOCK = 3
local MESSAGE_RECEIPT_RESPONCE = 4


-- preserved internal parameters
service.self = nil -- the current running service
service.pool = nil
service.config = nil

local yield_session = coroutine.yield

-- basic apis

function service.new(t)
    if not service.pool then 
        if t.pool then 
            service.pool = t.pool
        else 
            print("create new pool")
            service.pool = service._pool_new()
        end
    end

    assert(t.source, "source not provided")
    local code = nil
    if string.sub(t.source, 1, 1) == "@" then 
        code = assert(io.open(string.sub(t.source, 2, -1)):read("*all"), "service code path not found")
    else 
        code = t.source
    end

    config = nil
    if t.config and (type(t.config) == "table") then 
        config = service.pack(t.config)
    else 
        config = t.config
    end

    local addr = service._new(t.pool or service.pool, t.name, code, config)
    -- setmetatable(s, { __index = service })
    return addr
end

function service.start(addr)
    return service._start(addr)
end

function service.spawn(t)
    local addr = service.new(t)
    service.start(addr)
    return service.get_id(addr) 
end

-- get current service_id or get_id by addr
local CURRENT_SERVICE_ID = nil
function service.get_id(addr)
    if service.self == nil then return 0 end
    if not addr then 
        CURRENT_SERVICE_ID = CURRENT_SERVICE_ID or service._get_id(service.self)
        return CURRENT_SERVICE_ID
    else 
        return service._get_id(addr)
    end
end

function service.get_cond(addr) 
    if service.self == nil then return nil end
    addr = addr or service.self
    return service._get_cond(addr)
end

function service.get_pool(addr) 
    if service.self == nil then return nil end
    addr = addr or service.self
    return service._get_pool(addr)
end

function service.input(s, config)
    print("service.input", s, config)
    if s then
        service.self = s
        service.pool = service.get_pool(s)
        service.config = service.unpack_remove(config)
        print("service", service.get_id(), "with config", inspect(service.config) )
    else 
        print("No input, running in standalone mode")
        service.self = nil
        service.pool = nil
        service.config = {}
    end
    print("service.input end", s, config)
end

function service.send_message(to, session, type, msg, sz)
    local from = service.get_id()
    service._send_message(from, to, session, type, msg, sz)
    -- coroutine.yield()
    -- <TODO> add receipt logic
end

function service.recv_message(blocking)
    assert(service.self, "no self state provided")
    blocking = blocking or true
    return service._recv_message(service.self, blocking)
end

--
-- session (mostly copyed and modified from ltask)
-- 
local running_thread

local session_coroutine_suspend_lookup = {}
local session_coroutine_where = {}
local session_coroutine_suspend = {}
local session_coroutine_response = {}
local session_coroutine_address = {}
local session_id = 1

local session_waiting = {}
local wakeup_queue = {}

local function resume_session(co, ...)
	running_thread = co
	local ok, errobj = coroutine.resume(co, ...)
	running_thread = nil
	if ok then
		return errobj
	end
    session_coroutine_address[co] = nil
    session_coroutine_response[co] = nil
end

service.resume_session = resume_session

local coroutine_pool = setmetatable({}, { __mode = "kv" })

-- Mingda Qiu
-- 原始的new_thread没看懂, 尝试换一个写法试试
local function new_thread(f)
    local co = coroutine.create(function (...)
            -- print(">>> coroutine begin", f, inspect{...})
            local ok, err = pcall(f, ...)
            if not ok then print("ERROR", err) end
            -- print(">>> coroutine end")
        end)
    
    table.insert(coroutine_pool, co)

	return co
end

local function new_session(f, from, session)
    print("new_session", f, from, session)
	local co = new_thread(f)
	session_coroutine_address[co] = from
	session_coroutine_response[co] = session
	return co
end

local function send_response(...)
	local session = session_coroutine_response[running_thread]
    -- print("send_response", session, inspect{...})

	if session > 0 then
		local from = session_coroutine_address[running_thread]
		service._send_message(service.pool, service.get_id(), from, session, MESSAGE_RESPONSE, service.pack(...))
	end

	-- End session
	session_coroutine_address[running_thread] = nil
	session_coroutine_response[running_thread] = nil
end

-- api

-- local function dispatch_wakeup()
--     print("dispatch_wakeup", inspect(wakeup_queue))
-- 	while #wakeup_queue > 0 do
-- 		local s = table.remove(wakeup_queue, 1)
-- 		resume_session(unpack(s))
-- 	end
-- end

-- function service.fork(func, ...)
-- 	local co = new_thread(func)
-- 	wakeup_queue[#wakeup_queue+1] = {co, ...}
-- end


function service.send(id, ...)
    return service._send_message(
        service.pool,
        service.get_id(), -- from
        id,  -- to
        0,  --session_id = 0
        MESSAGE_REQUEST, 
        service.pack(...)
    )
end

function service.loopback(...)
    return service.send(service.get_id(), ...)
end

function service.call(id, ...)
    print("begin service.call:", id, session_id + 1)
    service._send_message(
        service.pool,
        service.get_id(), -- from
        id,  -- to
        session_id,
        MESSAGE_REQUEST, 
        service.pack(...)
    )

	session_coroutine_suspend_lookup[session_id] = running_thread
	session_id = session_id + 1

    print("begin service.call yield_session:", id)
	local type, session, msg, sz = yield_session()
    print("service.call get response from")
	if type == MESSAGE_RESPONSE then
		return service.unpack_remove(msg, sz)
	else
		-- type == MESSAGE_ERROR
		rethrow_error(2, service.unpack_remove(msg, sz))
	end
end

function service.get_session()
    return running_thread
end


function service.dispatch(request_handler)
    -- if in standalone mode
    if not service.self then return nil end

    local function request(command, ...)
        -- print("Begin request", inspect(command))
        local s = request_handler[command]
        if not s then
            error("Unknown request message : " .. command)
            return
        end
        send_response(s(...))
        -- print("End request", command)
    end

    -- main loop
	while true do
        local from, to, session, type, msg, sz = service.recv_message(true) -- blocking
        -- print("recv_message", from, to, session, type, msg, sz)
        -- if a request is received
        if type == MESSAGE_REQUEST then 
            local co = new_session(function (type, msg, sz)
                    request(service.unpack_remove(msg, sz))
                end, from, session)
            print("resume_session", resume_session(co, type, msg, sz))
        -- on response, resume the previous session
        elseif session then
            -- print("suspend", inspect(session_coroutine_suspend_lookup))
            local co = session_coroutine_suspend_lookup[session]
            if co == nil then
                print("Unknown response session : ", session)
                service.remove(msg, sz)
                -- not implemented yet
                -- service.quit()
            else
                session_coroutine_suspend_lookup[session] = nil
                resume_session(co, type, session, msg, sz)
            end
        else
            -- on idle, do nothing here
            -- print("on_idle")
            if service.on_idle then 
                service.on_idle() -- attention, this is not a coroutine
            end
        end

        -- dispatch_wakeup()
        if quit then
            -- do something cleaning here

            -- break the while mainloop, hence effectively end the thread
            break
        end
	end -- end while
end -- end function

return service