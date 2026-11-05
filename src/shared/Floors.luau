--[[
	Floors — реестр этажей и общий «движок» этажа. Каждый этаж — модуль floors/<id>.luau
	с одинаковым интерфейсом (шаблон и шаги — docs/NEW_FLOOR.md):

	  id, cat ("fire"|"race"|"brain"|"coop"|"calm"|"boss"|"secret"), icon, duration (с),
	  minPlayers, rare (шанс сюрприз-остановки, только редкие), ranked (false — без топ-3),
	  respawn (гонка: упал — на чекпоинт, не выбыл), freeze (первые 3 с все стоят — «на старт»),
	  speedMul (inst.speedMul — множитель скорости ходьбы на этаже, сервер ставит WalkSpeed),
	  build(inst)          — детали из примитивов (Kit.part/solid), inst.bounds, точки появления;
	                         случайность — только inst.rng, игроки — inst.list;
	  start(inst)?         — после build;
	  step(inst, dt)       — правила; время — inst.t (с начала этажа, по GetServerTimeNow сервера);
	  input(inst, p, a)?   — намерение игрока (сесть, нажать): проверка расстояния и времени;
	  done(inst)?          — закончить раньше (все финишировали, задача выполнена);
	  passed(inst, p)?     — прошёл ли (по умолчанию — не выбыл);
	  score(inst, p)?      — очки для места (по умолчанию — время на этаже);
	  view(inst, p, v)?    — что добавить в вид бота (только то, что видно игроку);
	  bot(view, mem)       — голова бота: намерение { tx, tz | mx, mz, speed, jump, act, stop }.

	Этаж не знает про Roblox: сервер строит детали, применяет изменения (inst.changes),
	подставляет позиции людей (setPos), а боты и тесты двигают тела через Body.
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Rng = require(Shared.Rng)
local Kit = require(Shared.FloorKit)
local Body = require(Shared.Body)

local Floors = {}

Floors.Kit = Kit

Floors.Categories = { "fire", "race", "brain", "coop", "calm" }
Floors.CatIcon = {
	fire = "🔥",
	race = "🏁",
	brain = "🧠",
	coop = "🤝",
	calm = "😌",
	boss = "👑",
	secret = "❓",
	stage = "🛗",
}

-- Порядок коллекции (16 + 2 босса + 1 секретный)
Floors.Order = {
	"lava",
	"melt",
	"bowling",
	"colors",
	"gravity",
	"mirror",
	"bubbles",
	"ice",
	"truth",
	"library",
	"chairs",
	"dark",
	"cake",
	"penguins",
	"chicken",
	"cafe",
	"vacuum",
	"soapboss",
	"basement",
}
-- Сцены, не этажи: лобби и крыша
Floors.Stages = { "lobby", "roof" }

Floors.defs = {} :: { [string]: any }
local folder = Shared:WaitForChild("floors")
for _, id in Floors.Order do
	local def = require(folder:FindFirstChild(id) :: any)
	assert(def.id == id, "floor module id mismatch: " .. id)
	Floors.defs[id] = def
end
for _, id in Floors.Stages do
	Floors.defs[id] = require(folder:FindFirstChild(id) :: any)
end

function Floors.get(id: string)
	return Floors.defs[id]
end

-- Списки для подбора
Floors.Regular = {} -- обычные, в голосовании
Floors.Rare = {} -- сюрприз-остановки
Floors.Bosses = {}
for _, id in Floors.Order do
	local d = Floors.defs[id]
	if d.cat == "boss" then
		table.insert(Floors.Bosses, id)
	elseif d.cat == "secret" then
		continue
	elseif d.rare then
		table.insert(Floors.Rare, id)
	else
		table.insert(Floors.Regular, id)
	end
end

--[[
	Новый этаж. opts = { seed, roster = { { id, name, bot } } }.
]]
function Floors.new(id: string, opts)
	local def = Floors.defs[id]
	assert(def, "unknown floor " .. tostring(id))
	local inst = {
		def = def,
		id = id,
		rng = Rng.new(opts.seed or 1),
		t = 0,
		duration = def.duration or 45,
		parts = {},
		order = {},
		cells = {},
		changes = {},
		pending = {},
		events = {},
		pub = { rev = 0 },
		pubRev = 0,
		list = {},
		byId = {},
		gravity = Config.Body.Gravity,
		killY = Config.Floor.KillY,
		bounds = nil :: { number }?,
		mirror = false,
		dark = false,
		over = false,
		graceSaves = 0,
	}
	for _, r in opts.roster or {} do
		local p = Body.init({
			id = r.id,
			name = r.name,
			bot = r.bot == true,
			out = false,
			falls = 0,
			score = 0,
			contrib = 0,
			spd = 0,
		}, 0, 0, 6)
		table.insert(inst.list, p)
		inst.byId[r.id] = p
	end
	if def.freeze then
		inst.freeze = Config.Floor.Grace -- гонки: «на старт» — все стоят первые 3 с
	end
	def.build(inst)
	for _, p in inst.list do
		if not p.spawn then
			p.spawn = { p.x, p.y, p.z }
		end
		p.checkpoint = p.spawn
	end
	if def.start then
		def.start(inst)
	end
	return inst
end

-- Позиция человека (ноги) от сервера. Для правил движение ограничено скоростью (анти-чит).
function Floors.setPos(inst, id, x: number, y: number, z: number, dt: number)
	local p = inst.byId[id]
	if not p or p.out then
		return
	end
	local F = Config.Floor
	if p.teleported then
		-- сервер только что сам поставил игрока: принимаем, если рядом с точкой
		if (x - p.x) ^ 2 + (z - p.z) ^ 2 < 36 then
			p.teleported = nil
		end
		return
	end
	local dx, dz = x - p.x, z - p.z
	local d = math.sqrt(dx * dx + dz * dz)
	local maxD = F.MaxSpeed * dt + 0.5
	if d > maxD then
		dx, dz = dx / d * maxD, dz / d * maxD
		d = maxD
		p.clamped = (p.clamped or 0) + 1
	end
	local dy = y - p.y
	local maxUp = F.MaxRise * dt + 0.5
	if dy > maxUp then
		dy = maxUp
	end
	p.vx, p.vz = dx / math.max(dt, 1e-3), dz / math.max(dt, 1e-3)
	p.vy = dy / math.max(dt, 1e-3)
	p.spd = d / math.max(dt, 1e-3)
	p.x, p.y, p.z = p.x + dx, p.y + dy, p.z + dz
	Kit.support(inst, p)
end

-- Вид для головы бота: только то, что видит игрок (+ def.view)
function Floors.view(inst, p)
	local v = {
		t = inst.t,
		me = p,
		list = inst.list,
		parts = inst.parts,
		pub = inst.pub,
		mirror = inst.mirror,
		gravity = inst.gravity,
		duration = inst.duration,
		inst = nil,
	}
	if inst.def.view then
		inst.def.view(inst, p, v)
	end
	return v
end

-- Шаг бота (или автопилота человека в тестах): голова → тело
function Floors.botStep(inst, p, mem, dt: number)
	if p.out or mem.idle then
		if not p.out then
			Body.step(p, {}, dt, inst)
			p.spd = 0
		end
		return
	end
	if inst.t >= mem.next then
		mem.next = inst.t + mem.think * (0.8 + 0.4 * mem.rng:next())
		local it = inst.def.bot(Floors.view(inst, p), mem) or {}
		mem.intent = it
		mem.aim = (mem.rng:next() * 2 - 1) * (mem.jitter or 0)
		mem.look = 0.12 + (mem.rng:next() * 2 - 1) * (mem.lookErr or 0)
		if it.act then
			Floors.input(inst, p.id, it.act)
			it.act = nil
		end
	end
	local it = mem.intent
	local mx, mz = it.mx or 0, it.mz or 0
	if it.track then
		-- цель, которая уточняется каждый шаг (следующий пузырь, убегающий пингвин)
		it.tx, it.tz = it.track(p)
	end
	if it.tx then
		local dx, dz = it.tx - p.x, it.tz - p.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < (it.stop or 0.5) then
			mx, mz = 0, 0
		else
			local sp = (it.speed or 1) * Config.Body.Walk
			local k = math.min(it.speed or 1, d / math.max(sp * dt, 1e-3) * (it.speed or 1))
			mx, mz = dx / d * k, dz / d * k
		end
	elseif it.speed and (mx ~= 0 or mz ~= 0) then
		local m = math.sqrt(mx * mx + mz * mz)
		mx, mz = mx / m * it.speed, mz / m * it.speed
	end
	if mem.aim ~= 0 and (mx ~= 0 or mz ~= 0) then
		local c, s = math.cos(mem.aim), math.sin(mem.aim)
		mx, mz = mx * c - mz * s, mx * s + mz * c
	end
	local jump = it.jump
	if it.jumpNear and p.grounded and it.tx and (p.x - it.tx) ^ 2 + (p.z - it.tz) ^ 2 < it.jumpNear ^ 2 then
		jump = true
	end
	if it.edgeJump and p.grounded and not jump and (mx ~= 0 or mz ~= 0) then
		-- прыжок у края: впереди нет опоры на этой высоте
		local la = mem.look or 0.12
		local lx = p.x + mx * Config.Body.Walk * la
		local lz = p.z + mz * Config.Body.Walk * la
		local top = Kit.groundAt(inst, lx, lz, p.y + 0.5)
		if not top or top < p.y - 1.5 then
			jump = true
		end
	end
	if inst.mirror and mem.mirrorFix then
		mx = -mx
	end
	Body.step(p, { mx = mx, mz = mz, jump = jump }, dt, inst)
	p.spd = math.sqrt(p.vx * p.vx + p.vz * p.vz)
	if it.jumpOnce and not p.grounded then
		it.jump, it.jumpOnce = nil, nil
	end
end

-- Намерение игрока (сесть, нажать, …). Возвращает ok, why
function Floors.input(inst, id, a): (boolean, string?)
	local p = inst.byId[id]
	if not p or p.out or inst.over or type(a) ~= "table" or not inst.def.input then
		return false, "no"
	end
	return inst.def.input(inst, p, a)
end

-- Шаг правил. true — этаж окончен
function Floors.step(inst, dt: number): boolean
	if inst.over then
		return true
	end
	inst.t += dt
	inst.def.step(inst, dt)
	for _, p in inst.list do
		if not p.out and p.y < inst.killY then
			if inst.t < Config.Floor.Grace then
				Kit.respawn(inst, p, true)
			elseif inst.def.respawn then
				Kit.respawn(inst, p)
			else
				Kit.out(inst, p, "fall")
			end
		end
	end
	local def = inst.def
	if inst.t >= inst.duration or Kit.activeCount(inst) == 0 or (def.done and def.done(inst)) then
		inst.over = true
		inst.endT = inst.t
		if def.finish then
			def.finish(inst)
		end
	end
	return inst.over
end

function Floors.drainEvents(inst)
	local e = inst.events
	inst.events = {}
	return e
end

-- Что клиент видит про этаж (табло, счётчики) — без скрытого
function Floors.public(inst)
	local out = table.clone(inst.pub)
	out.rev = inst.pubRev
	out.id = inst.id
	out.t = inst.t
	out.duration = inst.duration
	return out
end

--[[
	Итоги: { { id, passed, score, falls, place, top, clean, stars } } по местам.
	Звёзды: прошёл = 1, топ-3 среди прошедших = +1 (если этаж с местами), без падений = +1.
]]
function Floors.results(inst)
	local def = inst.def
	local rows = {}
	for _, p in inst.list do
		local passed
		if def.passed then
			passed = def.passed(inst, p)
		else
			passed = not p.out
		end
		local score
		if def.score then
			score = def.score(inst, p)
		else
			score = if p.out then p.outAt or 0 else (inst.endT or inst.t)
		end
		table.insert(
			rows,
			{ id = p.id, bot = p.bot, passed = passed == true, score = score, falls = p.falls }
		)
	end
	for _, r in rows do
		local better = 0
		for _, o in rows do
			if (o.passed and not r.passed) or (o.passed == r.passed and o.score > r.score + 1e-9) then
				better += 1
			end
		end
		r.place = better + 1
		r.top = r.passed and def.ranked ~= false and r.place <= 3
		r.clean = r.passed and r.falls == 0
		r.stars = (if r.passed then 1 else 0) + (if r.top then 1 else 0) + (if r.clean then 1 else 0)
	end
	table.sort(rows, function(a, b)
		if a.place ~= b.place then
			return a.place < b.place
		end
		return tostring(a.id) < tostring(b.id)
	end)
	return rows
end

return Floors
