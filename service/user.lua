local service = require "lservice2"

service.input(...)

local S = {}

function S.ping()
    print("pool", service.pool)
    print("PONG")
    return "PONG"
end

service.dispatch(S)