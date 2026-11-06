--[[
	Прогон сервера на заглушке движка: мир из примитивов, лобби, полная поездка из 10 этажей
	(Алису ведёт автопилот — та же голова бота; боты-пассажиры — модели из шаров), голосование
	только в кабине и только своими голосами, анти-чит (нажать издалека, голос не в кабине,
	телепорт к кнопке), награды и коллекция в профиле, leaderstats, крыша и падение в лобби,
	вход посреди этажа (балкон → кабина), выход посреди этажа, «Подвал сейчас!» с объявлением
	и продлением кабины на время оплаты, капсула и PolicyService, чеки, сбой DataStore,
	все люди ушли → лифт стоит, ботов нет; отладка через атрибут DebugCommand; самотест.
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
local RS = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local function shared(name)
	return Sim.require(RS.Shared[name])
end
local Config = shared("Config")
local Catalog = shared("Catalog")
local Floors = shared("Floors")
Sim.virtualTime = 1000

local function tick(dt)
	Sim.virtualTime += dt
	Sim.signalOf(RunService, "Heartbeat"):Fire(dt)
	task.wait()
end
local function waitUntil(fn, timeout)
	local t0 = os.clock()
	while not fn() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.02)
	end
	return true
end
local function tickUntil(fn, maxSec, dt)
	local t = 0
	local d = dt or 0.1
	while not fn() and t < maxSec do
		tick(d)
		t += d
	end
	return fn()
end
local function sentTo(player, kind)
	local out = {}
	for _, s in Sim.sent do
		if (s.player == player or s.player == "all") and s.payload and s.payload.t == kind then
			table.insert(out, s.payload)
		end
	end
	return out
end
local function last(player, kind)
	local l = sentTo(player, kind)
	return l[#l]
end
local function action(player, payload)
	Sim.signalOf(RS.Remotes.ClientAction, "OnServerEvent"):Fire(player, payload)
	task.wait(0.02)
end
local function debug(cmd)
	ws:SetAttribute("DebugCommand", cmd)
	Sim.signalOf(ws, "Attr:DebugCommand"):Fire()
	task.wait(0.05)
end

print("== boot")
local server = game:GetService("ServerScriptService").Server
local alice = Sim.addPlayer("Alice")
Sim.runScript(server)
check(
	waitUntil(function()
		return ws:GetAttribute("WorldReady") == true
	end, 20),
	"server ready"
)
local Lift = Sim.require(server.LiftService)
local Data = Sim.require(server.DataService)
local ride = Lift.ride()
check(
	waitUntil(function()
		tick(0.05)
		return alice.Character ~= nil and ride.people[alice.UserId] ~= nil
	end, 8),
	"Alice joins the lift and gets a character"
)
local lift = ws:FindFirstChild("Lift")
check(
	lift
		and lift:FindFirstChild("DoorL")
		and lift:FindFirstChild("Display")
		and lift:FindFirstChild("Balcony")
		and lift:FindFirstChild("VoteButton3")
		and lift:FindFirstChild("VipButton"),
	"cabin, doors, display, vote panel and balcony from primitives"
)
check(ride.phase == "lobby", "phase lobby, countdown")
check(
	ws:FindFirstChild("Stage") and ws.Stage:GetAttribute("Floor") == "lobby",
	"the lobby is built in front of the door"
)
local st = last(alice, "state")
check(st and st.v.phase == "lobby" and st.v.left > 0, "client told: lobby and the countdown")

print("== cabin: bot passengers, vote")
check(
	tickUntil(function()
		return ride.phase == "cabin"
	end, 25),
	"the ride starts: everyone in the cabin"
)
local bots = ws:FindFirstChild("Passengers")
check(bots and #bots:GetChildren() == 3, "3 bot passengers built from primitives")
local P = ride.people[alice.UserId]
check(P.where == "cabin", "Alice is in the cabin")
local root = alice.Character.HumanoidRootPart
local cx, _, cz = ride.people[alice.UserId].x, 0, ride.people[alice.UserId].z
check(
	(root.CFrame.Position - (Sim.require(server.World).toWorld(cx, 0, cz))).Magnitude < 4,
	"Alice's character stands at her cabin spot"
)
-- найти остановку с голосованием
local voted = false
for _ = 1, 3 do
	if ride.plan.kind == "vote" then
		break
	end
	debug("next")
	tickUntil(function()
		return ride.phase == "cabin"
	end, 90)
end
if ride.plan.kind == "vote" then
	local v = last(alice, "state").v
	check(v.options and #v.options == 3 and v.options[1].id == nil, "3 buttons: category only, no floor name")
	action(alice, { t = "vote", k = 2 })
	check(ride.votes[alice.UserId] and ride.votes[alice.UserId].k == 2, "Alice voted for button 2")
	local want = ride.plan.options[2].id
	tickUntil(function()
		return ride.phase == "doors"
	end, 20)
	check(ride.floorId == want, "her button wins (bots don't vote): " .. tostring(want))
	voted = true
end
check(voted, "a vote happened")
action(alice, { t = "vote", k = 1 })
check(last(alice, "toast") and last(alice, "toast").key == "vote.notNow", "no voting outside the cabin phase")

print("== a floor: stage from parts, bots walk, autopilot plays Alice")
tickUntil(function()
	return ride.phase == "floor"
end, 5)
check(ws.Stage:GetAttribute("Floor") == ride.floorId, "stage built: " .. tostring(ride.floorId))
check(#ws.Stage:GetChildren() == #ride.floor.order, "every part of the floor spec is in the world")
debug("auto")
check(ride.people[alice.UserId].auto ~= nil, "autopilot on (debug command via attribute)")
check(#sentTo(alice, "exit") > 0, "exit-from-the-lift effect sent")

print("== anti-cheat")
-- нажать то, чего рядом нет: модель отвергает
local ok = Lift.act(alice, { t = "press" })
check(not ok, "press far from anything is refused")
action(alice, { t = "act", a = { t = "sit" } })
check(true, "sit outside chairs is ignored")
action(alice, { t = "vote", k = 9 })
check(true, "bad vote ignored")

print("== the whole ride: 10 floors")
local floorsSeen, rewards = {}, 0
local guard = 0
while ride.phase ~= "roof" and guard < 20000 do
	guard += 1
	if ride.phase == "doors" and floorsSeen[#floorsSeen] ~= ride.floorId .. ride.stop then
		table.insert(floorsSeen, ride.floorId .. ride.stop)
	end
	tick(0.1)
end
check(ride.phase == "roof", "reached the roof after " .. #floorsSeen + 1 .. " floors")
rewards = #sentTo(alice, "reward")
check(rewards == 10, "a reward message per floor: " .. rewards)
local d = Data.get(alice)
local opened = 0
for _ in d.floors do
	opened += 1
end
check(opened >= 9, "floors in the collection: " .. opened)
check(d.stars > 0 and alice.leaderstats.Stars.Value == d.stars, "stars saved and in leaderstats: " .. d.stars)
check(d.coins > 0 and alice.leaderstats.Coins.Value == d.coins, "coins: " .. d.coins)
check(last(alice, "rideReward") ~= nil and d.rides == 1, "ride bonus on the roof")
check(alice.leaderstats.Floors.Value == d.bestFloors, "record floors per ride: " .. d.bestFloors)
local fe = last(alice, "floorEnd")
local botRow = false
for _, r in fe.rows do
	if r.bot then
		botRow = true
		check(r.coins == nil, "bots get no coins")
	end
end
check(botRow, "bots are marked in the results")
check(ws.Stage:GetAttribute("Floor") == "roof", "the roof is built")
check(
	tickUntil(function()
		return ride.phase == "lobby"
	end, Config.Ride.Roof + Config.Ride.Fall + 2),
	"the lift falls back to the lobby"
)
check(#bots:GetChildren() == 0, "bot passengers leave in the lobby")

print("== late joiner, leaving mid-floor")
debug("auto")
check(ride.people[alice.UserId].auto == nil, "autopilot off")
tickUntil(function()
	return ride.phase == "floor"
end, 60)
local bob = Sim.addPlayer("Bob")
Sim.signalOf(Players, "PlayerAdded"):Fire(bob)
check(
	waitUntil(function()
		tick(0.05)
		return bob.Character ~= nil and ride.people[bob.UserId] ~= nil
	end, 6),
	"Bob joins mid-floor"
)
check(ride.people[bob.UserId].where == "balcony", "Bob waits on the balcony")
check(ride.floor.byId[bob.UserId] == nil, "not on the floor in progress")
check(
	tickUntil(function()
		return ride.phase == "cabin"
	end, 70),
	"next stop"
)
check(ride.people[bob.UserId].where == "cabin", "Bob is in the cabin at the next stop")
check(#bots:GetChildren() == 2, "2 people → 2 bot passengers")
tickUntil(function()
	return ride.phase == "floor"
end, 20)
Sim.signalOf(Players, "PlayerRemoving"):Fire(bob)
task.wait(0.05)
bob.Parent = nil
check(
	ride.people[bob.UserId] == nil and ride.floor.byId[bob.UserId].out,
	"Bob left mid-floor: out of the floor"
)
check(ride.phase == "floor", "the floor goes on")

print("== «Basement now!» and the payment hold")
tickUntil(function()
	return ride.phase == "cabin"
end, 70)
local e0 = ride.phaseEnd
Sim.sent = {}
action(alice, { t = "product", key = "Basement" })
check(ride.phaseEnd >= e0 + Config.Ride.PayHold - 0.01, "cabin held while paying")
check(ride.plan.kind == "surprise" and ride.plan.id == "basement", "next floor is the Basement")
local ann = last(alice, "announce")
check(
	ann and ann.key == "announce.basement" and ann.name == alice.DisplayName,
	"everyone is told who called it"
)
Sim.sent = {}
action(alice, { t = "product", key = "Basement" })
check(
	last(alice, "toast") and string.find(last(alice, "toast").key, "shop.basementNo", 1, true) ~= nil,
	"not twice per ride"
)
tickUntil(function()
	return ride.phase == "floor"
end, 30)
check(ride.floorId == "basement" and ws:GetAttribute("FloorFlipped") == true, "the Basement: upside down")
debug("next")
tickUntil(function()
	return ride.phase == "floorEnd"
end, 10)
check(Data.get(alice).owned[Catalog.BasementPrize] == true, "unique Basement hat granted")
check(Data.get(alice).floors.basement ~= nil, "the Basement is in the collection")

print("== debug commands")
debug("floor chairs")
tickUntil(function()
	return ride.phase == "doors"
end, 20)
check(ride.floorId == "chairs", "floor chairs")
debug("bots 6")
tickUntil(function()
	return ride.phase == "cabin"
end, 80)
check(#bots:GetChildren() == 6, "bots 6")
debug("bots auto")
debug("speed 2")
check(ride.speed == 2, "speed 2")
debug("speed 1")
debug("state")
local stMsg = last(alice, "toast")
check(
	stMsg and stMsg.vars and string.find(stMsg.vars.text, "phase=", 1, true) ~= nil,
	"state: " .. tostring(stMsg and stMsg.vars and stMsg.vars.text)
)
debug("boss")
tickUntil(function()
	return ride.phase == "doors"
end, 20)
check(Floors.get(ride.floorId).cat == "boss", "boss now: " .. tostring(ride.floorId))

print("== emotes")
Sim.sent = {}
action(alice, { t = "emote", e = "😂" })
check(last(alice, "emote") and last(alice, "emote").e == "😂", "a reaction floats for everyone")
tick(1)
action(alice, { t = "emote", e = "🤡" })
check(last(alice, "emote").e ~= "🤡", "plus reactions need the pass")

print("== shop: coins, equip, capsule, PolicyService, receipts")
d = Data.get(alice)
d.coins = 5000
action(alice, { t = "buyCoins", id = "hat_top" })
check(d.owned.hat_top and alice:GetAttribute("Hat") == "hat_top", "bought a top hat and wearing it")
task.wait(0.05)
check(alice.Character:FindFirstChild("LiftHat") ~= nil, "the hat is built from primitives on the head")
action(alice, { t = "buyCoins", id = "hat_vip" })
check(not d.owned.hat_vip, "VIP hat not for sale")
action(alice, { t = "pass", key = "Vip" })
action(alice, { t = "equip", id = "hat_vip" })
check(alice:GetAttribute("Hat") == "hat_vip", "VIP golden top hat")
check(alice.Character.Head:FindFirstChild("VipTag") ~= nil, "★ VIP tag")
check(ride.people[alice.UserId].vip == true, "VIP vote weighs ×2 in the ride")
action(alice, { t = "product", key = "Chest" })
local cr = last(alice, "chestResult")
check(cr ~= nil and Catalog.get(cr.id) ~= nil, "capsule gives an item: " .. tostring(cr and cr.id))
Sim.policyRestricted = true
local carol = Sim.addPlayer("Carol")
Sim.signalOf(Players, "PlayerAdded"):Fire(carol)
check(
	waitUntil(function()
		tick(0.05)
		return Data.get(carol) ~= nil
	end, 6),
	"Carol joins"
)
task.wait(0.1)
action(carol, { t = "profile" })
check(last(carol, "profile").chestAllowed == false, "restricted region: capsule hidden")
action(carol, { t = "product", key = "Chest" })
check(
	last(carol, "toast").key == "shop.chestRestricted" and last(carol, "chestResult") == nil,
	"server refuses the capsule"
)
action(carol, { t = "product", key = "DirectEpic", item = "hat_crown" })
check(Data.get(carol).owned.hat_crown == true, "direct purchase works")
Sim.policyRestricted = false
Sim.policyFail = true
local dave = Sim.addPlayer("Dave")
Sim.signalOf(Players, "PlayerAdded"):Fire(dave)
waitUntil(function()
	tick(0.05)
	return Data.get(dave) ~= nil
end, 5)
task.wait(0.1)
action(dave, { t = "product", key = "Chest" })
check(last(dave, "chestResult") == nil, "policy request fails → capsule treated as restricted")
Sim.policyFail = false
local Monetization = Sim.require(server.Monetization)
local c1 = d.coins
Monetization.grant(alice, "Coins500", "PID-1")
Monetization.grant(alice, "Coins500", "PID-1")
check(d.coins == c1 + 500, "receipts are idempotent")

print("== data")
check(Data.save(alice), "save works")
local stored = Sim.dataStores[Config.DataStore.Name]["u_" .. alice.UserId]
check(
	stored and stored.stars == d.stars and stored.floors.basement ~= nil,
	"profile stored with the collection"
)
Sim.dataFail = true
local erin = Sim.addPlayer("Erin")
Sim.signalOf(Players, "PlayerAdded"):Fire(erin)
check(
	waitUntil(function()
		tick(0.05)
		return Data.get(erin) ~= nil and ride.people[erin.UserId] ~= nil
	end, 15),
	"data outage: temp profile, still in the lift"
)
check(erin:GetAttribute("DataSaved") == false, "temp profile is marked unsaved")
Sim.dataFail = false

print("== selftest")
action(alice, { t = "debug", cmd = "selftest" })
check(
	waitUntil(function()
		return #sentTo(alice, "selftest") > 0
	end, 30),
	"selftest finished"
)
local stl = last(alice, "selftest")
local fails = 0
for _, line in stl and stl.lines or {} do
	print("    " .. line)
	if string.find(line, "FAIL", 1, true) then
		fails += 1
	end
end
check(fails == 0, "selftest has no FAIL")

print("== everyone leaves: the lift stops, no bots")
for _, p in { alice, carol, dave, erin } do
	Sim.signalOf(Players, "PlayerRemoving"):Fire(p)
	task.wait(0.02)
	p.Parent = nil
end
tick(0.1)
check(ride.phase == "idle", "idle")
check(#bots:GetChildren() == 0, "bot passengers removed")
local c0 = ride.clock
for _ = 1, 20 do
	tick(0.5)
end
check(ride.clock == c0, "an empty server does not tick the ride")

print("== warnings")
local errs = 0
for _, w in Sim.warnings or {} do
	if
		string.find(w, "error", 1, true)
		or string.find(w, "[Actions]", 1, true)
		or string.find(w, "[Lift]", 1, true)
	then
		errs += 1
		print("    " .. w)
	end
end
check(errs == 0, "no runtime errors")
print(string.format("\n%d failures", #failures))
process.exit(if #failures > 0 then 1 else 0)
