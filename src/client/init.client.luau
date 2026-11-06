--[[
	Клиент: HUD поездки, коллекция, магазин, надписи в мире, эффекты, мелодия лифта.
	Клиент только показывает и шлёт намерения (голос, «сесть», «нажать», «подарок», реакция);
	состояние приходит от сервера: state (вид поездки), floor (публичное табло этажа),
	события (doors, out, fx, reward, floorEnd, rideEnd, announce, cabinFx, exit, emote).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Net = require(Shared.Net)

local Ui = require(script.Ui)
local Lang = require(script.Lang)
local Hud = require(script.Hud)
local Collection = require(script.Collection)
local Shop = require(script.Shop)
local Controls = require(script.Controls)
local StageView = require(script.StageView)
local Fx = require(script.Fx)
local DebugPanel = require(script.DebugPanel)

local C = Ui.colors

while not Workspace:GetAttribute("WorldReady") do
	task.wait(0.2)
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

Ui.watchViewport()
Fx.build()
Hud.build()
Collection.build()
Shop.build()
Controls.build()
DebugPanel.build()

local function send(payload)
	Net.ClientAction:FireServer(payload)
end

Hud.onVote = function(k)
	send({ t = "vote", k = k })
	Fx.play("Click")
end
Hud.onAct = function(a)
	send({ t = "act", a = { t = a } })
	Fx.play("Click")
end
Hud.onEmote = function(e)
	send({ t = "emote", e = e })
end
Hud.onShop = Shop.toggle
Hud.onCollection = Collection.toggle
Controls.onVote = Hud.onVote
Controls.onAct = function()
	local actF = Hud.root().Hud.Actions.Act
	local b = actF.ActButton
	if actF.Visible and b.Visible then
		Hud.onAct(b:GetAttribute("Act"))
	end
end

-- Позиция в мире по координатам сцены сервера (Origin — как в World)
local ORIGIN = Vector3.new(0, 60, 0)

local function charPos(id): Vector3?
	local p = Players:GetPlayerByUserId(tonumber(id) or 0)
	local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return root.CFrame.Position
	end
	local pass = Workspace:FindFirstChild("Passengers")
	local m = pass and pass:FindFirstChild("Bot_" .. tostring(id))
	local body = m and m:FindFirstChild("Body") :: BasePart?
	return body and body.CFrame.Position
end

local handlers = {}

handlers.state = function(p)
	local prev = Hud.info.v
	Hud.setState(p)
	local ph = p.v.phase
	Fx.music(ph == "cabin")
	if prev and prev.phase ~= ph then
		if ph == "fall" then
			Controls.shake(5)
			Fx.play("Whoosh", 0.6)
		elseif ph == "lobby" and prev.phase == "fall" then
			Controls.shake(0.6)
			Fx.play("Thud")
		end
	end
end

handlers.floor = function(p)
	Hud.setFloor(p.pub)
end

handlers.profile = function(p)
	Hud.setProfile(p)
	Collection.setProfile(p)
	Shop.setProfile(p)
	if p.saved == false then
		Hud.toast(Lang.t("ui.dataOff"), C.warn)
	end
end

handlers.toast = function(p)
	Hud.toast(Lang.t(p.key, p.vars))
end

handlers.doors = function(p)
	Hud.doors(p)
	local it = Catalog.get(p.chime or "") or Catalog.get(Catalog.Default.chime)
	Fx.notes(it.notes)
end

handlers.exit = function(p)
	for _, id in p.list do
		local pos = charPos(id)
		local pl = Players:GetPlayerByUserId(tonumber(id) or 0)
		local it = Catalog.get(pl and pl:GetAttribute("Exit") or "")
		if pos and it and it.burst and it.burst > 0 then
			Fx.burst(pos, it.colors, it.burst)
		end
	end
end

handlers.out = function(p)
	local name = if p.bot then Lang.t(p.name) else p.name
	local key = "out." .. tostring(p.reason or "other")
	if Lang.t(key) == key then
		key = "out.other"
	end
	Hud.toast(Lang.t(key, { name = name }))
	Fx.play("Boing")
	local pos = ORIGIN + Vector3.new(p.x or 0, (p.y or 0) + 2, p.z or 0)
	Fx.burst(pos, { { 255, 200, 230 }, { 255, 255, 255 } }, 25)
end

local FX_TOAST = { finish = true, broken = true, pop = true, delivered = true, splat = true, meow = true }

handlers.fx = function(p)
	local e = p.e
	if FX_TOAST[e.t] then
		local who = e.id and Players:GetPlayerByUserId(tonumber(e.id) or 0)
		Hud.toast(Lang.t("fx." .. e.t, { name = who and who.DisplayName or "" }))
	end
	if e.t == "photo" then
		Fx.play("Click", 0.6)
		local pos = charPos(e.id)
		if pos then
			Fx.burst(pos + Vector3.new(0, 2, 0), { { 255, 255, 255 } }, 30)
		end
	elseif e.t == "star" or e.t == "egg" or e.t == "coin" or e.t == "sock" or e.t == "penguin" then
		if tostring(e.id) == tostring(Players.LocalPlayer.UserId) then
			Fx.notes({ if e.gold then 19 else 12 }, 0, 0.3)
		end
	elseif e.t == "press" or e.t == "sit" or e.t == "boop" then
		Fx.play("Click")
	end
end

handlers.reward = function(p)
	Hud.showReward(p)
	if p.stars >= 2 then
		Fx.notes({ 12, 16, 19 }, 0.12)
	end
end

handlers.floorEnd = function(_p) end

handlers.rideEnd = function(p)
	Hud.showRide(p.rows, nil)
	Fx.notes({ 12, 16, 19, 24 }, 0.15)
end

handlers.rideReward = function(p)
	Hud.setRideBonus(p.coins)
end

handlers.announce = function(p)
	Hud.banner("🕳", Lang.t(p.key, { name = p.name }), 3.5)
	Fx.notes({ 12, 11, 10, 9 }, 0.18)
end

handlers.cabinFx = function(p)
	Hud.toast(Lang.t("cabin." .. p.kind))
	if p.kind == "shake" then
		Controls.shake(1.2)
		Fx.play("Thud")
	elseif p.kind == "flicker" then
		Controls.flicker()
	elseif p.kind == "sneeze" then
		local cam = Workspace.CurrentCamera
		local pos = if cam
			then cam.CFrame.Position + cam.CFrame.LookVector * 6
			else ORIGIN + Vector3.new(0, 6, -8)
		Fx.burst(pos, { { 255, 90, 90 }, { 255, 220, 80 }, { 90, 200, 255 } }, 60)
	end
end

handlers.emote = function(p)
	local pos = charPos(p.id)
	if not pos then
		return
	end
	local fx = Workspace:FindFirstChild("LiftFx")
		or Ui.Make("Folder", { Name = "LiftFx", Parent = Workspace })
	local part = Ui.Make("Part", {
		Name = "Emote",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)),
		Parent = fx,
	})
	local gui =
		Ui.Make("BillboardGui", { Size = UDim2.fromOffset(60, 60), AlwaysOnTop = true, Parent = part })
	Ui.Make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		Text = p.e,
		Parent = gui,
	})
	Fx.trackEmote(part)
end

handlers.chestResult = function(p)
	Shop.showReward(p.id, Lang.t("shop.chestGot"), if p.dup then p.refund else nil)
end

handlers.directResult = function(p)
	Shop.showReward(p.id, Lang.t("shop.directGot"), nil)
end

handlers.selftest = function(p)
	for _, line in p.lines do
		print(line)
	end
	Hud.toast(p.lines[#p.lines] or "selftest")
end

Net.ServerEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local h = handlers[payload.t]
	if h then
		local ok, err = pcall(h, payload)
		if not ok then
			warn("[Client]", payload.t, err)
		end
	end
end)

Lang.onChange(StageView.refresh)

send({ t = "sync" })

RunService.RenderStepped:Connect(function(dt)
	Fx.update(dt)
	Controls.update(dt)
	Hud.update(dt)
	StageView.update(dt)
end)
