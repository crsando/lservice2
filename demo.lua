package.path = package.path .. ";./?.lua;./?/init.lua"

local inspect = require "inspect"
local service = require "lservice2"
local uv = require "luv"

local pass = require "pass"

local root_id = service.spawn { source = "@service/root.lua", config = { pass = pass } }
service.send(root_id, "boot")


uv.new_signal():start("sigint", function(signal)
        print("on sigint, exit")
        uv.walk(function (handle) if not handle:is_closing() then handle:close() end end)
        os.exit(1)
    end)

uv.run()