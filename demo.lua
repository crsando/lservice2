local inspect = require "inspect"
local service = require "lservice2"
local uv = require "luv"

local root_id = service.spawn { source = "@service/root.lua", config = {} }
local msg, sz = service.pack ( "boot" )
-- service._send_message(
--     service.pool,
--     0,
--     root_id,
--     0,
--     1,
--     msg,
--     sz
-- )

service.send(root_id, "boot")


uv.new_signal():start("sigint", function(signal)
        print("on sigint, exit")
        uv.walk(function (handle) if not handle:is_closing() then handle:close() end end)
        os.exit(1)
    end)

uv.run()