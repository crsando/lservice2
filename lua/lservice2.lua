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
    return addr 
end

-- get current service_id or get_id by addr
function service.get_id(addr)
    addr = addr or service.self
    return service._get_id(addr)
end

function service.input(s, config)
    service.self = s
    service.config = service.unpack_remove(config)

    print("service", service.get_id(), "with config", inspect(service.config) )
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

local coroutine_pool = setmetatable({}, { __mode = "kv" })

-- Mingda Qiu
-- 原始的new_thread没看懂, 尝试换一个写法试试
local function new_thread(f)
    local co = coroutine.create(function (...)
            print(">>> coroutine begin", f, inspect{...})
            local ok, err = pcall(f, ...)
            if not ok then print("ERROR", err) end
            print(">>> coroutine end")
        end)
    
    table.insert(coroutine_pool, co)

	return co
end

local function new_session(f, from, session)
	local co = new_thread(f)
	session_coroutine_address[co] = from
	session_coroutine_response[co] = session
	return co
end

local function send_response(...)
	local session = session_coroutine_response[running_thread]

	if session > 0 then
		local from = session_coroutine_address[running_thread]
		service.send_message(from, session, MESSAGE_RESPONSE, service.pack(...))
	end

	-- End session
	session_coroutine_address[running_thread] = nil
	session_coroutine_response[running_thread] = nil
end

-- api

local function dispatch_wakeup()
    print("dispatch_wakeup")
	while #wakeup_queue > 0 do
		local s = table.remove(wakeup_queue, 1)
		resume_session(unpack(s))
	end
end

-- function service.fork(func, ...)
-- 	local co = new_thread(func)
-- 	wakeup_queue[#wakeup_queue+1] = {co, ...}
-- end

function service.call(id, ...)
	service._send_message(
        service.get_id(),
        id, 
        session_id, 
        MESSAGE_REQUEST, 
        ltask.pack(...)
    ) 

	session_coroutine_suspend_lookup[session_id] = running_thread
	session_id = session_id + 1

	local type, session, msg, sz = yield_session()
	if type == MESSAGE_RESPONSE then
		return ltask.unpack_remove(msg, sz)
	else
		-- type == MESSAGE_ERROR
		rethrow_error(2, ltask.unpack_remove(msg, sz))
	end
end


function service.dispatch(request_handler)
    local function request(command, ...)
        print("Begin request", inspect(command))
        local s = request_handler[command]
        if not s then
            error("Unknown request message : " .. command)
            return
        end
        send_response(s(...))
        print("End request", command)
    end

    -- main loop
	while true do
        local from, to, session, type, msg, sz = service.recv_message(true) -- blocking
        print("recv_message", from, to, session, type, msg, sz)
        -- if a request is received
        if type == MESSAGE_REQUEST then 
            local co = new_session(function (type, msg, sz)
                    request(service.unpack_remove(msg, sz))
                end, from, session)
            print(resume_session(co, type, msg, sz))
        -- on response, resume the previous session
        elseif session then
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
        end
        dispatch_wakeup()
        if quit then
            -- do something cleaning here

            -- break the while mainloop, hence effectively end the thread
            break
        end
	end -- end while
end -- end function

return service