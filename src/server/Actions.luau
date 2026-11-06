--[[
	Actions — запросы клиента (ClientAction). Клиент шлёт только намерения; всё проверяется
	на сервере: типы аргументов, фаза и место (модель Ride), расстояние, владение, цены,
	частота запросов.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Profile = require(Shared.Profile)

local Data = require(script.Parent.DataService)
local Monetization = require(script.Parent.Monetization)
local Cosmetics = require(script.Parent.Cosmetics)
local LiftService = require(script.Parent.LiftService)

local Actions = {}

Actions.selfTest = nil :: (() -> { string })?

local budget: { [Player]: { n: number, t: number } } = {}
local function allowed(player: Player): boolean
	local b = budget[player]
	local t = os.clock()
	if not b or t - b.t > 1 then
		budget[player] = { n = 1, t = t }
		return true
	end
	b.n += 1
	return b.n <= 30
end

local function toast(player: Player, key: string, vars: { [string]: any }?)
	Net.ServerEvent:FireClient(player, { t = "toast", key = key, vars = vars })
end

local handlers = {}

handlers.profile = function(player: Player)
	Monetization.sendProfile(player)
end

handlers.sync = function(player: Player)
	LiftService.sync(player)
	Monetization.sendProfile(player)
end

-- голос за кнопку: { t = "vote", k = 1..3 }
handlers.vote = function(player: Player, payload)
	if not LiftService.vote(player, payload.k) then
		toast(player, "vote.notNow")
	end
end

-- намерение на этаже: { t = "act", a = { t = "sit" | "press" | "gift" | "photo" } }
handlers.act = function(player: Player, payload)
	local ok, why = LiftService.act(player, payload.a)
	if not ok and (why == "far" or why == "notNow") then
		toast(player, "act." .. why)
	end
end

handlers.emote = function(player: Player, payload)
	LiftService.emote(player, payload.e)
end

handlers.buyCoins = function(player: Player, payload)
	local id = payload.id
	if type(id) ~= "string" then
		return
	end
	local d = Data.get(player)
	if not d then
		return
	end
	local ok, err = Profile.buyWithCoins(d, id)
	if ok then
		Data.changed(player)
		Profile.equip(d, id, Monetization.hasPass(player, "Vip"))
		Cosmetics.refresh(player)
		toast(player, "shop.bought", { item = "item." .. id })
	else
		toast(player, err or "shop.error")
	end
	Monetization.sendProfile(player)
end

handlers.equip = function(player: Player, payload)
	local id = payload.id
	if type(id) ~= "string" or not Catalog.get(id) then
		return
	end
	local d = Data.get(player)
	if d and Profile.equip(d, id, Monetization.hasPass(player, "Vip")) then
		Data.changed(player)
		Cosmetics.refresh(player)
	end
	Monetization.sendProfile(player)
end

handlers.pass = function(player: Player, payload)
	if type(payload.key) == "string" and Config.Passes[payload.key] then
		Monetization.promptPass(player, payload.key)
	end
end

handlers.product = function(player: Player, payload)
	local key = payload.key
	if type(key) ~= "string" or not Config.Products[key] then
		return
	end
	local item = if type(payload.item) == "string" then payload.item else nil
	Monetization.promptProduct(player, key, item)
end

-- Отладка (только Studio)
local function debugCmd(player: Player, cmd: string, arg: any): string?
	if cmd == "coins" then
		local d = Data.get(player)
		if d then
			Profile.addCoins(d, tonumber(arg) or 1000)
			Data.changed(player)
			Monetization.sendProfile(player)
			return "coins " .. d.coins
		end
	elseif cmd == "reset" then
		local d = Data.get(player)
		if d then
			local fresh = Profile.new()
			for k, v in fresh do
				(d :: any)[k] = v
			end
			Data.changed(player)
			Cosmetics.refresh(player)
			Monetization.sendProfile(player)
			return "profile reset"
		end
	elseif cmd == "selftest" then
		local fn = Actions.selfTest
		if fn then
			task.spawn(function()
				Net.ServerEvent:FireClient(player, { t = "selftest", lines = fn() })
			end)
		end
		return nil
	end
	local msg = LiftService.debug(player, cmd, if arg ~= nil then tostring(arg) else nil)
	if msg then
		return msg
	end
	return "unknown " .. tostring(cmd)
end

handlers.debug = function(player: Player, payload)
	if not RunService:IsStudio() then
		return
	end
	local msg = debugCmd(player, tostring(payload.cmd), payload.arg)
	if msg then
		toast(player, "debug.msg", { text = msg })
	end
end

function Actions.start()
	Net.ClientAction.OnServerEvent:Connect(function(player: Player, payload)
		if type(payload) ~= "table" or type(payload.t) ~= "string" then
			return
		end
		local h = handlers[payload.t]
		if not h or not allowed(player) then
			return
		end
		local ok, err = pcall(h, player, payload)
		if not ok then
			warn("[Actions]", payload.t, err)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		budget[p] = nil
	end)
	-- Studio: команды из Command Bar / Studio MCP (execute_luau) без require:
	--   workspace:SetAttribute("DebugCommand", "state")  -- state | floor <id> | next | boss |
	--     basement | bots <n> | speed <x> | auto | coins <n> | reset | selftest
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("DebugCommand"):Connect(function()
			local raw = Workspace:GetAttribute("DebugCommand")
			local player = Players:GetPlayers()[1]
			if type(raw) ~= "string" or raw == "" or not player then
				return
			end
			Workspace:SetAttribute("DebugCommand", "")
			local cmd, arg = string.match(raw, "^(%S+)%s*(.*)$")
			print("[Debug]", raw)
			local msg = debugCmd(player, cmd or raw, if arg ~= "" then arg else nil)
			if msg then
				print("[Debug]", msg)
				toast(player, "debug.msg", { text = msg })
			end
		end)
	end
end

return Actions
