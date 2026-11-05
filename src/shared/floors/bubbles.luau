--[[
	🏁 Пузыри. Высокий зал: пузыри-батуты подбрасывают вверх — допрыгай до кнопки под
	потолком. Упал на пол — начинай снизу (падение считается). Пузыри покачиваются.
	Прошёл — нажал кнопку. Место — по времени финиша.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "bubbles",
	cat = "race",
	icon = "🫧",
	duration = 50,
	minPlayers = 1,
	freeze = true,
}

local U = {
	Bounce = 72, -- скорость отскока от пузыря (≈13 studs вверх)
	Step = 5.5, -- пузыри выше друг друга на
	Count = 12,
	D = 7, -- диаметр пузыря
}
def.U = U

function def.build(inst)
	local rng = inst.rng
	inst.bounds = { -24, 24, 2, 50 }
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = 26,
		sx = 48,
		sy = 1,
		sz = 48,
		color = { 150, 210, 240 },
		mat = "SmoothPlastic",
	})
	inst.path = {}
	-- спираль вверх вокруг центра зала
	local ang = rng:range(0, math.pi * 2)
	for i = 1, U.Count do
		ang += rng:range(0.6, 0.9)
		local r = 7 + (i % 2) * 2
		local x, z = math.cos(ang) * r, 28 + math.sin(ang) * r
		local top = 2 + (i - 1) * U.Step
		local s = Kit.solid(inst, {
			name = "Bubble" .. i,
			shape = "Disc",
			x = x,
			y = top - 0.5,
			z = z,
			sx = U.D,
			sy = 1,
			color = { 170, 230, 255 },
			mat = "Glass",
			alpha = 0.35,
			bounce = U.Bounce,
		})
		s.k = i
		s.base = top - 0.5
		s.phase = rng:range(0, math.pi * 2)
		table.insert(inst.path, s)
		Kit.part(inst, {
			name = "Shine" .. i,
			shape = "Ball",
			x = x,
			y = top + 1.5,
			z = z,
			sx = U.D,
			color = { 200, 240, 255 },
			mat = "Glass",
			alpha = 0.6,
			collide = false,
		})
	end
	local last = inst.path[#inst.path]
	local ledgeTop = last.y + 0.5 + U.Step
	local lx, lz = last.x * 0.4, 28 + (last.z - 28) * 0.4
	inst.ledge = Kit.solid(inst, {
		name = "Ledge",
		x = lx,
		y = ledgeTop - 1,
		z = lz,
		sx = 8,
		sy = 2,
		sz = 8,
		color = { 255, 205, 70 },
	})
	Kit.part(inst, {
		name = "Button",
		shape = "Disc",
		x = lx,
		y = ledgeTop + 0.3,
		z = lz,
		sx = 3,
		sy = 0.6,
		color = { 255, 60, 80 },
		mat = "Neon",
	})
	Kit.part(inst, {
		name = "Ceiling",
		x = 0,
		y = ledgeTop + 14,
		z = 26,
		sx = 48,
		sy = 1,
		sz = 48,
		color = { 220, 240, 255 },
		collide = false,
	})
	-- батут у пола: первый подскок
	Kit.solid(inst, {
		name = "Pad",
		shape = "Disc",
		x = 0,
		y = 0.25,
		z = 14,
		sx = 8,
		sy = 0.5,
		color = { 255, 120, 180 },
		mat = "Neon",
		bounce = U.Bounce * 0.75,
	})
	Kit.spawnRow(inst, 6, 0, 16)
	for _, p in inst.list do
		p.best = 0
	end
	Kit.pub(inst, { height = math.floor(ledgeTop) })
end

function def.step(inst, _dt)
	local t = inst.t
	for _, s in inst.path do
		local y = s.base + math.sin(t * 1.3 + s.phase) * 0.6
		s.x0 = s.x0 or s.x
		local x = s.x0 + math.sin(t * 0.7 + s.phase * 2) * 1.6
		Kit.set(inst, s.name, { x = x, y = y })
		Kit.set(inst, "Shine" .. s.k, { x = x, y = y + 2 })
	end
	local L = inst.ledge
	for _, p in inst.list do
		if not p.out and not p.finished then
			local on = p.on
			if on and on.k then
				p.best = math.max(p.best, on.k)
			end
			-- касание пузыря снизу у людей видно по высоте над ним
			for _, s in inst.path do
				if s.k > p.best and math.abs(p.y - (s.y + 0.5)) < 1 and Kit.near(p, s.x, s.z, U.D / 2) then
					p.best = s.k
				end
			end
			if p.grounded and on and on.name == "Floor" and p.best > 2 then
				p.best = 0
				p.falls += 1
				Kit.event(inst, { t = "fell", id = p.id })
			end
			if p.grounded and on == L and Kit.near(p, L.x, L.z, 4) then
				p.finished = t
				Kit.event(inst, { t = "finish", id = p.id, at = t })
			end
		end
	end
end

function def.done(inst)
	for _, p in inst.list do
		if not p.out and not p.finished then
			return false
		end
	end
	return true
end

function def.passed(_inst, p)
	return p.finished ~= nil
end

function def.score(inst, p)
	if p.finished then
		return 100 + inst.duration - p.finished
	end
	return p.best or 0
end

-- Голова: следующий — первый пузырь выше ног; в полёте держаться над ним, с пола — запрыгнуть
local function nextBubble(view, p)
	local lb = p.lastBounce
	if lb and lb.k and p.y > lb.y - 2 then
		return view.path[lb.k + 1] or view.ledge
	end
	for _, s in view.path do
		if s.y + 0.5 > p.y + 0.6 then
			return s
		end
	end
	return view.ledge
end

function def.bot(view, mem)
	local me = view.me
	if me.finished then
		return {}
	end
	if mem.random then
		if not mem.goal or mem.rng:next() < 0.25 then
			mem.goal = view.path[mem.rng:int(1, #view.path)]
		end
		return Kit.go(mem.goal.x, mem.goal.z, 1, { stop = 0.4, jumpNear = 3 })
	end
	if mem.rng:next() < mem.err then
		-- ошибся: целится не туда
		local s = view.path[mem.rng:int(1, #view.path)]
		return Kit.go(s.x, s.z, 1, { stop = 0.4 })
	end
	return {
		speed = 1,
		stop = 0.4,
		jumpNear = 3,
		track = function(p)
			local s = nextBubble(view, p)
			return s.x, s.z
		end,
	}
end

function def.view(inst, _p, v)
	v.path = inst.path
	v.ledge = inst.ledge
	v.pad = inst.parts.Pad
end

return def
