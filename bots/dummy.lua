local service = require "lservice2"

service.input(...)


local 




local S = {}

function S.on_tick(tick)
    print("bot on tick", inspect(tick))
end

function S.on_bar(tick)
end

service.dispatch(S)