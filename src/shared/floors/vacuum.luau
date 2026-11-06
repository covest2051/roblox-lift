--[[
	👑 Босс: Робот-пылесос. Огромный пылесос гоняется за ближайшим и «засасывает» на балкон
	(всё быстрее). На краю три выключателя: нажмите все три почти одновременно (каждый
	держится 4 с) — пылесос ломается и все оставшиеся прошли. Не сломали — прошли выжившие.
	Место — по вкладу (нажатия, засчитанные в поломку, и время).
]]

local Kit = require(script.Parent.Parent.FloorKit)
local Config = require(script.Parent.Parent.Config)

local def = {
	id = "vacuum",
	cat = "boss",
	icon = "🤖",
	duration = 60,
	minPlayers = 1,
}

local V = {
	R = 30, -- радиус арены
	Body = 5, -- радиус пылесоса
	Speed = { 8.5, 13 }, -- скорость: в начале … в конце
	Turn = 2.2, -- рад/с — поворачивает не мгновенно
	Window = 4, -- выключатель держится
	SwitchR = 26,
	Wake = 5, -- просыпается (первые секунды — разбежаться)
}
def.V = V

function def.build(inst)
	local cz = 6 + V.R
	inst.cz = cz
	inst.bounds = { -V.R + 1, V.R - 1, 7, 6 + 2 * V.R - 1 }
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = cz,
		sx = 2 * V.R + 2,
		sy = 1,
		sz = 2 * V.R + 2,
		color = { 220, 220, 230 },
		mat = "Marble",
	})
	Kit.part(inst, {
		name = "Carpet",
		shape = "Disc",
		x = 0,
		y = 0.05,
		z = cz,
		sx = 30,
		sy = 0.1,
		color = { 180, 70, 70 },
		mat = "Fabric",
		collide = false,
	})
	inst.switches = {}
	for k = 1, 3 do
		local a = math.pi / 2 + (k - 1) * 2 * math.pi / 3
		local sw = {
			k = k,
			name = "Switch" .. k,
			x = math.cos(a) * V.SwitchR,
			z = cz + math.sin(a) * V.SwitchR,
			onUntil = 0,
			by = nil,
		}
		table.insert(inst.switches, sw)
		Kit.part(inst, {
			name = sw.name .. "Post",
			x = sw.x,
			y = 1.5,
			z = sw.z,
			sx = 2,
			sy = 3,
			sz = 2,
			color = { 90, 90, 100 },
			mat = "Metal",
		})
		Kit.part(inst, {
			name = sw.name,
			x = sw.x,
			y = 3.4,
			z = sw.z,
			sx = 1.6,
			sy = 0.8,
			sz = 1.6,
			color = { 200, 40, 40 },
			mat = "Neon",
		})
	end
	inst.robot = { x = 0, z = cz, a = -math.pi / 2, broken = false }
	Kit.part(inst, {
		name = "Robot",
		shape = "Disc",
		x = 0,
		y = 1.2,
		z = cz,
		sx = 2 * V.Body,
		sy = 2.4,
		color = { 60, 60, 70 },
		mat = "Metal",
		collide = false,
	})
	Kit.part(inst, {
		name = "RobotTop",
		shape = "Disc",
		x = 0,
		y = 2.6,
		z = cz,
		sx = 2 * V.Body - 2,
		sy = 0.4,
		color = { 90, 200, 255 },
		mat = "Neon",
		collide = false,
	})
	Kit.part(inst, {
		name = "RobotEye",
		shape = "Ball",
		x = 0,
		y = 2.2,
		z = cz - V.Body,
		sx = 1.4,
		color = { 255, 60, 60 },
		mat = "Neon",
		collide = false,
	})
	Kit.spawnRow(inst, 9, 0, 24)
	Kit.pub(inst, { on = 0, broken = false, act = "press" })
end

local function onCount(inst): number
	local n = 0
	for _, sw in inst.switches do
		if inst.t < sw.onUntil then
			n += 1
		end
	end
	return n
end

function def.step(inst, dt)
	local t = inst.t
	local r = inst.robot
	if r.broken then
		return
	end
	-- выключатели гаснут
	for _, sw in inst.switches do
		if sw.lit and t >= sw.onUntil then
			sw.lit = false
			Kit.set(inst, sw.name, { color = { 200, 40, 40 } })
			Kit.pub(inst, { on = onCount(inst) })
		end
	end
	if t < V.Wake then
		return
	end
	local target, td = nil, math.huge
	for _, p in inst.list do
		if not p.out then
			local d = (p.x - r.x) ^ 2 + (p.z - r.z) ^ 2
			if d < td then
				target, td = p, d
			end
		end
	end
	if target then
		local want = math.atan2(target.z - r.z, target.x - r.x)
		local da = (want - r.a + math.pi) % (2 * math.pi) - math.pi
		r.a += math.clamp(da, -V.Turn * dt, V.Turn * dt)
		local k = math.clamp((t - V.Wake) / (inst.duration - V.Wake), 0, 1)
		local sp = V.Speed[1] + (V.Speed[2] - V.Speed[1]) * k
		r.x += math.cos(r.a) * sp * dt
		r.z += math.sin(r.a) * sp * dt
		local dr = math.sqrt(r.x ^ 2 + (r.z - inst.cz) ^ 2)
		if dr > V.R - V.Body then
			r.x *= (V.R - V.Body) / dr
			r.z = inst.cz + (r.z - inst.cz) * (V.R - V.Body) / dr
		end
	end
	Kit.set(inst, "Robot", { x = r.x, z = r.z })
	Kit.set(inst, "RobotTop", { x = r.x, z = r.z })
	Kit.set(inst, "RobotEye", { x = r.x + math.cos(r.a) * V.Body, z = r.z + math.sin(r.a) * V.Body })
	for _, p in inst.list do
		if not p.out and (p.x - r.x) ^ 2 + (p.z - r.z) ^ 2 < (V.Body + 0.8) ^ 2 and p.y < 4 then
			Kit.out(inst, p, "vacuum")
		end
	end
end

function def.input(inst, p, a)
	if a.t ~= "press" then
		return false, "bad"
	end
	local r = inst.robot
	if r.broken then
		return false, "notNow"
	end
	local sw = Kit.nearest(p, inst.switches)
	if not sw or not Kit.near(p, sw.x, sw.z, Config.Floor.ActRange) then
		return false, "far"
	end
	sw.onUntil = inst.t + V.Window
	sw.lit = true
	sw.by = p.id
	Kit.set(inst, sw.name, { color = { 80, 255, 120 } })
	p.score += 1
	local n = onCount(inst)
	Kit.pub(inst, { on = n })
	if n >= 3 then
		r.broken = true
		for _, s in inst.switches do
			local q = inst.byId[s.by]
			if q then
				q.contrib += 5
			end
		end
		Kit.set(inst, "RobotTop", { color = { 255, 120, 40 } })
		Kit.set(inst, "RobotEye", { color = { 80, 80, 80 } })
		Kit.event(inst, { t = "broken" })
		Kit.pub(inst, { broken = true })
		inst.endAt = inst.t + 2
	end
	return true, nil
end

function def.done(inst)
	return inst.endAt ~= nil and inst.t >= inst.endAt
end

function def.score(_inst, p)
	return p.contrib + p.score * 0.5 + (if p.out then (p.outAt or 0) / 60 else 2)
end

-- Голова: свой выключатель по порядку (первые трое живых); рядом пылесос — убегать
function def.bot(view, mem)
	local me = view.me
	local r = view.robot
	local cz = view.cz
	local dx, dz = me.x - r.x, me.z - r.z
	local dr = math.sqrt(dx * dx + dz * dz)
	local function flee()
		-- из 12 направлений — то, где через секунду дальше всего от пылесоса и не у стены
		local best, bv = nil, -math.huge
		for k = 0, 11 do
			local a = k * math.pi / 6
			local tx, tz = me.x + math.cos(a) * 10, me.z + math.sin(a) * 10
			local rr = math.sqrt(tx * tx + (tz - cz) ^ 2)
			local v = math.sqrt((tx - r.x) ^ 2 + (tz - r.z) ^ 2) - math.max(0, rr - (V.R - 6)) * 3
			if v > bv then
				best, bv = { tx, tz }, v
			end
		end
		return Kit.go(best[1], best[2], 1)
	end
	-- путь мимо пылесоса: если прямая проходит рядом с ним — через точку сбоку
	local function route(tx, tz)
		local ux, uz = tx - me.x, tz - me.z
		local L = math.max(0.01, math.sqrt(ux * ux + uz * uz))
		ux, uz = ux / L, uz / L
		local along = (r.x - me.x) * ux + (r.z - me.z) * uz
		local px, pz = me.x + ux * along, me.z + uz * along
		if along > 0 and along < L and (px - r.x) ^ 2 + (pz - r.z) ^ 2 < 12 * 12 then
			local side = if (r.x - me.x) * uz - (r.z - me.z) * ux > 0 then -1 else 1
			return Kit.go(px + uz * side * 14, pz - ux * side * 14, 1)
		end
		return Kit.go(tx, tz, 1, { stop = 1.5 })
	end
	if view.t < 3 then
		return {}
	end
	local danger = if mem.level == "novice" then 14 else 13
	if dr < danger and (not mem.random or mem.rng:next() < 0.35) then
		return flee()
	end
	-- роль: выключатели делят ближайшие (жадно: самая короткая пара — первой)
	local pairs_ = {}
	for _, p in view.list do
		if not p.out then
			for _, s in view.switches do
				table.insert(pairs_, { p = p, s = s, d = (p.x - s.x) ^ 2 + (p.z - s.z) ^ 2 })
			end
		end
	end
	table.sort(pairs_, function(a, b)
		return a.d < b.d
	end)
	local usedP, usedS, sw = {}, {}, nil
	for _, q in pairs_ do
		if not usedP[q.p] and not usedS[q.s] then
			usedP[q.p], usedS[q.s] = true, true
			if q.p == me then
				sw = q.s
			end
		end
	end
	if mem.random then
		if not mem.goal or mem.rng:next() < 0.25 then
			local s = view.switches[mem.rng:int(1, 3)]
			mem.goal = s
		end
		if Kit.near(me, mem.goal.x, mem.goal.z, 3) and mem.rng:next() < 0.5 then
			return { act = { t = "press" } }
		end
		return route(mem.goal.x, mem.goal.z)
	end
	if not sw then
		-- лишний: держаться подальше от пылесоса
		if dr < 16 then
			return flee()
		end
		return Kit.go(-r.x * 0.5, cz - (r.z - cz) * 0.5, 0.6)
	end
	if not Kit.near(me, sw.x, sw.z, 3) then
		return route(sw.x, sw.z)
	end
	-- все на местах? (видно, кто стоит у выключателей) — жать
	local ready = 0
	for _, s in view.switches do
		for _, p in view.list do
			if not p.out and Kit.near(p, s.x, s.z, 4.5) then
				ready += 1
				break
			end
		end
	end
	local alive = 0
	for _, p in view.list do
		if not p.out then
			alive += 1
		end
	end
	if ready >= math.min(3, alive) or view.t > view.duration - 10 or mem.rng:next() < mem.err then
		if view.t >= sw.onUntil - 1 then
			return { act = { t = "press" } }
		end
	end
	return {}
end

function def.view(inst, _p, v)
	v.robot = inst.robot
	v.switches = inst.switches
	v.cz = inst.cz
end

return def
