--[[
	Прогон сервера на заглушке движка (каркас).
	Запуск (после rojo build): lune run tests/engine/server_sim.luau build/game.rbxl
]]

local process = require("@lune/process")
local task = require("@lune/task")
local Sim = require("./Sim")

local failures = {}
local function check(cond, msg)
	print((if cond then "  ✓ " else "  ✗ ") .. msg)
	if not cond then
		table.insert(failures, msg)
	end
end

local game = Sim.loadPlace(process.args[1] or "build/game.rbxl")
local ws = game:GetService("Workspace")
Sim.runScript(game:GetService("ServerScriptService").Server)
task.wait(0.1)
check(ws:GetAttribute("WorldReady") == true, "server ready")
print(string.format("\n%d failures", #failures))
process.exit(if #failures > 0 then 1 else 0)
