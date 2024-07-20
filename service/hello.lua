local inspect = require "inspect"
local service = require "lservice2"

service.input(...)

while true do 
    local from, to, session, type, msg, sz =  service._recv_message(service.self, true) 

    local body = service.unpack_remove(msg)
    print("recv", from, to, inspect(body))
end