--[[
	Ride — чистая модель поездки лифта (без инстансов): фазы, участники, голосование, подбор
	этажа, этаж (Floors), балкон, боты-пассажиры, звёзды и монеты.

	Фазы: idle (людей нет) → lobby → cabin (голосование) → doors → floor → floorEnd → cabin … →
	после 10-го: roof → fall → lobby.

	Сервер — тонкий адаптер: join/leave/vote/act от игроков, setPos — позиции людей,
	step(now) — по GetServerTimeNow; события (drain) превращает в мир и сообщения клиентам:
	  tp { id, to, x, y, z, exit? }    — поставить человека/бота (координаты сцены, ноги)
	  out { id, x, y, z, to = {x,y,z} } — смешно улетел на балкон
	  stage { kind, id }               — построить сцену (лобби, этаж, крыша) из ride.stage
	  phase { phase }                  — смена фазы (клиентам — вид)
	  votes { sum }, doors { id, cat, chime }, cabinFx { kind }, announce { key, name }
	  reward { id, floor, stars, … }, floorEnd { rows }, rideReward { id, coins }, rideEnd { rows }
	  bot { id, add | remove }
	Изменения деталей сцены за шаг — ride.changes (сервер применяет к моделям).
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Rng = require(Shared.Rng)
local Floors = require(Shared.Floors)
local Kit = require(Shared.FloorKit)
local Picker = require(Shared.Picker)
local Bots = require(Shared.Bots)

local Ride = {}

local R = Config.Ride

-------------------------------------------------------------------------------
-- Точки сцены
-------------------------------------------------------------------------------
function Ride.cabinSpot(i: number): (number, number, number)
	local c = Config.Stage.CabinSpots
	local cols, rows = 5, 3
	local k = (i - 1) % (cols * rows)
	local col, row = k % cols, math.floor(k / cols)
	local x = c.x0 + (c.x1 - c.x0) * col / (cols - 1)
	local z = c.z0 + (c.z1 - c.z0) * row / (rows - 1)
	return x, 0, z
end

function Ride.balconySpot(i: number): (number, number, number)
	local b = Config.Stage.Balcony
	local per = 12
	local k = (i - 1) % (per * 2)
	local col, row = k % per, math.floor(k / per)
	local x = b.x - b.w / 2 + 2 + (b.w - 4) * col / (per - 1)
	local z = b.z - b.d / 2 + 2.5 + row * 4
	return x, b.y, z
end

-------------------------------------------------------------------------------
-- Создание
-------------------------------------------------------------------------------
function Ride.new(opts)
	opts = opts or {}
	local ride = {
		seed = opts.seed or 1,
		rng = Rng.new(opts.seed or 1),
		clock = 0,
		now = opts.now or 0,
		phase = "idle",
		phaseEnd = math.huge,
		rideNo = 0,
		stop = 0,
		history = {},
		bosses = {},
		plan = nil :: any,
		votes = {},
		holdUsed = false,
		basementBy = nil :: string?,
		basementUsed = false,
		forced = nil :: string?,
		people = {},
		order = {},
		stage = nil :: any,
		floor = nil :: any,
		floorId = nil :: string?,
		events = {},
		changes = {},
		botTarget = nil :: number?,
		botSeq = 0,
		speed = 1,
		firstLobby = true,
		lastPubRev = -1,
		lastRows = nil,
		cabinFx = nil,
		chime = nil,
		stats = { maxBalcony = 0, rideMaxBalcony = 0, floors = 0, rides = 0 },
		quiet = opts.quiet == true, -- тесты: не копить события
	}
	return ride
end

local function emit(ride, e)
	if ride.quiet and e.t ~= "out" then
		return
	end
	table.insert(ride.events, e)
end

function Ride.drain(ride)
	local e = ride.events
	ride.events = {}
	return e
end

local function humans(ride): number
	local n = 0
	for _, id in ride.order do
		if not ride.people[id].bot then
			n += 1
		end
	end
	return n
end
Ride.humans = humans

local function list(ride, where: string?)
	local out = {}
	for _, id in ride.order do
		local P = ride.people[id]
		if where == nil or P.where == where then
			table.insert(out, P)
		end
	end
	return out
end
Ride.list = list

local function setPhase(ride, phase: string, dur: number)
	ride.phase = phase
	ride.phaseStart = ride.clock
	ride.phaseEnd = ride.clock + dur
	emit(ride, { t = "phase", phase = phase })
end

local function tp(ride, P, to: string, x: number, y: number, z: number, extra)
	P.where = to
	P.x, P.y, P.z = x, y, z
	local e = { t = "tp", id = P.id, to = to, x = x, y = y, z = z }
	if extra then
		for k, v in extra do
			e[k] = v
		end
	end
	emit(ride, e)
end

local function newStage(ride, id: string, roster)
	ride.stage = Floors.new(id, { seed = ride.rng:int(1, 2 ^ 30), roster = roster or {} })
	ride.lastPubRev = -1
	emit(ride, { t = "stage", kind = if Floors.get(id).cat == "stage" then id else "floor", id = id })
	return ride.stage
end

-- Балкон: учёт ожидания
local function leaveBalcony(ride, P)
	if P.balconySince then
		local w = ride.clock - P.balconySince
		if not P.bot then
			ride.stats.maxBalcony = math.max(ride.stats.maxBalcony, w)
			ride.stats.rideMaxBalcony = math.max(ride.stats.rideMaxBalcony, w)
		end
		P.balconySince = nil
	end
end

local function toBalcony(ride, P, fromFloor)
	local i = 0
	for _, Q in list(ride) do
		if Q.where == "balcony" then
			i += 1
		end
	end
	local x, y, z = Ride.balconySpot(i + 1)
	P.balconySince = P.balconySince or ride.clock
	if fromFloor then
		P.where = "balcony"
		emit(ride, { t = "out", id = P.id, x = P.x, y = P.y, z = P.z, to = { x, y, z } })
		P.x, P.y, P.z = x, y, z
	else
		tp(ride, P, "balcony", x, y, z)
	end
end

-------------------------------------------------------------------------------
-- Боты-пассажиры
-------------------------------------------------------------------------------
local function removeBot(ride, id)
	local P = ride.people[id]
	if not P then
		return
	end
	ride.people[id] = nil
	table.remove(ride.order, table.find(ride.order, id) :: number)
	emit(ride, { t = "bot", id = id, remove = true })
end

local function fillBots(ride)
	local h = humans(ride)
	local want = if h == 0 then 0 else math.clamp(Config.Bots.MinCrew - h, 0, Config.Bots.Max)
	if ride.botTarget then
		want = if h == 0 then 0 else ride.botTarget
	end
	local bots = {}
	for _, id in ride.order do
		if ride.people[id].bot then
			table.insert(bots, id)
		end
	end
	while #bots > want do
		removeBot(ride, table.remove(bots))
	end
	local used = {}
	for _, id in bots do
		used[ride.people[id].name] = true
	end
	while #bots < want do
		ride.botSeq += 1
		local id = "bot" .. ride.botSeq
		local name
		for k = 0, #Bots.Names - 1 do
			local cand = Bots.Names[(ride.botSeq + k - 1) % #Bots.Names + 1]
			if not used[cand] then
				name = cand
				break
			end
		end
		name = name or Bots.Names[1]
		used[name] = true
		local skill = Config.Bots.Skills[(#bots % #Config.Bots.Skills) + 1]
		local P = {
			id = id,
			name = name,
			bot = true,
			skill = skill,
			mem = Bots.mem(skill, ride.rng:int(1, 2 ^ 30)),
			where = "cabin",
			x = 0,
			y = 0,
			z = 0,
			vip = false,
			mult = 0,
			rideStars = 0,
			ridePassed = 0,
		}
		ride.people[id] = P
		table.insert(ride.order, id)
		table.insert(bots, id)
		emit(ride, { t = "bot", id = id, add = true, name = name, skill = skill })
	end
end

-------------------------------------------------------------------------------
-- Фазы
-------------------------------------------------------------------------------
local enterLobby, toCabin, openDoors, startFloor, endFloor, toRoof, startFall, goIdle

local function seatAll(ride)
	local i = 0
	for _, P in list(ride) do
		i += 1
		leaveBalcony(ride, P)
		local x, y, z = Ride.cabinSpot(i)
		tp(ride, P, "cabin", x, y, z)
	end
end

local function pickerState(ride)
	local n = 0
	for _, P in list(ride) do
		if P.where == "cabin" then
			n += 1
		end
	end
	local forced, why = ride.forced, "debug"
	if not forced and ride.basementBy and not ride.basementUsed then
		forced, why = "basement", "bought"
	end
	return {
		history = ride.history,
		n = n,
		bosses = ride.bosses,
		forced = forced,
		forcedWhy = why,
		basementUsed = ride.basementUsed,
	}
end

local function planStop(ride)
	ride.plan = Picker.plan(ride.stop, pickerState(ride), ride.rng)
	ride.votes = {}
	if ride.plan.kind == "surprise" then
		if ride.plan.id == ride.forced then
			ride.forced = nil
		end
		if ride.plan.why == "bought" then
			emit(ride, { t = "announce", key = "announce.basement", name = ride.basementBy })
		end
	end
end

function enterLobby(ride)
	for _, id in table.clone(ride.order) do
		if ride.people[id].bot then
			removeBot(ride, id)
		end
	end
	local st = newStage(ride, "lobby", {})
	local dur = if ride.firstLobby then R.FirstLobby else R.Lobby
	ride.firstLobby = false
	ride.floor, ride.floorId = nil, nil
	ride.stop = 0
	local i = 0
	for _, P in list(ride) do
		i += 1
		leaveBalcony(ride, P)
		local s = st.spawns[(i - 1) % #st.spawns + 1]
		tp(ride, P, "lobby", s[1], s[2], s[3])
	end
	setPhase(ride, "lobby", dur)
end

local function startRide(ride)
	ride.rideNo += 1
	ride.stats.rides += 1
	ride.stats.rideMaxBalcony = 0
	ride.stop = 0
	ride.history = {}
	ride.bosses = Picker.bossOrder(ride.rng)
	ride.basementUsed = false
	ride.holdUsed = false
	for _, P in list(ride) do
		P.rideStars, P.ridePassed, P.rideCoins = 0, 0, 0
	end
	toCabin(ride)
end

function toCabin(ride)
	fillBots(ride)
	seatAll(ride)
	ride.stop += 1
	planStop(ride)
	ride.cabinFx = nil
	if ride.rng:next() < R.CabinFxChance then
		local kinds = { "flicker", "shake", "sneeze" }
		ride.cabinFx =
			{ kind = kinds[ride.rng:int(1, #kinds)], at = ride.rng:range(2, R.Cabin - 2), done = false }
	end
	setPhase(ride, "cabin", R.Cabin)
end

function openDoors(ride)
	local id, k, sum
	if ride.plan.kind == "vote" then
		k, sum = Picker.tally(ride.plan.options, ride.votes, ride.rng)
		id = ride.plan.options[k].id
	else
		id = ride.plan.id
	end
	if id == "basement" then
		ride.basementUsed = true
		ride.basementBy = nil
	end
	table.insert(ride.history, id)
	-- звонок лифта: облик того, кто голосовал за этот этаж (иначе — случайного человека)
	local chimeBy = nil
	for who, v in ride.votes do
		if v.k == k and ride.people[who] then
			chimeBy = who
			break
		end
	end
	if not chimeBy then
		local hs = {}
		for _, P in list(ride, "cabin") do
			if not P.bot then
				table.insert(hs, P.id)
			end
		end
		chimeBy = if #hs > 0 then hs[ride.rng:int(1, #hs)] else nil
	end
	local roster = {}
	for _, P in list(ride, "cabin") do
		table.insert(roster, { id = P.id, name = P.name, bot = P.bot })
	end
	ride.floorId = id
	ride.floor = newStage(ride, id, roster)
	ride.stats.floors += 1
	emit(ride, {
		t = "doors",
		id = id,
		cat = Floors.get(id).cat,
		chosen = k,
		sum = sum,
		chime = chimeBy,
		why = ride.plan.kind == "surprise" and ride.plan.why or nil,
	})
	setPhase(ride, "doors", R.Doors)
end

function startFloor(ride)
	local inst = ride.floor
	for _, p in inst.list do
		local P = ride.people[p.id]
		if P then
			tp(ride, P, "floor", p.x, p.y, p.z, { exit = true })
			p.teleported = true
			-- память головы — своя на каждом этаже
			if P.mem then
				P.mem = Bots.mem(P.mem.level, ride.rng:int(1, 2 ^ 30))
			end
			if P.auto then
				P.auto = Bots.mem(P.auto.level, ride.rng:int(1, 2 ^ 30))
			end
		end
	end
	setPhase(ride, "floor", inst.duration + 5)
end

function endFloor(ride)
	local inst = ride.floor
	local rows = Floors.results(inst)
	local named = {}
	for _, r in rows do
		local P = ride.people[r.id]
		if P then
			r.name = P.name
			if not P.bot then
				local coins = math.floor(r.stars * Config.Rewards.CoinsPerStar * (P.mult or 1) + 1e-9)
				r.coins = coins
				P.rideStars += r.stars
				P.rideCoins = (P.rideCoins or 0) + coins
				if r.passed then
					P.ridePassed += 1
				end
				emit(ride, {
					t = "reward",
					id = r.id,
					floor = inst.id,
					stars = r.stars,
					passed = r.passed,
					top = r.top,
					clean = r.clean,
					place = r.place,
					score = r.score,
					coins = coins,
				})
			else
				P.rideStars += r.stars
			end
			table.insert(named, r)
		end
	end
	ride.lastRows = named
	emit(ride, { t = "floorEnd", id = inst.id, rows = named })
	setPhase(ride, "floorEnd", R.FloorEnd)
end

function toRoof(ride)
	local roster = {}
	for _, P in list(ride) do
		leaveBalcony(ride, P)
		table.insert(roster, { id = P.id, name = P.name, bot = P.bot })
	end
	local st = newStage(ride, "roof", roster)
	ride.floor, ride.floorId = nil, nil
	for _, p in st.list do
		local P = ride.people[p.id]
		tp(ride, P, "roof", p.x, p.y, p.z)
	end
	local rows = {}
	for _, P in list(ride) do
		local coins = 0
		if not P.bot then
			coins = math.floor(Config.Rewards.RideBonus * (P.mult or 1) + 1e-9)
			P.rideCoins = (P.rideCoins or 0) + coins
			emit(ride, {
				t = "rideReward",
				id = P.id,
				coins = coins,
				stars = P.rideStars,
				passed = P.ridePassed,
			})
		end
		table.insert(rows, {
			id = P.id,
			name = P.name,
			bot = P.bot,
			stars = P.rideStars,
			passed = P.ridePassed,
			coins = P.rideCoins or 0,
		})
	end
	table.sort(rows, function(a, b)
		if a.stars ~= b.stars then
			return a.stars > b.stars
		end
		return tostring(a.id) < tostring(b.id)
	end)
	emit(ride, { t = "rideEnd", rows = rows })
	setPhase(ride, "roof", R.Roof)
end

function startFall(ride)
	seatAll(ride)
	setPhase(ride, "fall", R.Fall)
end

function goIdle(ride)
	for _, id in table.clone(ride.order) do
		if ride.people[id].bot then
			removeBot(ride, id)
		end
	end
	ride.floor, ride.floorId, ride.stage = nil, nil, nil
	ride.plan = nil
	ride.phase = "idle"
	ride.phaseEnd = math.huge
	ride.firstLobby = true
	emit(ride, { t = "phase", phase = "idle" })
end

local function advance(ride)
	local ph = ride.phase
	if ph == "lobby" then
		startRide(ride)
	elseif ph == "cabin" then
		openDoors(ride)
	elseif ph == "doors" then
		startFloor(ride)
	elseif ph == "floor" then
		-- страховка: этаж не закончился сам
		ride.floor.over = true
		endFloor(ride)
	elseif ph == "floorEnd" then
		if ride.stop >= R.Stops then
			toRoof(ride)
		else
			toCabin(ride)
		end
	elseif ph == "roof" then
		startFall(ride)
	elseif ph == "fall" then
		enterLobby(ride)
	end
end

-------------------------------------------------------------------------------
-- Игроки
-------------------------------------------------------------------------------
--[[
	Человек вошёл. opts = { vip, mult } (mult — множитель монет: ×2 Монеты, VIP).
	Лобби/кабина — сразу туда; посреди этажа — на балкон, в кабину на ближайшей остановке.
]]
function Ride.join(ride, id, name: string, opts)
	if ride.people[id] then
		return ride.people[id]
	end
	opts = opts or {}
	local P = {
		id = id,
		name = name,
		bot = false,
		vip = opts.vip == true,
		mult = opts.mult or 1,
		where = "lobby",
		x = 0,
		y = 0,
		z = 0,
		rideStars = 0,
		ridePassed = 0,
		rideCoins = 0,
		joinedAt = ride.clock,
	}
	ride.people[id] = P
	table.insert(ride.order, id)
	local ph = ride.phase
	if ph == "idle" then
		enterLobby(ride)
	elseif ph == "lobby" then
		local s = ride.stage.spawns[(#ride.order - 1) % #ride.stage.spawns + 1]
		tp(ride, P, "lobby", s[1], s[2], s[3])
	elseif ph == "cabin" or ph == "fall" then
		local x, y, z = Ride.cabinSpot(#ride.order)
		tp(ride, P, "cabin", x, y, z)
	elseif ph == "roof" then
		local x, z = Config.Stage.Roof.x, Config.Stage.Roof.z
		tp(ride, P, "roof", x + ride.rng:range(-6, 6), 0, z + ride.rng:range(-4, 4))
	else
		toBalcony(ride, P, false)
	end
	return P
end

function Ride.leave(ride, id)
	local P = ride.people[id]
	if not P then
		return
	end
	if ride.floor and ride.floor.byId[id] then
		local p = ride.floor.byId[id]
		p.out, p.left = true, true
		p.outAt = p.outAt or ride.floor.t
	end
	ride.votes[id] = nil
	ride.people[id] = nil
	table.remove(ride.order, table.find(ride.order, id) :: number)
	if humans(ride) == 0 and ride.phase ~= "idle" then
		goIdle(ride)
	end
end

-- Множитель монет и VIP изменились (купил пропуск)
function Ride.setFlags(ride, id, vip: boolean, mult: number)
	local P = ride.people[id]
	if P then
		P.vip, P.mult = vip, mult
	end
end

-- Голос за кнопку k (только в кабине, только люди, во время голосования)
function Ride.vote(ride, id, k: number): boolean
	local P = ride.people[id]
	if ride.phase ~= "cabin" or not P or P.bot or P.where ~= "cabin" then
		return false
	end
	if not ride.plan or ride.plan.kind ~= "vote" or type(k) ~= "number" or not ride.plan.options[k] then
		return false
	end
	ride.votes[id] = { k = k, w = if P.vip then 2 else 1 }
	local _, sum = Ride.tallyNow(ride)
	emit(ride, { t = "votes", sum = sum })
	return true
end

function Ride.tallyNow(ride)
	local sum = {}
	for i = 1, #ride.plan.options do
		sum[i] = 0
	end
	for _, v in ride.votes do
		sum[v.k] += v.w
	end
	return nil, sum
end

-- Намерение на этаже (сесть, нажать, подарок). ok, why
function Ride.act(ride, id, a): (boolean, string?)
	local P = ride.people[id]
	if not P or ride.phase ~= "floor" or P.where ~= "floor" or not ride.floor then
		return false, "notNow"
	end
	return Floors.input(ride.floor, id, a)
end

-- Позиция человека (ноги, координаты сцены) — каждый шаг сервера
function Ride.setPos(ride, id, x: number, y: number, z: number)
	local P = ride.people[id]
	if not P then
		return
	end
	local dt = math.max(1e-3, ride.clock - (P.posAt or ride.clock - R.Step))
	P.posAt = ride.clock
	if P.where == "floor" and ride.floor and ride.phase == "floor" then
		Floors.setPos(ride.floor, id, x, y, z, dt)
		local p = ride.floor.byId[id]
		if p then
			P.x, P.y, P.z = p.x, p.y, p.z
		end
	else
		P.x, P.y, P.z = x, y, z
	end
end

-- Автопилот человека головой бота (тесты на заглушке, автоигра в Studio). nil — выключить
function Ride.setAuto(ride, id, level: string?)
	local P = ride.people[id]
	if P then
		P.auto = if level then Bots.mem(level, ride.rng:int(1, 2 ^ 30)) else nil
	end
end

-------------------------------------------------------------------------------
-- «Подвал сейчас!» и окно оплаты
-------------------------------------------------------------------------------
local function nextPlanStop(ride): number
	if ride.phase == "cabin" then
		return ride.stop
	elseif ride.phase == "lobby" or ride.phase == "idle" or ride.phase == "roof" or ride.phase == "fall" then
		return 1
	end
	return ride.stop + 1
end

-- Можно ли сейчас вызвать Подвал: раз за поездку и есть ещё обычная остановка
function Ride.canBasement(ride): (boolean, string?)
	if ride.phase == "idle" then
		return false, "notNow"
	end
	if ride.basementBy then
		return false, "pending"
	end
	local from = nextPlanStop(ride)
	local fresh = from == 1 and (ride.phase == "lobby" or ride.phase == "roof" or ride.phase == "fall")
	if ride.basementUsed and not fresh then
		return false, "used"
	end
	if ride.phase == "cabin" and ride.plan and ride.plan.why == "basement" then
		return false, "used"
	end
	for s = from, R.Stops do
		if not Picker.isBossStop(s) then
			return true, nil
		end
	end
	return false, "late"
end

-- Куплен «Подвал сейчас!»: следующий обычный этаж — Подвал для всех
function Ride.forceBasement(ride, name: string): (boolean, string?)
	local ok, why = Ride.canBasement(ride)
	if not ok then
		return false, why
	end
	ride.basementBy = name
	if ride.phase == "cabin" and not Picker.isBossStop(ride.stop) then
		planStop(ride)
	end
	return true, nil
end

-- Пока открыт промпт оплаты в кабине — продлить отсчёт (один раз за поездку)
function Ride.holdCabin(ride): boolean
	if ride.phase ~= "cabin" or ride.holdUsed then
		return false
	end
	ride.holdUsed = true
	ride.phaseEnd += R.PayHold
	emit(ride, { t = "phase", phase = "cabin" })
	return true
end

-------------------------------------------------------------------------------
-- Шаг
-------------------------------------------------------------------------------
function Ride.step(ride, now: number)
	local dt = math.clamp(now - ride.now, 0, R.MaxDt) * ride.speed
	ride.now = now
	ride.changes = {}
	if ride.phase == "idle" or dt <= 0 then
		return
	end
	ride.clock += dt
	if ride.phase == "cabin" and ride.cabinFx and not ride.cabinFx.done then
		if ride.clock - ride.phaseStart >= ride.cabinFx.at then
			ride.cabinFx.done = true
			emit(ride, { t = "cabinFx", kind = ride.cabinFx.kind })
		end
	end
	if ride.phase == "floor" and ride.floor then
		local inst = ride.floor
		for _, p in inst.list do
			local P = ride.people[p.id]
			if P and P.where == "floor" then
				local mem = P.mem or P.auto
				if mem then
					Floors.botStep(inst, p, mem, dt)
				end
			end
		end
		local finished = Floors.step(inst, dt)
		for _, e in Floors.drainEvents(inst) do
			if e.t == "out" then
				local P = ride.people[e.id]
				if P and P.where == "floor" then
					P.x, P.y, P.z = e.x, e.y, e.z
					toBalcony(ride, P, true)
				end
			else
				e.floorEvent = true
				emit(ride, e)
			end
		end
		for _, p in inst.list do
			local P = ride.people[p.id]
			if P and P.where == "floor" then
				P.x, P.y, P.z = p.x, p.y, p.z
			end
		end
		if finished then
			endFloor(ride)
		end
	end
	if ride.stage then
		if ride.stage.def.cat == "stage" and ride.stage.def.step then
			ride.stage.t += dt
			ride.stage.def.step(ride.stage, dt)
		end
		ride.changes = Kit.drainChanges(ride.stage)
		if ride.stage.pubRev ~= ride.lastPubRev then
			ride.lastPubRev = ride.stage.pubRev
			emit(ride, { t = "pub" })
		end
	end
	if ride.phase ~= "idle" and ride.clock >= ride.phaseEnd then
		advance(ride)
	end
end

-------------------------------------------------------------------------------
-- Вид для клиента
-------------------------------------------------------------------------------
function Ride.left(ride): number
	if ride.phaseEnd == math.huge then
		return 0
	end
	if ride.phase == "floor" and ride.floor then
		return math.max(0, (ride.floor.duration - ride.floor.t) / ride.speed)
	end
	return math.max(0, (ride.phaseEnd - ride.clock) / ride.speed)
end

function Ride.view(ride, id)
	local P = ride.people[id]
	local v = {
		phase = ride.phase,
		left = Ride.left(ride),
		stop = ride.stop,
		stops = R.Stops,
		rideNo = ride.rideNo,
		where = P and P.where,
		floor = nil :: string?,
		cat = nil :: string?,
		options = nil :: any,
		surprise = nil :: string?,
		votes = nil :: any,
		myVote = ride.votes[id] and ride.votes[id].k,
		people = {},
		basementBy = ride.basementBy,
		stars = P and P.rideStars or 0,
	}
	local ph = ride.phase
	if (ph == "doors" or ph == "floor" or ph == "floorEnd") and ride.floorId then
		v.floor = ride.floorId
		v.cat = Floors.get(ride.floorId).cat
	end
	if ph == "cabin" and ride.plan then
		if ride.plan.kind == "vote" then
			v.options = {}
			for _, o in ride.plan.options do
				table.insert(v.options, { cat = o.cat })
			end
			local _, sum = Ride.tallyNow(ride)
			v.votes = sum
		else
			v.surprise = ride.plan.why
		end
	end
	for _, pid in ride.order do
		local Q = ride.people[pid]
		table.insert(v.people, {
			id = Q.id,
			name = Q.name,
			bot = Q.bot,
			vip = Q.vip,
			where = Q.where,
			stars = Q.rideStars,
		})
	end
	return v
end

-------------------------------------------------------------------------------
-- Отладка: floor <id> | next | boss | basement | bots <n> | speed <x> | state
-------------------------------------------------------------------------------
function Ride.debug(ride, cmd: string, arg: string?): string
	if cmd == "state" then
		local parts = {
			string.format(
				"ride %d phase=%s stop=%d/%d left=%.1f",
				ride.rideNo,
				ride.phase,
				ride.stop,
				R.Stops,
				Ride.left(ride)
			),
		}
		if ride.floorId then
			table.insert(parts, "floor=" .. ride.floorId)
		end
		if ride.plan and ride.phase == "cabin" then
			if ride.plan.kind == "vote" then
				local o = {}
				for _, x in ride.plan.options do
					table.insert(o, x.cat .. ":" .. x.id)
				end
				table.insert(parts, "options=" .. table.concat(o, ","))
			else
				table.insert(parts, "surprise=" .. ride.plan.id .. "(" .. ride.plan.why .. ")")
			end
		end
		local ppl = {}
		for _, P in list(ride) do
			table.insert(
				ppl,
				string.format("%s%s@%s★%d", P.name, if P.bot then "(bot)" else "", P.where, P.rideStars)
			)
		end
		table.insert(parts, "people=" .. table.concat(ppl, " "))
		table.insert(parts, "history=" .. table.concat(ride.history, ","))
		table.insert(parts, string.format("speed=%.1f maxBalcony=%.1fs", ride.speed, ride.stats.maxBalcony))
		return table.concat(parts, " | ")
	elseif cmd == "floor" or cmd == "boss" or cmd == "basement" then
		local id = arg
		if cmd == "boss" then
			id = nil
			for _, b in Floors.Bosses do
				if not table.find(ride.history, b) then
					id = b
					break
				end
			end
			id = id or Floors.Bosses[1]
		elseif cmd == "basement" then
			id = "basement"
		end
		if not id or not Floors.get(id) or Floors.get(id).cat == "stage" then
			return "unknown floor " .. tostring(id)
		end
		ride.forced = id
		if ride.phase == "cabin" then
			ride.plan = { kind = "surprise", id = id, why = "debug" }
			ride.forced = nil
			ride.phaseEnd = ride.clock
		elseif ride.phase == "floor" and ride.floor then
			ride.floor.t = ride.floor.duration
		elseif ride.phase == "lobby" or ride.phase == "doors" or ride.phase == "floorEnd" then
			ride.phaseEnd = ride.clock
		end
		return "next floor: " .. id
	elseif cmd == "next" then
		if ride.phase == "floor" and ride.floor then
			ride.floor.t = ride.floor.duration
		else
			ride.phaseEnd = ride.clock
		end
		return "skip " .. ride.phase
	elseif cmd == "bots" then
		local n = tonumber(arg)
		ride.botTarget = if n then math.clamp(math.floor(n), 0, 11) else nil
		if ride.phase == "cabin" then
			fillBots(ride)
			seatAll(ride)
		end
		return "bots → " .. tostring(ride.botTarget or "auto")
	elseif cmd == "speed" then
		ride.speed = math.clamp(tonumber(arg) or 1, 0.25, 8)
		return "speed " .. ride.speed
	end
	return "unknown " .. tostring(cmd)
end

return Ride
