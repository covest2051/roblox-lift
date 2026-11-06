--[[
	SelfTest — проверки внутри движка (в Studio при старте и кнопкой DBG / командой selftest).
	Пишет в Output строки [SELFTEST] PASS/WARN/FAIL и итог RESULT.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Floors = require(Shared.Floors)
local Bots = require(Shared.Bots)

local LiftService = require(script.Parent.LiftService)

local SelfTest = {}

function SelfTest.run(): { string }
	local lines = {}
	local pass, warns, total = 0, 0, 0
	local function check(name: string, fn: () -> (boolean | string, string?))
		total += 1
		local ok, res, detail = pcall(fn)
		local line
		if not ok then
			line = "[SELFTEST] FAIL " .. name .. ": " .. tostring(res)
		elseif res == true then
			pass += 1
			line = "[SELFTEST] PASS " .. name .. (if detail then " (" .. detail .. ")" else "")
		elseif res == "warn" then
			pass += 1
			warns += 1
			line = "[SELFTEST] WARN " .. name .. (if detail then ": " .. detail else "")
		else
			line = "[SELFTEST] FAIL " .. name .. (if detail then ": " .. detail else "")
		end
		print(line)
		table.insert(lines, line)
	end

	local ride = LiftService.ride()
	local p1 = Players:GetPlayers()[1]

	check("streaming off, characters spawn after the world", function()
		return Workspace.StreamingEnabled == false and Players.CharacterAutoLoads == false
	end)

	check("cabin, doors, display and balcony built", function()
		local lift = Workspace:FindFirstChild("Lift")
		return lift ~= nil
			and lift:FindFirstChild("DoorL") ~= nil
			and lift:FindFirstChild("Display") ~= nil
			and lift:FindFirstChild("Balcony") ~= nil,
			lift and (#lift:GetDescendants() .. " instances") or "no Lift model"
	end)

	check("stage built from primitives", function()
		local st = Workspace:FindFirstChild("Stage")
		if not st then
			return "warn", "no stage yet (phase " .. tostring(ride and ride.phase) .. ")"
		end
		return #st:GetChildren() > 3, st:GetAttribute("Floor") .. ": " .. #st:GetChildren() .. " parts"
	end)

	check("ride runs on server time", function()
		if not ride or ride.phase == "idle" then
			return "warn", "no players — the lift is idle"
		end
		return true, string.format("ride %d, phase %s, stop %d", ride.rideNo, ride.phase, ride.stop)
	end)

	check("every floor builds and steps (1 and 12 players)", function()
		local bad = {}
		for _, id in Floors.Order do
			for _, n in { 1, 12 } do
				local roster = {}
				for i = 1, n do
					roster[i] = { id = i, name = "b" .. i, bot = true }
				end
				local ok = pcall(function()
					local inst = Floors.new(id, { seed = 3, roster = roster })
					local mems = {}
					for i = 1, n do
						mems[i] = Bots.mem("medium", i)
					end
					for _ = 1, 40 do
						for i, p in inst.list do
							Floors.botStep(inst, p, mems[i], 0.1)
						end
						Floors.step(inst, 0.1)
					end
				end)
				if not ok then
					table.insert(bad, id .. "@" .. n)
				end
			end
		end
		return #bad == 0, if #bad > 0 then table.concat(bad, ", ") else #Floors.Order .. " floors"
	end)

	check("player in the lift", function()
		if not p1 or not ride then
			return "warn", "no players"
		end
		local P = ride.people[p1.UserId]
		return P ~= nil, P and ("where=" .. P.where) or "not joined"
	end)

	check("products configured", function()
		local missing = {}
		for _, k in Config.ProductOrder do
			if Config.Products[k].id == 0 then
				table.insert(missing, k)
			end
		end
		for _, k in Config.PassOrder do
			if Config.Passes[k].id == 0 then
				table.insert(missing, k)
			end
		end
		for k, id in Config.Badges do
			if id == 0 then
				table.insert(missing, "Badge:" .. k)
			end
		end
		if #missing > 0 then
			return "warn", "ID = 0 (emulated in Studio): " .. table.concat(missing, ", ")
		end
		return true
	end)

	check("player data saves", function()
		if not p1 then
			return "warn", "no players"
		end
		if p1:GetAttribute("DataSaved") ~= true then
			return "warn",
				"DataStore off: Game Settings → Security → Enable Studio Access to API Services"
		end
		return true
	end)

	check("PolicyService answers", function()
		if not p1 then
			return "warn", "no players"
		end
		local info = PolicyService:GetPolicyInfoForPlayerAsync(p1)
		return true, "ArePaidRandomItemsRestricted=" .. tostring(info.ArePaidRandomItemsRestricted)
	end)

	local result = string.format("[SELFTEST] RESULT %d/%d passed, %d warnings", pass, total, warns)
	print(result)
	table.insert(lines, result)
	return lines
end

return SelfTest
