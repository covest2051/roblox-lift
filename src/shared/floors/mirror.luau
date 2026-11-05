--[[
	🏁 Зеркальный этаж. Мостики над пустотой до кнопки, управление отражено (влево = вправо).
	Упал — обратно на последний островок (падение считается). Прошёл — нажал кнопку.
	Место — по времени финиша.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "mirror",
	cat = "race",
	icon = "🪞",
	duration = 45,
	minPlayers = 1,
	freeze = true,
	respawn = true,
}

local W = 3 -- ширина мостика

function def.build(inst)
	local rng = inst.rng
	inst.mirror = true
	-- узлы-островки зигзагом
	local nodes = { { 0, 8 } }
	local x, z = 0, 8
	for i = 1, 11 do
		if i % 2 == 1 then
			z += if i == 1 then 14 else rng:range(8, 10)
		else
			local nx
			repeat
				nx = rng:range(-16, 16)
			until math.abs(nx - x) > 9
			x = nx
		end
		table.insert(nodes, { x, z })
	end
	table.insert(nodes, { x, z + 12 })
	inst.nodes = nodes
	inst.bounds = { -26, 26, 1, z + 20 }
	for i, n in nodes do
		local size = if i == 1 then 16 elseif i == #nodes then 10 else 7
		Kit.solid(inst, {
			name = "Isle" .. i,
			x = n[1],
			y = -1,
			z = n[2],
			sx = size,
			sy = 2,
			sz = size,
			color = if i == #nodes then { 255, 205, 70 } else { 180, 220, 255 },
			mat = if i == #nodes then "SmoothPlastic" else "Glass",
		})
		if i > 1 then
			local a = nodes[i - 1]
			local dx, dz = n[1] - a[1], n[2] - a[2]
			local len = math.abs(dx) + math.abs(dz)
			local gap = if i % 3 == 0 then 4 else 0
			-- мостик (с разрывом посередине на некоторых)
			local function bridge(name, cx, cz, l)
				Kit.solid(inst, {
					name = name,
					x = cx,
					y = -0.75,
					z = cz,
					sx = if dx ~= 0 then l else W,
					sy = 1.5,
					sz = if dz ~= 0 then l else W,
					color = { 200, 235, 255 },
					mat = "Glass",
					alpha = 0.2,
				})
			end
			local mx, mz = (a[1] + n[1]) / 2, (a[2] + n[2]) / 2
			if gap > 0 then
				local half = (len - gap) / 2
				local ux, uz = math.sign(dx), math.sign(dz)
				bridge("Bridge" .. i .. "a", a[1] + ux * half / 2, a[2] + uz * half / 2, half)
				bridge("Bridge" .. i .. "b", n[1] - ux * half / 2, n[2] - uz * half / 2, half)
			else
				bridge("Bridge" .. i, mx, mz, len)
			end
		end
	end
	local f = nodes[#nodes]
	Kit.part(inst, {
		name = "Button",
		shape = "Disc",
		x = f[1],
		y = 0.3,
		z = f[2] + 2,
		sx = 3,
		sy = 0.6,
		color = { 255, 60, 80 },
		mat = "Neon",
	})
	-- зеркала по бокам (декор)
	for i = 1, 4 do
		Kit.part(inst, {
			name = "Mirror" .. i,
			x = if i % 2 == 0 then 27 else -27,
			y = 8,
			z = 10 + (i - 1) * 22,
			sx = 0.5,
			sy = 14,
			sz = 18,
			color = { 210, 230, 255 },
			mat = "Glass",
			alpha = 0.3,
			collide = false,
		})
	end
	Kit.spawnRow(inst, 6, 0, 12)
	for _, p in inst.list do
		p.cp = 1
	end
	Kit.pub(inst, { mirror = true })
end

function def.step(inst, _dt)
	local nodes = inst.nodes
	local f = nodes[#nodes]
	for _, p in inst.list do
		if not p.out and not p.finished and p.grounded then
			local k = p.cp + 1
			local n = nodes[k]
			if n and math.abs(p.x - n[1]) <= 3.5 and math.abs(p.z - n[2]) <= 3.5 then
				p.cp = k
				p.checkpoint = { nodes[k][1], 0, nodes[k][2] }
			end
			if p.cp >= #nodes - 1 and Kit.near(p, f[1], f[2] + 2, 3) then
				p.finished = inst.t
				p.cp = #nodes
				Kit.event(inst, { t = "finish", id = p.id, at = inst.t })
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
	return p.cp or 0
end

function def.bot(view, mem)
	local me = view.me
	local nodes = view.nodes
	if me.finished then
		return {}
	end
	-- знает про зеркало: средний почти всегда, новичок часто путается
	mem.mirrorFix = not mem.random and mem.rng:next() > mem.err * 2.5
	local k = math.min(#nodes, (me.cp or 1) + 1)
	if mem.random then
		if not mem.goal or mem.rng:next() < 0.15 then
			mem.goal = mem.rng:int(1, #nodes)
		end
		k = mem.goal
	end
	local n = nodes[k]
	local tz = n[2]
	if k == #nodes then
		tz += 2
	end
	return Kit.go(n[1], tz, 1, { edgeJump = true, stop = 0.8 })
end

function def.view(inst, _p, v)
	v.nodes = inst.nodes
end

return def
