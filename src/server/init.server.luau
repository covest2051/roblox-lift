--[[
	Точка входа сервера: сервисы, мир, лифт (LiftService над моделью Ride), затем игроки.
	Логика идёт фиксированным шагом по GetServerTimeNow (не task.delay).
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.DataService)
local Monetization = require(script.Monetization)
local Cosmetics = require(script.Cosmetics)
local World = require(script.World)
local LiftService = require(script.LiftService)
local Actions = require(script.Actions)
local SelfTest = require(script.SelfTest)

-- данные и покупки — сразу: ProcessReceipt должен быть назначен как можно раньше
DataService.start()
Monetization.start()
Cosmetics.start()
LiftService.boot()
Actions.selfTest = SelfTest.run
Actions.start()

-- бейджи: ID вписать в Config.Badges (0 — не выдаются)
LiftService.badge = function(player: Player, key: string)
	local id = Config.Badges[key]
	if not id or id == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, id) then
				BadgeService:AwardBadge(player.UserId, id)
			end
		end)
	end)
end

local t0 = os.clock()
World.lighting()
World.build()
Workspace:SetAttribute("WorldReady", true)
print(string.format("[World] ready in %.2fs", os.clock() - t0))

-- шаг логики
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= Config.Ride.Step * 0.5 then
		acc = 0
		local ok, err = pcall(LiftService.step)
		if not ok then
			warn("[Lift] step error:", err)
		end
	end
end)

local function setupCharacter(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			task.wait(2)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end
	LiftService.onCharacter(player)
end

-- персонаж появляется, когда мир построен (CharacterAutoLoads = false)
local function arrive(player: Player)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	LiftService.join(player)
	player:LoadCharacter()
end
Players.PlayerAdded:Connect(arrive)
Players.PlayerRemoving:Connect(LiftService.leave)
for _, p in Players:GetPlayers() do
	task.spawn(arrive, p)
end

if RunService:IsStudio() then
	task.delay(6, SelfTest.run)
end
