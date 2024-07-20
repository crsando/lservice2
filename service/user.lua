local service = require "lservice2"

service.input(...)

local S = {}

function S.ping(id)
    print("pool", service.pool)

    if id then 
        service.call(id, "PONG")
    end

    print("PONG")
    return "PONG"
end

service.dispatch(S)