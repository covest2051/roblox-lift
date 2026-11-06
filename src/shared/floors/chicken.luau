--[[
	😌 Курица-гигант (редкий). Огромная курица бродит по кругу и несёт яйца, которые
	прыгают по этажу. Коснись яйца — оно в твоей корзине: обычное +1, золотое +5.
	Выбывания нет. Место — по очкам.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "chicken",
	cat = "calm",
	icon = "🐔",
	duration = 40,
	minPlayers = 1,
	rare = 0.05,
}

local E = {
	Size = 56,
	Every = 0.55, -- курица несёт яйцо
	Gold = 0.08,
	Life = 10,
	Pick = 2.4,
	Pool = 24,
}
def.E = E

function def.build(inst)
	local h = E.Size / 2
	inst.cz = 6 + h
	inst.bounds = { -h + 1, h - 1, 6, 6 + E.Size - 1 }
	Kit.solid(inst, {
		name = "Yard",
		x = 0,
		y = -0.5,
		z = inst.cz,
		sx = E.Size,
		sy = 1,
		sz = E.Size,
		color = { 140, 200, 90 },
		mat = "Grass",
	})
	Kit.part(inst, {
		name = "Nest",
		shape = "Disc",
		x = 0,
		y = 0.4,
		z = inst.cz,
		sx = 10,
		sy = 0.8,
		color = { 210, 170, 90 },
		mat = "WoodPlanks",
		collide = false,
	})
	-- курица из примитивов
	Kit.part(inst, {
		name = "Hen",
		shape = "Ball",
		x = 0,
		y = 6,
		z = inst.cz,
		sx = 10,
		color = { 250, 250, 245 },
		collide = false,
	})
	Kit.part(inst, {
		name = "HenHead",
		shape = "Ball",
		x = 0,
		y = 12,
		z = inst.cz - 4,
		sx = 5,
		color = { 250, 250, 245 },
		collide = false,
	})
	Kit.part(inst, {
		name = "HenComb",
		x = 0,
		y = 15,
		z = inst.cz - 4,
		sx = 1,
		sy = 2,
		sz = 3,
		color = { 230, 40, 40 },
		collide = false,
	})
	Kit.part(inst, {
		name = "HenBeak",
		x = 0,
		y = 11.5,
		z = inst.cz - 6.8,
		sx = 1.4,
		sy = 1,
		sz = 2,
		color = { 255, 180, 40 },
		collide = false,
	})
	inst.eggs = {}
	for k = 1, E.Pool do
		local e =
			{ k = k, name = "Egg" .. k, live = false, x = 0, z = 0, vx = 0, vz = 0, born = 0, gold = false }
		table.insert(inst.eggs, e)
		Kit.part(inst, {
			name = e.name,
			shape = "Ball",
			x = 0,
			y = -50,
			z = 0,
			sx = 1.6,
			color = { 255, 250, 235 },
			collide = false,
		})
	end
	inst.nextEgg = 3
	inst.henA = 0
	Kit.spawnRow(inst, 8, 0, 26)
	Kit.pub(inst, { eggs = 0 })
end

function def.step(inst, dt)
	local t = inst.t
	local rng = inst.rng
	local h = E.Size / 2
	-- курица ходит по кругу
	inst.henA += dt * 0.35
	local hx, hz = math.cos(inst.henA) * 8, inst.cz + math.sin(inst.henA) * 8
	Kit.set(inst, "Hen", { x = hx, z = hz })
	Kit.set(
		inst,
		"HenHead",
		{ x = hx + math.cos(inst.henA + 1.6) * 4, z = hz + math.sin(inst.henA + 1.6) * 4 }
	)
	Kit.set(
		inst,
		"HenComb",
		{ x = hx + math.cos(inst.henA + 1.6) * 4, z = hz + math.sin(inst.henA + 1.6) * 4 }
	)
	Kit.set(
		inst,
		"HenBeak",
		{ x = hx + math.cos(inst.henA + 1.6) * 6.6, z = hz + math.sin(inst.henA + 1.6) * 6.6 }
	)
	if t >= inst.nextEgg then
		inst.nextEgg = t + E.Every * rng:range(0.7, 1.3) / math.max(1, math.sqrt(#inst.list / 4))
		for _, e in inst.eggs do
			if not e.live then
				local a = rng:range(0, math.pi * 2)
				local sp = rng:range(8, 16)
				e.live, e.x, e.z, e.vx, e.vz, e.born = true, hx, hz, math.cos(a) * sp, math.sin(a) * sp, t
				e.gold = rng:next() < E.Gold
				Kit.set(inst, e.name, {
					color = if e.gold then { 255, 205, 40 } else { 255, 250, 235 },
					mat = if e.gold then "Neon" else "SmoothPlastic",
				})
				break
			end
		end
	end
	for _, e in inst.eggs do
		if e.live then
			local age = t - e.born
			e.x += e.vx * dt
			e.z += e.vz * dt
			e.vx *= 1 - math.min(1, 0.6 * dt)
			e.vz *= 1 - math.min(1, 0.6 * dt)
			if math.abs(e.x) > h - 1 then
				e.vx = -e.vx
				e.x = math.clamp(e.x, -h + 1, h - 1)
			end
			if math.abs(e.z - inst.cz) > h - 1 then
				e.vz = -e.vz
				e.z = math.clamp(e.z, inst.cz - h + 1, inst.cz + h - 1)
			end
			local hop = math.abs(math.sin(age * 5)) * math.max(0, 2 - age * 0.3)
			if age > E.Life then
				e.live = false
				Kit.set(inst, e.name, { y = -50 })
			else
				Kit.set(inst, e.name, { x = e.x, y = 0.8 + hop, z = e.z })
				for _, p in inst.list do
					if (p.x - e.x) ^ 2 + (p.z - e.z) ^ 2 < E.Pick * E.Pick then
						p.score += if e.gold then 5 else 1
						e.live = false
						Kit.set(inst, e.name, { y = -50 })
						Kit.event(inst, { t = "egg", id = p.id, gold = e.gold })
						break
					end
				end
			end
		end
	end
end

function def.score(_inst, p)
	return p.score
end

-- Голова: к самому выгодному яйцу (золотое ценнее, далёкое дешевле)
function def.bot(view, mem)
	local me = view.me
	local live = {}
	local best, bv = nil, -math.huge
	for _, e in view.eggs do
		if e.live then
			table.insert(live, e)
			local d = math.sqrt((e.x - me.x) ^ 2 + (e.z - me.z) ^ 2)
			local v = (if e.gold then 5 else 1) / (d + 4)
			if v > bv then
				best, bv = e, v
			end
		end
	end
	if #live == 0 then
		return Kit.go(0, view.cz, 0.5, { stop = 6 })
	end
	if mem.random then
		if not mem.egg or not mem.egg.live or mem.rng:next() < 0.5 then
			mem.egg = live[mem.rng:int(1, #live)]
		end
	else
		if not mem.egg or not mem.egg.live or mem.egg ~= best then
			mem.egg = Kit.choose(mem, best, live)
		end
	end
	local egg = mem.egg
	return {
		speed = if mem.random then 0.75 else 1,
		stop = 0.2,
		track = function(_p)
			return egg.x + egg.vx * 0.2, egg.z + egg.vz * 0.2
		end,
	}
end

function def.view(inst, _p, v)
	v.eggs = inst.eggs
	v.cz = inst.cz
end

return def
