--[[
	LiftService — сервер как тонкий адаптер над чистой моделью Ride:
	  • игроки → Ride.join/leave, позиции ног персонажей → Ride.setPos каждый шаг;
	  • Ride.step(GetServerTimeNow) — вся логика (фазы, этажи, боты, балкон) в модели;
	  • события модели → мир (сцена из деталей, телепорты, полёт на балкон, двери, табло, боты)
	    и сообщения клиентам (вид поездки, этаж, награды, эффекты);
	  • правила этажа для людей: скорость ходьбы (этаж «на цыпочках», «на старт»), гравитация,
	    атрибуты Workspace (FloorId, FloorDark, FloorMirror, FloorFlipped) для клиента.
	Клиент шлёт только намерения (голос, «сесть», «нажать», «подарок», реакция) — проверяет модель.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local Floors = require(Shared.Floors)
local Net = require(Shared.Net)
local Profile = require(Shared.Profile)
local Rewards = require(Shared.Rewards)
local Ride = require(Shared.Ride)

local Data = require(script.Parent.DataService)
local Monetization = require(script.Parent.Monetization)
local Cosmetics = require(script.Parent.Cosmetics)
local World = require(script.Parent.World)

local LiftService = {}

local ride = nil :: any
local playerOf: { [number]: Player } = {}
local flying: { [any]: { t0: number, from: Vector3, to: Vector3, player: Player? } } = {}
local stateDirty = false
local pubDirty = false
local lastGravity = Config.Body.Gravity
local lastEmote: { [Player]: number } = {}
local displayFall = nil :: { from: number, t0: number }?

LiftService.badge = nil :: ((Player, string) -> ())? -- выдать бейдж (ставит init)

function LiftService.ride()
	return ride
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function idOf(player: Player): number
	return player.UserId
end

-------------------------------------------------------------------------------
-- Персонажи
-------------------------------------------------------------------------------
local function rootOf(player: Player): (BasePart?, Humanoid?)
	local ch = player.Character
	if not ch then
		return nil, nil
	end
	return ch:FindFirstChild("HumanoidRootPart") :: BasePart?, ch:FindFirstChildOfClass("Humanoid")
end

-- Ноги ниже корня на (половина корня + HipHeight)
local function feetOffset(player: Player): number
	local root, hum = rootOf(player)
	if not root then
		return 3
	end
	local hip = 2
	if hum then
		local ok, h = pcall(function()
			return hum.HipHeight
		end)
		if ok and type(h) == "number" then
			hip = h
		end
	end
	return root.Size.Y / 2 + hip
end

local FACE = { cabin = 0, floor = 0, lobby = 0, roof = 0, balcony = math.pi }

local function placeHuman(player: Player, x: number, y: number, z: number, where: string?)
	local ch = player.Character
	if not ch then
		return
	end
	local pos = World.toWorld(x, y + feetOffset(player), z)
	ch:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.pi + (FACE[where or ""] or 0), 0))
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Скорость ходьбы и прыжок по правилам этажа
local function applyMovement(player: Player)
	local _, hum = rootOf(player)
	local P = ride and ride.people[idOf(player)]
	if not hum or not P then
		return
	end
	local walk, jump = 16, 50
	local inst = ride.floor
	if P.where == "floor" and inst and ride.phase == "floor" then
		walk = 16 * (inst.speedMul or 1)
		if inst.freeze and inst.t < inst.freeze then
			walk, jump = 0, 0
		end
	elseif P.where == "balcony" or ride.phase == "doors" then
		walk, jump = 0, 0
	end
	if hum.WalkSpeed ~= walk then
		hum.WalkSpeed = walk
	end
	hum.UseJumpPower = true
	if hum.JumpPower ~= jump then
		hum.JumpPower = jump
	end
end

-------------------------------------------------------------------------------
-- Сообщения клиентам
-------------------------------------------------------------------------------
local function toAll(payload)
	Net.ServerEvent:FireAllClients(payload)
end

local function sendState(player: Player)
	if not ride then
		return
	end
	Net.ServerEvent:FireClient(player, { t = "state", v = Ride.view(ride, idOf(player)), now = now() })
end

function LiftService.sync(player: Player)
	sendState(player)
	if ride and ride.stage then
		Net.ServerEvent:FireClient(player, { t = "floor", pub = Floors.public(ride.stage) })
	end
end

local function rowsForClient(rows)
	local out = {}
	for _, r in rows do
		table.insert(out, {
			id = r.id,
			name = r.name,
			bot = r.bot == true,
			stars = r.stars,
			passed = r.passed,
			place = r.place,
			top = r.top,
			clean = r.clean,
			coins = r.coins,
		})
	end
	return out
end

-------------------------------------------------------------------------------
-- Табло и двери по фазе
-------------------------------------------------------------------------------
local GARBLE = { "1̶3", "31", "Ǝ1", "?3", "13" }

local function updateCabin()
	local ph = ride.phase
	World.setDoors(ph == "lobby" or ph == "doors" or ph == "floor" or ph == "floorEnd" or ph == "roof")
	if ph == "cabin" and ride.plan then
		if ride.plan.kind == "vote" then
			local icons = {}
			for _, o in ride.plan.options do
				table.insert(icons, Floors.CatIcon[o.cat])
			end
			local _, sum = Ride.tallyNow(ride)
			World.setPanel(icons, sum)
		else
			World.setPanel({ "❓", "❓", "❓" }, nil)
		end
	else
		World.setPanel(nil, nil)
	end
	if ph == "lobby" or ph == "idle" then
		World.setDisplay("L")
	elseif ph == "roof" then
		World.setDisplay("R")
	elseif ph == "fall" then
		displayFall = { from = ride.stop, t0 = now() }
	elseif ride.floorId == "basement" and ph ~= "cabin" then
		World.setDisplay(GARBLE[ride.rng:int(1, #GARBLE)])
	else
		World.setDisplay(tostring(ride.stop) .. (if ph == "cabin" then " ▲" else ""))
	end
end

-------------------------------------------------------------------------------
-- Награды
-------------------------------------------------------------------------------
local function onReward(e)
	local player = playerOf[e.id]
	local d = player and Data.get(player)
	if not player or not d then
		return
	end
	local first = Profile.recordFloor(d, e.floor, e.stars, e.score or 0, e.passed)
	Profile.earn(d, e.coins)
	local prize = nil
	if e.floor == "basement" and not d.owned[Catalog.BasementPrize] then
		Profile.grantItem(d, Catalog.BasementPrize)
		prize = Catalog.BasementPrize
		if LiftService.badge then
			LiftService.badge(player, "Basement")
		end
	end
	Data.changed(player)
	Net.ServerEvent:FireClient(player, {
		t = "reward",
		floor = e.floor,
		stars = e.stars,
		passed = e.passed,
		top = e.top,
		clean = e.clean,
		place = e.place,
		coins = e.coins,
		first = first,
		prize = prize,
	})
	Monetization.sendProfile(player)
end

local function onRideReward(e)
	local player = playerOf[e.id]
	local d = player and Data.get(player)
	if not player or not d then
		return
	end
	Profile.recordRide(d, e.passed)
	Profile.earn(d, e.coins)
	Data.changed(player)
	if LiftService.badge then
		LiftService.badge(player, "Roof")
	end
	Net.ServerEvent:FireClient(
		player,
		{ t = "rideReward", coins = e.coins, stars = e.stars, passed = e.passed }
	)
	Monetization.sendProfile(player)
end

-- Кафе: подарок каждому + ежедневный
local function onGift(e)
	local player = playerOf[e.id]
	local d = player and Data.get(player)
	if not player or not d then
		return
	end
	Profile.addCoins(d, Config.Rewards.CafeGift)
	local daily = Profile.claimDaily(d, math.floor(os.time() / 86400))
	Data.changed(player)
	Net.ServerEvent:FireClient(player, {
		t = "toast",
		key = if daily then "cafe.daily" else "cafe.gift",
		vars = { n = Config.Rewards.CafeGift, d = Config.Rewards.DailyGift },
	})
	Monetization.sendProfile(player)
end

-------------------------------------------------------------------------------
-- События модели → мир
-------------------------------------------------------------------------------
local exitList = {}

local function handle(e)
	local t = e.t
	if t == "phase" then
		stateDirty = true
		updateCabin()
		if e.phase == "cabin" or e.phase == "lobby" or e.phase == "idle" then
			Workspace.Gravity = Config.Body.Gravity
			lastGravity = Config.Body.Gravity
		end
	elseif t == "tp" then
		stateDirty = true
		local P = ride.people[e.id]
		if P and P.bot then
			World.moveBot(e.id, e.x, e.y, e.z, 0)
		else
			local player = playerOf[e.id]
			if player then
				flying[e.id] = nil
				Cosmetics.pose(player, false)
				local root = rootOf(player)
				if root then
					root.Anchored = false
				end
				placeHuman(player, e.x, e.y, e.z, e.to)
				if e.to == "balcony" then
					Cosmetics.pose(player, true)
				end
			end
		end
		if e.exit then
			table.insert(exitList, e.id)
		end
	elseif t == "out" then
		stateDirty = true
		local P = ride.people[e.id]
		local from = World.toWorld(e.x, e.y, e.z)
		local to = World.toWorld(e.to[1], e.to[2], e.to[3])
		local player = playerOf[e.id]
		flying[e.id] = { t0 = now(), from = from, to = to, player = player }
		if player then
			local root = rootOf(player)
			if root then
				root.Anchored = true
			end
		end
		toAll({ t = "out", id = e.id, name = P and P.name, bot = P and P.bot, x = e.x, y = e.y, z = e.z })
	elseif t == "stage" then
		World.buildStage(ride.stage)
		local inst = ride.stage
		Workspace:SetAttribute("FloorId", if e.kind == "floor" then e.id else e.kind)
		Workspace:SetAttribute("FloorDark", inst.dark == true)
		Workspace:SetAttribute("FloorMirror", inst.mirror == true)
		Workspace:SetAttribute("FloorFlipped", inst.flipped == true)
		pubDirty = true
		if e.kind == "floor" and e.id == "cafe" then
			-- витрина Кафе: манекены в случайных шапках из каталога
			local hats = {}
			for _, it in Catalog.Items do
				if it.kind == "hat" and it.parts and #it.parts > 0 and it.rarity ~= "Secret" then
					table.insert(hats, it.id)
				end
			end
			for i, n in inst.show or {} do
				local head = World.stagePart("MannequinHead" .. i)
				if head and #hats > 0 then
					Cosmetics.attach(head, hats[n % #hats + 1], "Show" .. i, true)
				end
			end
		end
	elseif t == "pub" then
		pubDirty = true
	elseif t == "bot" then
		stateDirty = true
		if e.add then
			World.addBot(e.id, e.name)
		else
			World.removeBot(e.id)
			flying[e.id] = nil
		end
	elseif t == "votes" then
		stateDirty = true
		updateCabin()
	elseif t == "doors" then
		local chimeBy = e.chime and playerOf[e.chime]
		toAll({
			t = "doors",
			id = e.id,
			cat = e.cat,
			why = e.why,
			chime = chimeBy and chimeBy:GetAttribute("Chime") or Catalog.Default.chime,
			chimeName = chimeBy and chimeBy.DisplayName,
		})
	elseif t == "cabinFx" or t == "announce" then
		toAll(e)
	elseif t == "reward" then
		onReward(e)
	elseif t == "rideReward" then
		onRideReward(e)
	elseif t == "floorEnd" then
		toAll({ t = "floorEnd", id = e.id, rows = rowsForClient(e.rows) })
	elseif t == "rideEnd" then
		toAll({ t = "rideEnd", rows = rowsForClient(e.rows) })
	elseif e.floorEvent then
		if t == "gift" then
			onGift(e)
		end
		if (t == "respawn" or t == "sit") and playerOf[e.id] then
			local p = ride.floor and ride.floor.byId[e.id]
			if p then
				placeHuman(playerOf[e.id], p.x, p.y, p.z, "floor")
			end
		end
		toAll({ t = "fx", e = e })
	end
end

-------------------------------------------------------------------------------
-- Игроки
-------------------------------------------------------------------------------
local function flagsOf(player: Player): (boolean, number)
	local vip = Monetization.hasPass(player, "Vip")
	return vip, Rewards.multiplier(Monetization.hasPass(player, "DoubleCoins"), vip)
end

function LiftService.join(player: Player)
	local id = idOf(player)
	playerOf[id] = player
	local vip, mult = flagsOf(player)
	Ride.join(ride, id, player.DisplayName, { vip = vip, mult = mult })
	LiftService.flush()
end

function LiftService.leave(player: Player)
	local id = idOf(player)
	Ride.leave(ride, id)
	playerOf[id] = nil
	flying[id] = nil
	lastEmote[player] = nil
	LiftService.flush()
end

function LiftService.refreshFlags(player: Player)
	local vip, mult = flagsOf(player)
	Ride.setFlags(ride, idOf(player), vip, mult)
	stateDirty = true
end

-- Персонаж появился: поставить туда, где игрок по модели
function LiftService.onCharacter(player: Player)
	local P = ride.people[idOf(player)]
	if P then
		placeHuman(player, P.x, P.y, P.z, P.where)
		if P.where == "balcony" then
			Cosmetics.pose(player, true)
		end
	end
	applyMovement(player)
end

function LiftService.vote(player: Player, k: any): boolean
	if type(k) ~= "number" then
		return false
	end
	local ok = Ride.vote(ride, idOf(player), math.floor(k))
	LiftService.flush()
	return ok
end

function LiftService.act(player: Player, a: any): (boolean, string?)
	if type(a) ~= "table" or type(a.t) ~= "string" then
		return false, "bad"
	end
	local ok, why = Ride.act(ride, idOf(player), { t = a.t })
	LiftService.flush()
	return ok, why
end

function LiftService.emote(player: Player, e: any)
	if type(e) ~= "string" or not Catalog.emoteAllowed(e, Monetization.hasPass(player, "Emotes")) then
		return
	end
	local t = os.clock()
	if lastEmote[player] and t - lastEmote[player] < 0.8 then
		return
	end
	lastEmote[player] = t
	toAll({ t = "emote", id = idOf(player), e = e })
end

-- «Подвал сейчас!»
function LiftService.canBasement(_player: Player): (boolean, string?)
	return Ride.canBasement(ride)
end

function LiftService.forceBasement(player: Player): boolean
	local ok = Ride.forceBasement(ride, player.DisplayName)
	LiftService.flush()
	stateDirty = true
	return ok
end

function LiftService.holdCabin(_player: Player)
	if Ride.holdCabin(ride) then
		LiftService.flush()
	end
end

-------------------------------------------------------------------------------
-- Шаг
-------------------------------------------------------------------------------
function LiftService.flush()
	for _, e in Ride.drain(ride) do
		local ok, err = pcall(handle, e)
		if not ok then
			warn("[Lift] event", e.t, err)
		end
	end
	if stateDirty then
		stateDirty = false
		for _, player in playerOf do
			sendState(player)
		end
	end
	if pubDirty and ride.stage then
		pubDirty = false
		toAll({ t = "floor", pub = Floors.public(ride.stage) })
	end
	if #exitList > 0 then
		toAll({ t = "exit", list = exitList })
		exitList = {}
	end
end

function LiftService.step()
	local tNow = now()
	-- позиции людей (кроме летящих на балкон и автопилота)
	for id, player in playerOf do
		local P = ride.people[id]
		if P and not P.auto and not flying[id] then
			local root = rootOf(player)
			if root then
				local x, y, z = World.toStage(root.CFrame.Position)
				Ride.setPos(ride, id, x, y - feetOffset(player), z)
			end
		end
	end
	Ride.step(ride, tNow)
	if ride.stage and #ride.changes > 0 then
		World.applyChanges(ride.stage, ride.changes)
	end
	LiftService.flush()
	local inst = ride.floor
	if inst and ride.phase == "floor" and inst.gravity ~= lastGravity then
		lastGravity = inst.gravity
		Workspace.Gravity = inst.gravity
	end
	-- боты и автопилот
	for _, id in ride.order do
		local P = ride.people[id]
		if P and not flying[id] then
			if P.bot then
				local p = inst and inst.byId[id]
				local yaw = 0
				if p and (math.abs(p.vx) + math.abs(p.vz)) > 0.5 then
					yaw = math.atan2(-p.vx, -p.vz)
				end
				World.moveBot(id, P.x, P.y, P.z, yaw)
			elseif P.auto and playerOf[id] and P.where == "floor" then
				placeHuman(playerOf[id], P.x, P.y, P.z, "floor")
			end
		end
	end
	-- полёт на балкон
	for id, f in flying do
		local k = math.clamp((tNow - f.t0) / Config.Floor.OutFlight, 0, 1)
		local pos = f.from:Lerp(f.to, k) + Vector3.new(0, math.sin(k * math.pi) * 14, 0)
		local spin = CFrame.Angles(k * math.pi * 4, 0, 0)
		if f.player then
			local ch = f.player.Character
			if ch then
				ch:PivotTo(CFrame.new(pos + Vector3.new(0, feetOffset(f.player), 0)) * spin)
			end
		else
			local m = World.bot(id)
			if m then
				m:PivotTo(CFrame.new(pos) * spin)
			end
		end
		if k >= 1 then
			flying[id] = nil
			if f.player then
				local root = rootOf(f.player)
				if root then
					root.Anchored = false
				end
				local ch = f.player.Character
				if ch then
					ch:PivotTo(
						CFrame.new(f.to + Vector3.new(0, feetOffset(f.player), 0)) * CFrame.Angles(0, 0, 0)
					)
				end
				Cosmetics.pose(f.player, true)
			else
				local m = World.bot(id)
				if m then
					m:PivotTo(CFrame.new(f.to))
				end
			end
		end
	end
	-- табло при падении: цифры бегут вниз
	if displayFall and ride.phase == "fall" then
		local k = math.clamp((tNow - displayFall.t0) / Config.Ride.Fall, 0, 1)
		World.setDisplay(tostring(math.max(1, math.ceil(displayFall.from * (1 - k)))) .. " ▼")
	end
	for _, player in playerOf do
		applyMovement(player)
	end
end

-------------------------------------------------------------------------------
-- Отладка: floor <id> | next | boss | basement | bots <n> | speed <x> | state | auto
-------------------------------------------------------------------------------
function LiftService.debug(player: Player, cmd: string, arg: string?): string
	if cmd == "auto" then
		local P = ride.people[idOf(player)]
		if P then
			Ride.setAuto(ride, idOf(player), if P.auto then nil else (arg or "medium"))
			return "autopilot " .. (if ride.people[idOf(player)].auto then "on" else "off")
		end
		return "no player"
	end
	local msg = Ride.debug(ride, cmd, arg)
	LiftService.flush()
	return msg
end

function LiftService.boot()
	ride = Ride.new({ seed = math.floor(os.time()) % 100000 + 1, now = now() })
	updateCabin()
	Monetization.canBasement = LiftService.canBasement
	Monetization.onBasement = LiftService.forceBasement
	Monetization.beforePrompt = function(player, key)
		if key == "Basement" then
			LiftService.holdCabin(player)
		end
	end
	Monetization.onPass(function(player)
		LiftService.refreshFlags(player)
	end)
end

return LiftService
