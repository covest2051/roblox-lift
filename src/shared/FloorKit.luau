--[[
	FloorKit — общие кирпичики модулей этажей (чистые функции, без инстансов).

	Деталь этажа — таблица-описание (её строит сервер из примитивов, тесты читают как есть):
	  { name, shape = "Block"|"Ball"|"Disc"|"Cylinder"|"Wedge", x, y, z (центр), sx, sy, sz,
	    ry (поворот вокруг Y, градусы), color = {r,g,b}, mat = "SmoothPlastic"|"Neon"|…,
	    alpha (прозрачность), collide (false — сквозь), solid (опора для тела бота),
	    ice, bounce (скорость отскока), slope = { y0, y1 } (верх по Z от y0 до y1), label }
	Изменения деталей копятся в inst.changes — сервер применяет их к миру.

	Игрок на этаже — тело (Body): x, y (ноги), z, vx, vy, vz, grounded, on (опора) +
	out, outAt, falls, score, finished, contrib.
]]

local Shared = script.Parent
local Config = require(Shared.Config)

local Kit = {}

local CELL = 8
local OFF = 4096

local function cellKey(cx: number, cz: number): number
	return (cx + OFF) * 8192 + (cz + OFF)
end

-------------------------------------------------------------------------------
-- Детали и опора
-------------------------------------------------------------------------------

local function footprint(s)
	local hx, hz
	if s.shape == "Disc" or s.shape == "Ball" then
		hx, hz = s.sx / 2, s.sx / 2
	else
		hx, hz = s.sx / 2, s.sz / 2
	end
	return s.x - hx, s.x + hx, s.z - hz, s.z + hz
end

local function index(inst, s)
	local x0, x1, z0, z1 = footprint(s)
	local cx0, cx1 = math.floor(x0 / CELL), math.floor(x1 / CELL)
	local cz0, cz1 = math.floor(z0 / CELL), math.floor(z1 / CELL)
	s._cells = { cx0, cx1, cz0, cz1 }
	for cx = cx0, cx1 do
		for cz = cz0, cz1 do
			local k = cellKey(cx, cz)
			local list = inst.cells[k]
			if not list then
				list = {}
				inst.cells[k] = list
			end
			table.insert(list, s)
		end
	end
end

local function unindex(inst, s)
	local c = s._cells
	if not c then
		return
	end
	for cx = c[1], c[2] do
		for cz = c[3], c[4] do
			local list = inst.cells[cellKey(cx, cz)]
			if list then
				local i = table.find(list, s)
				if i then
					table.remove(list, i)
				end
			end
		end
	end
	s._cells = nil
end

-- Добавить деталь. Возвращает её описание.
function Kit.part(inst, spec)
	assert(spec.name and not inst.parts[spec.name], "part name must be unique: " .. tostring(spec.name))
	spec.shape = spec.shape or "Block"
	spec.sz = spec.sz or spec.sx
	spec.sy = spec.sy or 1
	if spec.collide == nil then
		spec.collide = true
	end
	inst.parts[spec.name] = spec
	table.insert(inst.order, spec.name)
	if spec.solid then
		spec.alive = spec.alive ~= false
		index(inst, spec)
	end
	return spec
end

-- Деталь-опора (по ней ходят тела)
function Kit.solid(inst, spec)
	spec.solid = true
	return Kit.part(inst, spec)
end

-- Верх опоры в точке (x, z)
function Kit.topOf(s, x: number, z: number): number
	if s.slope then
		local z0, z1 = s.z - s.sz / 2, s.z + s.sz / 2
		local k = math.clamp((z - z0) / (z1 - z0), 0, 1)
		return s.slope[1] + (s.slope[2] - s.slope[1]) * k
	end
	if s.shape == "Ball" then
		local r = s.sx / 2
		local d2 = (x - s.x) ^ 2 + (z - s.z) ^ 2
		return s.y + math.sqrt(math.max(0, r * r - d2))
	end
	return s.y + s.sy / 2
end

local function inside(s, x: number, z: number): boolean
	if s.shape == "Disc" or s.shape == "Ball" then
		local r = s.sx / 2
		return (x - s.x) ^ 2 + (z - s.z) ^ 2 <= r * r
	end
	return math.abs(x - s.x) <= s.sx / 2 and math.abs(z - s.z) <= s.sz / 2
end

--[[
	Самая высокая опора под точкой, верх которой не выше maxY.
	Возвращает (верх, опора) или nil.
]]
function Kit.groundAt(inst, x: number, z: number, maxY: number)
	local list = inst.cells[cellKey(math.floor(x / CELL), math.floor(z / CELL))]
	if not list then
		return nil, nil
	end
	local best, bestS = nil, nil
	for _, s in list do
		if s.alive and s.collide and inside(s, x, z) then
			local top = Kit.topOf(s, x, z)
			if top <= maxY and (best == nil or top > best) then
				best, bestS = top, s
			end
		end
	end
	return best, bestS
end

-- Изменить деталь: свойства пишутся в описание и в очередь изменений для сервера
function Kit.set(inst, name: string, props: { [string]: any })
	local s = inst.parts[name]
	assert(s, "no part " .. name)
	local moved = false
	for k, v in props do
		if k == "x" or k == "z" or k == "sx" or k == "sz" then
			moved = moved or s[k] ~= v
		end
		s[k] = v
	end
	if moved and s.solid then
		unindex(inst, s)
		index(inst, s)
	end
	local ch = inst.pending[name]
	if not ch then
		ch = {}
		inst.pending[name] = ch
		table.insert(inst.changes, { name = name, props = ch })
	end
	for k, v in props do
		ch[k] = v
	end
end

-- Убрать/вернуть опору (плитка исчезла)
function Kit.vanish(inst, name: string, gone: boolean)
	local s = inst.parts[name]
	s.alive = not gone
	Kit.set(inst, name, { alpha = if gone then 1 else (s.baseAlpha or 0), collide = not gone })
	s.alive = not gone
end

-- Изменения за шаг (сервер забирает и применяет)
function Kit.drainChanges(inst)
	local out = inst.changes
	inst.changes = {}
	inst.pending = {}
	return out
end

-------------------------------------------------------------------------------
-- Игроки
-------------------------------------------------------------------------------

function Kit.active(inst): { any }
	local out = {}
	for _, p in inst.list do
		if not p.out then
			table.insert(out, p)
		end
	end
	return out
end

function Kit.activeCount(inst): number
	local n = 0
	for _, p in inst.list do
		if not p.out then
			n += 1
		end
	end
	return n
end

function Kit.event(inst, e)
	table.insert(inst.events, e)
end

-- Публичное состояние этажа изменилось (уйдёт клиентам)
function Kit.pub(inst, fields: { [string]: any })
	for k, v in fields do
		inst.pub[k] = v
	end
	inst.pubRev += 1
end

-- Выбыл: смешно улетает на мягкий балкон
function Kit.out(inst, p, reason: string)
	if p.out then
		return
	end
	if inst.t < Config.Floor.Grace then
		-- первые секунды никто не выбывает: ставим обратно
		Kit.respawn(inst, p, true)
		inst.graceSaves += 1
		return
	end
	p.out = true
	p.outAt = inst.t
	p.falls += 1
	p.vx, p.vy, p.vz = 0, 0, 0
	Kit.event(inst, { t = "out", id = p.id, reason = reason, x = p.x, y = p.y, z = p.z, at = inst.t })
end

-- Поставить на точку
function Kit.place(p, x: number, y: number, z: number)
	p.x, p.y, p.z = x, y, z
	p.vx, p.vy, p.vz = 0, 0, 0
	p.grounded = true
	p.teleported = true
end

-- Упал в гонке: обратно на чекпоинт (без выбывания), падение считается (free — не считать)
function Kit.respawn(inst, p, free: boolean?)
	local c = p.checkpoint or p.spawn
	Kit.place(p, c[1], c[2], c[3])
	if not free then
		p.falls += 1
	end
	Kit.event(inst, { t = "respawn", id = p.id, x = c[1], y = c[2], z = c[3] })
end

function Kit.dist2(ax: number, az: number, bx: number, bz: number): number
	return (ax - bx) ^ 2 + (az - bz) ^ 2
end

function Kit.near(p, x: number, z: number, r: number): boolean
	return (p.x - x) ^ 2 + (p.z - z) ^ 2 <= r * r
end

-- Опора под ногами человека (позиция пришла от сервера, не из Body)
function Kit.support(inst, p)
	local top, s = Kit.groundAt(inst, p.x, p.z, p.y + 0.7)
	if top and p.y - top < 0.8 then
		p.grounded, p.on = true, s
	else
		p.grounded, p.on = false, nil
	end
end

-- Точки появления: ряд у двери лифта по умолчанию
function Kit.spawnRow(inst, z: number, y: number, width: number?)
	local n = #inst.list
	local w = width or 24
	for i, p in inst.list do
		local x = if n == 1 then 0 else -w / 2 + w * (i - 1) / (n - 1)
		p.spawn = { x, y, z }
		Kit.place(p, x, y, z)
	end
end

-------------------------------------------------------------------------------
-- Голова бота: общие приёмы
-------------------------------------------------------------------------------

-- Выбрать: лучший (с ошибкой mem.err — любой), «наугад» — любой
function Kit.choose(mem, best, all)
	local list = all or {}
	if (mem.random or mem.rng:next() < (mem.err or 0)) and #list > 0 then
		return list[mem.rng:int(1, #list)]
	end
	return best
end

-- Идти к точке
function Kit.go(x: number, z: number, speed: number?, extra: { [string]: any }?)
	local it = { tx = x, tz = z, speed = speed or 1 }
	if extra then
		for k, v in extra do
			it[k] = v
		end
	end
	return it
end

-- Дальность прыжка (по горизонтали) на опору выше на dh при гравитации g; nil — не допрыгнуть
function Kit.reach(dh: number, g: number): number?
	local v = Config.Body.Jump
	local disc = v * v - 2 * g * dh
	if disc < 0 then
		return nil
	end
	local tLand = (v + math.sqrt(disc)) / g
	return Config.Body.Walk * tLand
end

-- Зазор от края своей опоры cur (или от точки me, если опоры нет) до края цели s
function Kit.gap(cur, me, s): number
	local rs = if s.shape == "Disc" or s.shape == "Ball" then s.sx / 2 else math.min(s.sx, s.sz) / 2
	if not cur then
		return math.sqrt((s.x - me.x) ^ 2 + (s.z - me.z) ^ 2) - rs
	end
	if cur.shape == "Disc" or cur.shape == "Ball" then
		return math.sqrt((s.x - cur.x) ^ 2 + (s.z - cur.z) ^ 2) - rs - cur.sx / 2
	end
	local qx = math.clamp(s.x, cur.x - cur.sx / 2, cur.x + cur.sx / 2)
	local qz = math.clamp(s.z, cur.z - cur.sz / 2, cur.z + cur.sz / 2)
	return math.sqrt((s.x - qx) ^ 2 + (s.z - qz) ^ 2) - rs
end

-- Случайная точка в прямоугольнике
function Kit.randomPoint(rng, x0: number, x1: number, z0: number, z1: number)
	return rng:range(x0, x1), rng:range(z0, z1)
end

-- Ближайшая из списка { {x=, z=}... } по условию
function Kit.nearest(p, list, filter: ((any) -> boolean)?)
	local best, bd = nil, math.huge
	for _, o in list do
		if not filter or filter(o) then
			local d = (o.x - p.x) ^ 2 + (o.z - p.z) ^ 2
			if d < bd then
				best, bd = o, d
			end
		end
	end
	return best, math.sqrt(bd)
end

return Kit
