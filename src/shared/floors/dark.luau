--[[
	🤝 Тёмный этаж. Темно, у каждого фонарик (клиент гасит свет и включает фонарь).
	Найдите и включите 5 рубильников вместе: подойти и «Нажать». Рубильник сам гаснет
	через 14 с — нужно, чтобы все 5 горели одновременно. Включены все 5 — прошли все.
	Место — по вкладу (сколько включил).
]]

local Kit = require(script.Parent.Parent.FloorKit)
local Config = require(script.Parent.Parent.Config)

local def = {
	id = "dark",
	cat = "coop",
	icon = "🔦",
	duration = 50,
	minPlayers = 1,
}

local D = {
	Switches = 5,
	Size = 76, -- сторона комнаты
	See = 12, -- фонарик освещает
	Hold = 14, -- рубильник сам выключается через (если не все 5 включены)
	Cell = 13, -- клетка «осмотрено» у бота
}
def.D = D

function def.build(inst)
	local rng = inst.rng
	inst.dark = true
	local h = D.Size / 2
	inst.bounds = { -h + 1, h - 1, 2, D.Size }
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = h + 1,
		sx = D.Size,
		sy = 1,
		sz = D.Size,
		color = { 50, 45, 60 },
		mat = "Slate",
	})
	for i = 1, 22 do
		local s = rng:range(2.5, 5)
		Kit.part(inst, {
			name = "Crate" .. i,
			x = rng:range(-h + 4, h - 4),
			y = s / 2,
			z = rng:range(12, D.Size - 4),
			sx = s,
			sy = s,
			sz = s,
			ry = rng:range(0, 90),
			color = { 120, 90, 60 },
			mat = "WoodPlanks",
		})
	end
	inst.switches = {}
	local tries = 0
	while #inst.switches < D.Switches and tries < 500 do
		tries += 1
		local x, z = rng:range(-h + 4, h - 4), rng:range(16, D.Size - 3)
		local ok = true
		for _, s in inst.switches do
			if (s.x - x) ^ 2 + (s.z - z) ^ 2 < 15 * 15 then
				ok = false
				break
			end
		end
		if ok then
			local k = #inst.switches + 1
			local sw = { k = k, x = x, z = z, on = false, name = "Switch" .. k }
			table.insert(inst.switches, sw)
			Kit.part(inst, {
				name = sw.name,
				x = x,
				y = 2,
				z = z,
				sx = 1.6,
				sy = 3,
				sz = 1,
				color = { 90, 30, 30 },
				mat = "Neon",
			})
			Kit.part(inst, {
				name = sw.name .. "Lamp",
				shape = "Ball",
				x = x,
				y = 4.2,
				z = z,
				sx = 1.2,
				color = { 120, 40, 40 },
				mat = "Neon",
				collide = false,
			})
		end
	end
	inst.lit = 0
	Kit.spawnRow(inst, 5, 0, 20)
	Kit.pub(inst, { lit = 0, total = #inst.switches, act = "press" })
end

function def.step(inst, _dt)
	if inst.lit >= #inst.switches then
		return
	end
	for _, sw in inst.switches do
		if sw.on and inst.t >= sw.offAt then
			sw.on = false
			inst.lit -= 1
			Kit.set(inst, sw.name, { color = { 90, 30, 30 } })
			Kit.set(inst, sw.name .. "Lamp", { color = { 120, 40, 40 }, light = 0 })
			Kit.event(inst, { t = "switchOff", k = sw.k })
			Kit.pub(inst, { lit = inst.lit })
		end
	end
end

function def.input(inst, p, a)
	if a.t ~= "press" then
		return false, "bad"
	end
	local sw = Kit.nearest(p, inst.switches, function(s)
		return not s.on
	end)
	if not sw or not Kit.near(p, sw.x, sw.z, Config.Floor.ActRange) then
		return false, "far"
	end
	sw.on = true
	sw.offAt = inst.t + D.Hold
	p.contrib += 1
	inst.lit += 1
	Kit.set(inst, sw.name, { color = { 80, 255, 120 } })
	Kit.set(inst, sw.name .. "Lamp", { color = { 120, 255, 160 }, light = 18 })
	Kit.event(inst, { t = "press", id = p.id, k = sw.k })
	Kit.pub(inst, { lit = inst.lit })
	return true, nil
end

function def.done(inst)
	return inst.lit >= #inst.switches
end

function def.passed(inst, p)
	return inst.lit >= #inst.switches and not p.out
end

function def.score(_inst, p)
	return p.contrib
end

-- Голова: осматривать комнату по клеткам; рубильник в луче фонаря — подойти и нажать
function def.bot(view, mem)
	local me = view.me
	local sws = view.switches
	mem.seen = mem.seen or {}
	local cx, cz = math.floor(me.x / D.Cell), math.floor(me.z / D.Cell)
	mem.seen[cx .. ":" .. cz] = true
	local target = nil
	for _, s in sws do
		if not s.on and Kit.near(me, s.x, s.z, D.See) then
			target = s
			break
		end
	end
	if target and not mem.random then
		if Kit.near(me, target.x, target.z, 3) then
			return { act = { t = "press" } }
		end
		return Kit.go(target.x, target.z, 1, { stop = 2 })
	end
	if mem.random then
		if target and Kit.near(me, target.x, target.z, 4) then
			return { act = { t = "press" } }
		end
		if not mem.goal or mem.rng:next() < 0.2 then
			local h = D.Size / 2
			mem.goal = { mem.rng:range(-h, h), mem.rng:range(4, D.Size) }
		end
		return Kit.go(mem.goal[1], mem.goal[2], 1)
	end
	-- следующая неосмотренная клетка (ближайшая; с ошибкой — любая)
	if mem.goal and not mem.seen[mem.goalKey] then
		return Kit.go(mem.goal[1], mem.goal[2], 1)
	end
	local h = D.Size / 2
	local best, bd, all = nil, math.huge, {}
	for gx = math.floor(-h / D.Cell), math.floor((h - 1) / D.Cell) do
		for gz = 0, math.floor((D.Size - 1) / D.Cell) do
			local key = gx .. ":" .. gz
			if not mem.seen[key] then
				local x, z = (gx + 0.5) * D.Cell, (gz + 0.5) * D.Cell
				x = math.clamp(x, -h + 2, h - 2)
				local c = { x, z, key }
				table.insert(all, c)
				local d = (x - me.x) ^ 2 + (z - me.z) ^ 2
				if d < bd then
					best, bd = c, d
				end
			end
		end
	end
	local pick = Kit.choose(mem, best, all)
	if not pick then
		mem.seen = {}
		return {}
	end
	mem.goal, mem.goalKey = pick, pick[3]
	return Kit.go(pick[1], pick[2], 1)
end

-- Видно только то, что в луче фонаря, и уже включённые рубильники
function def.view(inst, p, v)
	local vis = {}
	for _, s in inst.switches do
		if s.on or Kit.near(p, s.x, s.z, D.See) then
			table.insert(vis, s)
		end
	end
	v.switches = vis
end

return def
