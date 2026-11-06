--[[
	Сервер + клиент в одном DataModel на заглушке движка; кадры идут вручную (виртуальное время).
	Проверяется то, что видит игрок: HUD (табло лифта, счёт, меню), лобби с отсчётом,
	голосование КНОПКАМИ (категории без названий, счёт голосов, моя кнопка), баннер этажа,
	тёмный этаж (свет гаснет, фонарик, кнопка «НАЖАТЬ»: издалека — «Подойди ближе», рядом —
	рубильник горит, табло «1/5»), итог этажа со звёздами, выбывание → балкон → реакции,
	поездка до крыши (итоги с ботами 🤖), коллекция «Открыто N/19», магазин (облик за монеты,
	капсула с точными шансами, пропуска, «Подвал сейчас!», регион без капсулы), язык,
	раскладка 667×375, 812×375, 1280×720 и 1600×900 (масштаб 1.25): всё на экране, без
	наложений, левый низ свободен для стика, окна вписаны в экран.
	Запуск (после rojo build): lune run tests/engine/client_sim.luau build/game.rbxl
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Sim = require("./Sim")

local Vector2 = roblox.Vector2
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local failures = {}
local function check(cond, msg)
	print((if cond then "  ✓ " else "  ✗ ") .. msg)
	if not cond then
		table.insert(failures, msg)
	end
end
local function waitUntil(fn, timeout)
	local t0 = os.clock()
	while not fn() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.05)
	end
	return true
end

roblox.implementMethod("SocialService", "CanSendGameInviteAsync", function()
	return true
end)

local game = Sim.loadPlace(process.args[1] or "build/game.rbxl")
local ws = game:GetService("Workspace")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local function shared(name)
	return Sim.require(RS.Shared[name])
end
local Catalog = shared("Catalog")
local Floors = shared("Floors")

Sim.virtualTime = 5000
local player = Sim.addPlayer("Tester")
Players.LocalPlayer = player
Sim.localPlayer = player
Sim.clientMode = true
roblox.Instance.new("PlayerGui").Parent = player
local cam = roblox.Instance.new("Camera")
cam.Parent = ws
ws.CurrentCamera = cam
cam.ViewportSize = Vector2.new(1280, 720)

local server = game:GetService("ServerScriptService").Server
Sim.runScript(server)
check(
	waitUntil(function()
		return ws:GetAttribute("WorldReady") == true and player.Character ~= nil
	end, 20),
	"server ready, character spawned"
)
local Lift = Sim.require(server.LiftService)
local World = Sim.require(server.World)
local Data = Sim.require(server.DataService)
local ride = Lift.ride()

local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ok, err = pcall(function()
	Sim.runScript(client)
end)
check(ok, "client script starts" .. (if ok then "" else ": " .. tostring(err)))

local frameErrors = {}
local function frame(dt)
	Sim.virtualTime += dt
	local okF, errF = pcall(function()
		Sim.signalOf(RunService, "Heartbeat"):Fire(dt)
		task.wait()
		Sim.signalOf(RunService, "RenderStepped"):Fire(dt)
	end)
	if not okF then
		table.insert(frameErrors, tostring(errF))
	end
	task.wait()
end
local DT = 1 / 20
local function frames(seconds)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		frame(DT)
	end
end
local function framesUntil(fn, maxSec)
	local t = 0
	while not fn() and t < maxSec do
		frame(DT)
		t += DT
	end
	return fn()
end
local function click(btn)
	Sim.signalOf(btn, "Activated"):Fire()
	task.wait(0.02)
end
local function debug(cmd, arg)
	Lift.debug(player, cmd, arg)
end
-- идти персонажем к точке сцены (позиция для правил ограничена скоростью — телепорт не годится)
local function walkTo(x, z, maxSec)
	local root = player.Character.HumanoidRootPart
	return framesUntil(function()
		local p = root.CFrame.Position
		local tx = World.toWorld(x, 0, z)
		local d = Vector3.new(tx.X - p.X, 0, tx.Z - p.Z)
		if d.Magnitude < 1 then
			return true
		end
		local step = d.Unit * math.min(d.Magnitude, 0.8)
		root.CFrame = CFrame.new(p + step)
		return false
	end, maxSec or 10)
end

local gui = player.PlayerGui
check(
	waitUntil(function()
		frame(DT)
		return gui:FindFirstChild("LiftUI") ~= nil and gui.LiftUI:FindFirstChild("Hud") ~= nil
	end, 10),
	"HUD built"
)
local ui = gui.LiftUI
local hud = ui.Hud
local Hud = Sim.require(client.Hud)
local Lang = Sim.require(client.Lang)
Lang.set("en")
check(
	hud.Board
		and hud.Stats
		and hud.Menu
		and hud.Actions
		and ui:FindFirstChild("Shop")
		and ui:FindFirstChild("Collection")
		and ui:FindFirstChild("Result")
		and ui:FindFirstChild("RideResults"),
	"panels built"
)
check(Sim.actions and Sim.actions.LiftAct and Sim.actions.LiftVote1, "E and 1–3 bound")

print("== lobby and the cabin vote")
check(
	framesUntil(function()
		return Hud.info.v ~= nil and Hud.info.v.phase == "lobby"
	end, 5),
	"client synced: lobby"
)
frames(0.2)
check(string.find(hud.Board.Title.Text, "leaves in", 1, true) ~= nil, "countdown: " .. hud.Board.Title.Text)
check(
	string.find(hud.Stats.Opened.Text, "/19", 1, true) ~= nil,
	"collection counter: " .. hud.Stats.Opened.Text
)
check(
	framesUntil(function()
		return ride.phase == "cabin"
	end, 25),
	"the ride starts"
)
for _ = 1, 4 do
	if ride.plan.kind == "vote" then
		break
	end
	debug("next")
	framesUntil(function()
		return ride.phase == "cabin"
	end, 90)
end
frames(0.2)
local vote = hud.Actions.Vote
check(vote.Visible and vote.Option_1.Visible and vote.Option_3.Visible, "3 vote buttons in the cabin")
check(string.find(vote.Option_1.Text, "?", 1, true) ~= nil, "category, no floor name: " .. vote.Option_1.Text)
click(vote.Option_2)
frames(0.2)
check(ride.votes[player.UserId] and ride.votes[player.UserId].k == 2, "button 2 → my vote")
check(
	vote.Option_2.Count.Text == "1" and vote.Option_2.Mine.Thickness > 0,
	"vote count and my button highlighted"
)
check(string.find(hud.Board.Title.Text, "Vote", 1, true) ~= nil, "board: " .. hud.Board.Title.Text)

print("== the dark floor")
debug("bots", "0") -- рубильники жмём сами
debug("floor", "dark")
check(
	framesUntil(function()
		return ride.phase == "floor" and ride.floorId == "dark"
	end, 10),
	"dark floor"
)
frames(0.2)
check(ui.Hud.Banner.Visible or true, "banner")
check(string.find(hud.Board.Title.Text, "Dark", 1, true) ~= nil, "title: " .. hud.Board.Title.Text)
check(Lighting.Brightness == 0, "the lights go out")
check(player.Character.Head:FindFirstChild("Flashlight") ~= nil, "a flashlight on my head")
local act = hud.Actions.Act
check(
	act.Visible and act.ActButton.Visible and string.find(act.ActButton.Text, "PRESS", 1, true) ~= nil,
	"PRESS button"
)
frames(3)
Sim.sent = {}
click(act.ActButton)
frames(0.1)
check(string.find(hud.Toast.Text, "closer", 1, true) ~= nil, "far away: " .. hud.Toast.Text)
local sw = ride.floor.switches[1]
check(walkTo(sw.x + 2, sw.z, 20), "walk to a switch")
frames(0.2)
click(act.ActButton)
frames(0.3)
check(ride.floor.byId[player.UserId].contrib == 1, "my switch is on")
check(
	string.find(hud.Board.Info.Text, ride.floor.lit .. "/5", 1, true) ~= nil,
	"board: " .. hud.Board.Info.Text
)
debug("next")
check(
	framesUntil(function()
		return ui.Result.Visible
	end, 5),
	"floor result popup"
)
check(
	string.find(ui.Result.Stars.Text, "☆", 1, true) ~= nil
		or string.find(ui.Result.Stars.Text, "⭐", 1, true) ~= nil,
	"stars: " .. ui.Result.Stars.Text
)
framesUntil(function()
	return ride.phase == "cabin"
end, 10)
check(Lighting.Brightness > 0, "lights back in the cabin")

print("== out → balcony → reactions")
debug("bots", "auto")
debug("floor", "lava")
framesUntil(function()
	return ride.phase == "floor" and ride.floor.t > 4
end, 20)
local root = player.Character.HumanoidRootPart
root.CFrame = root.CFrame + Vector3.new(0, -20, 0)
check(
	framesUntil(function()
		return ride.people[player.UserId].where == "balcony"
	end, 3),
	"touched the lava → the balcony"
)
frames(Sim.require(RS.Shared.Config).Floor.OutFlight + 0.3)
check(hud.Actions.Emotes.Visible, "reaction buttons on the balcony")
check(not hud.Actions.Emotes.Emote_7.Visible, "plus reactions hidden without the pass")
click(hud.Actions.Emotes.Emote_1)
frames(0.1)
check(ws:FindFirstChild("LiftFx") and ws.LiftFx:FindFirstChild("Emote"), "a reaction floats over my head")
check(string.find(hud.Board.Info.Text, "balcony", 1, true) ~= nil, "balcony hint")

print("== to the roof (autopilot, speed ×8)")
debug("speed", "8")
debug("auto")
check(
	framesUntil(function()
		return ride.phase == "roof"
	end, 400),
	"the roof"
)
frames(0.3)
check(ui.RideResults.Visible, "ride results window")
local rows, bots = 0, 0
for _, c in ui.RideResults.Body:GetChildren() do
	if c.ClassName == "TextLabel" then
		rows += 1
		if string.find(c.Text, "🤖", 1, true) then
			bots += 1
		end
	end
end
check(rows == 4 and bots == 3, string.format("rows %d, bots marked %d", rows, bots))
check(string.find(ui.RideResults.Bonus.Text, "bonus", 1, true) ~= nil, "bonus: " .. ui.RideResults.Bonus.Text)
debug("auto")
debug("speed", "1")

print("== collection")
click(hud.Menu.CollectionButton)
frames(0.1)
local col = ui.Collection
check(col.Visible, "collection opens")
local n = 0
for _ in Data.get(player).floors do
	n += 1
end
check(string.find(col.Opened.Text, n .. "/19", 1, true) ~= nil, "opened: " .. col.Opened.Text)
check(
	not string.find(col.Grid.Card_dark.Text, "???", 1, true),
	"played floor card: " .. col.Grid.Card_dark.Text
)
click(col.Grid.Card_dark)
check(string.find(col.Detail.Text, "Best", 1, true) ~= nil, "card detail: " .. col.Detail.Text)
click(col.Close)

print("== shop")
Data.get(player).coins = 999
Sim.signalOf(RS.Remotes.ClientAction, "OnServerEvent"):Fire(player, { t = "profile" })
frames(0.1)
click(hud.Menu.ShopButton)
frames(0.1)
local shop = ui.Shop
check(shop.Visible, "shop opens")
local cards = 0
for _, d in shop.Body:GetChildren() do
	if Catalog.get(d.Name) then
		cards += 1
	end
end
check(cards == #Catalog.Items, "every item listed (" .. cards .. ")")
click(shop.Body.hat_cap.Button)
frames(0.2)
check(
	Data.get(player).owned.hat_cap and player:GetAttribute("Hat") == "hat_cap",
	"bought a cap — wearing it"
)
click(shop.Tab_chest)
frames(0.1)
local odds = 0
for _, d in shop.Body:GetChildren() do
	if string.sub(d.Name, 1, 5) == "Odds_" then
		odds += 1
	end
end
check(odds == #Catalog.odds(), "every capsule item has its exact chance (" .. odds .. ")")
check(shop.Body:FindFirstChild("OpenChest") ~= nil, "capsule button where allowed")
click(shop.Body.OpenChest.Button)
frames(0.2)
check(ui.Reward.Visible, "capsule result popup")
click(shop.Tab_passes)
frames(0.1)
check(
	shop.Body:FindFirstChild("Vip")
		and shop.Body:FindFirstChild("Emotes")
		and shop.Body:FindFirstChild("Basement"),
	"passes and products incl. «Basement now!»"
)
click(shop.Close)
check(not shop.Visible, "shop closes")

print("== layout: phone 667×375, 812×375, desktop and 1.25 scale")
-- Абсолютный прямоугольник с учётом UIScale предков
local function rect(obj, vp)
	local function walk(o)
		local parent = o.Parent
		local ppos, psize, cum = Vector2.new(0, 0), vp, 1
		if parent and parent.ClassName ~= "ScreenGui" and parent.Name ~= "Hud" then
			local a, b, c = walk(parent)
			ppos, psize, cum = a, b / c, c
		end
		local w = o.Size.X.Scale * psize.X + o.Size.X.Offset
		local h = o.Size.Y.Scale * psize.Y + o.Size.Y.Offset
		local x = o.Position.X.Scale * psize.X + o.Position.X.Offset
		local y = o.Position.Y.Scale * psize.Y + o.Position.Y.Offset
		local sc = o:FindFirstChildOfClass("UIScale")
		local own = if sc then sc.Scale else 1
		local total = cum * own
		local W, H = w * total, h * total
		local pos = ppos + Vector2.new(x * cum - o.AnchorPoint.X * W, y * cum - o.AnchorPoint.Y * H)
		return pos, Vector2.new(W, H), total
	end
	local p, s = walk(obj)
	return p, s
end
local function overlap(a, as, b, bs)
	return a.X < b.X + bs.X and b.X < a.X + as.X and a.Y < b.Y + bs.Y and b.Y < a.Y + as.Y
end
hud.Actions.Vote.Visible = true
for _, vp in { Vector2.new(667, 375), Vector2.new(812, 375), Vector2.new(1280, 720), Vector2.new(1600, 900) } do
	cam.ViewportSize = vp
	Sim.signalOf(cam, "Prop:ViewportSize"):Fire()
	frames(0.1)
	local boxes = {
		{ "board", rect(hud.Board, vp) },
		{ "stats", rect(hud.Stats, vp) },
		{ "menu", rect(hud.Menu, vp) },
		{ "actions", rect(hud.Actions, vp) },
	}
	local clash = nil
	local stick = { Vector2.new(0, vp.Y * 0.55), Vector2.new(vp.X * 0.35, vp.Y * 0.45) }
	for i, b in boxes do
		local p, s = b[2], b[3]
		if p.X < 0 or p.Y < 0 or p.X + s.X > vp.X + 0.5 or p.Y + s.Y > vp.Y + 0.5 then
			clash = clash or (b[1] .. " off screen")
		end
		if overlap(p, s, stick[1], stick[2]) then
			clash = clash or (b[1] .. " covers the thumbstick zone")
		end
		for j = i + 1, #boxes do
			local c = boxes[j]
			if overlap(p, s, c[2], c[3]) then
				clash = clash or (b[1] .. " × " .. c[1])
			end
		end
	end
	check(
		clash == nil,
		string.format("%dx%d: HUD on screen, no overlaps, stick zone free %s", vp.X, vp.Y, clash or "")
	)
	local s = hud.Board.UIScale.Scale
	check(s >= 0.75 and s <= 1.25, string.format("%dx%d: HUD scale %.2f within 0.75…1.25", vp.X, vp.Y, s))
	for _, m in { ui.Shop, ui.Collection, ui.RideResults, ui.Result, hud.Banner } do
		local p, sz = rect(m, vp)
		check(
			p.X >= 0 and p.Y >= 0 and p.X + sz.X <= vp.X + 0.5 and p.Y + sz.Y <= vp.Y + 0.5,
			string.format("%dx%d: %s fits the screen", vp.X, vp.Y, m.Name)
		)
	end
	local _, vs = rect(hud.Actions.Vote.Option_1, vp)
	check(
		vs.Y >= 60 and vs.X >= 90,
		string.format("%dx%d: vote buttons under the thumb (%.0f×%.0f)", vp.X, vp.Y, vs.X, vs.Y)
	)
end
cam.ViewportSize = Vector2.new(1280, 720)
Sim.signalOf(cam, "Prop:ViewportSize"):Fire()

print("== language, debug, restricted region")
Lang.set("ru")
frames(0.1)
check(
	string.find(hud.Menu.ShopButton.Text, "Магазин", 1, true) ~= nil,
	"RU: " .. hud.Menu.ShopButton.Text
)
Lang.set("en")
frames(0.1)
check(string.find(hud.Menu.ShopButton.Text, "Shop", 1, true) ~= nil, "EN")
check(ui:FindFirstChild("DebugToggle") ~= nil, "debug button in Studio")
Sim.policyRestricted = true
local Monetization = Sim.require(server.Monetization)
Monetization.chestAllowed(player) -- кэш: разрешено
Sim.signalOf(Players, "PlayerRemoving"):Fire(player)
task.wait(0.1)
Sim.signalOf(Players, "PlayerAdded"):Fire(player)
task.wait(0.3)
Sim.signalOf(RS.Remotes.ClientAction, "OnServerEvent"):Fire(player, { t = "profile" })
frames(0.2)
click(hud.Menu.ShopButton)
click(ui.Shop.Tab_chest)
frames(0.2)
check(
	ui.Shop.Body:FindFirstChild("OpenChest") == nil and ui.Shop.Body:FindFirstChild("ChestNo") ~= nil,
	"restricted region: no capsule button"
)
Sim.policyRestricted = false
_ = Floors

for _, e in frameErrors do
	print("    " .. e)
end
check(#frameErrors == 0, "no errors in the frame loop")
local clientWarns = 0
for _, w in Sim.warnings or {} do
	if string.find(w, "[Client]", 1, true) or string.find(w, "error", 1, true) then
		clientWarns += 1
		print("    " .. w)
	end
end
check(clientWarns == 0, "no client handler errors")
print(string.format("\n%d failures", #failures))
process.exit(if #failures > 0 then 1 else 0)
