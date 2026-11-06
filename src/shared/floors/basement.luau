--[[
	❓ Подвал (этаж 13, секретный). Всё вверх ногами: мебель на потолке, люстра растёт из
	пола, табло путает цифры. По подвалу разбросаны 13 потерянных носков — собирай.
	Кот-призрак бродит и, если догонит, утаскивает один носок обратно (не страшно, смешно).
	Выбывания нет. Даёт уникальный облик и запись в коллекции. Место — по носкам.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "basement",
	cat = "secret",
	icon = "🕳",
	duration = 40,
	minPlayers = 1,
}

local S = {
	Socks = 13,
	Pick = 2.4,
	Cat = 7, -- скорость кота
	CatGrab = 2.6,
	Size = 52,
}
def.S = S

local SOCK = { { 255, 120, 120 }, { 120, 200, 255 }, { 255, 230, 120 }, { 170, 255, 150 }, { 230, 150, 255 } }

function def.build(inst)
	local rng = inst.rng
	local h = S.Size / 2
	inst.cz = 6 + h
	inst.flipped = true
	inst.bounds = { -h + 1, h - 1, 6, 6 + S.Size - 1 }
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = inst.cz,
		sx = S.Size,
		sy = 1,
		sz = S.Size,
		color = { 70, 60, 80 },
		mat = "Cobblestone",
	})
	Kit.part(inst, {
		name = "Ceiling",
		x = 0,
		y = 20,
		z = inst.cz,
		sx = S.Size,
		sy = 1,
		sz = S.Size,
		color = { 150, 120, 90 },
		mat = "WoodPlanks",
		collide = false,
	})
	-- мебель вверх ногами — на потолке
	for i = 1, 5 do
		local x, z = rng:range(-h + 6, h - 6), inst.cz + rng:range(-h + 6, h - 6)
		Kit.part(inst, {
			name = "UpTable" .. i,
			x = x,
			y = 17,
			z = z,
			sx = 6,
			sy = 0.6,
			sz = 4,
			color = { 120, 80, 50 },
			mat = "WoodPlanks",
			collide = false,
		})
		Kit.part(inst, {
			name = "UpLeg" .. i,
			x = x,
			y = 18.5,
			z = z,
			sx = 0.5,
			sy = 3,
			sz = 0.5,
			color = { 100, 60, 40 },
			collide = false,
		})
		Kit.part(inst, {
			name = "UpChair" .. i,
			x = x + 4,
			y = 18,
			z = z,
			sx = 2,
			sy = 2,
			sz = 2,
			color = { 200, 80, 80 },
			collide = false,
		})
	end
	-- люстра растёт из пола
	Kit.part(inst, {
		name = "Chandelier",
		shape = "Ball",
		x = 0,
		y = 2,
		z = inst.cz,
		sx = 4,
		color = { 255, 230, 150 },
		mat = "Neon",
		collide = false,
	})
	Kit.part(inst, {
		name = "ChandelierRod",
		x = 0,
		y = 0.5,
		z = inst.cz,
		sx = 0.4,
		sy = 3,
		sz = 0.4,
		color = { 200, 180, 100 },
		mat = "Metal",
		collide = false,
	})
	Kit.part(inst, {
		name = "Board",
		x = 0,
		y = 12,
		z = 6 + S.Size - 1,
		sx = 16,
		sy = 6,
		sz = 1,
		color = { 30, 30, 40 },
		label = "basement.board",
	})
	inst.socks = {}
	for k = 1, S.Socks do
		local sk = { k = k, name = "Sock" .. k, live = true }
		sk.x, sk.z = rng:range(-h + 3, h - 3), inst.cz + rng:range(-h + 6, h - 3)
		table.insert(inst.socks, sk)
		Kit.part(inst, {
			name = sk.name,
			x = sk.x,
			y = 0.5,
			z = sk.z,
			sx = 0.8,
			sy = 0.6,
			sz = 2,
			ry = rng:range(0, 180),
			color = SOCK[k % #SOCK + 1],
			mat = "Fabric",
			collide = false,
		})
	end
	inst.cat = { x = 0, z = inst.cz + 10, nap = 0 }
	Kit.part(inst, {
		name = "Cat",
		shape = "Ball",
		x = 0,
		y = 1.5,
		z = inst.cat.z,
		sx = 3,
		color = { 220, 230, 255 },
		mat = "Glass",
		alpha = 0.4,
		collide = false,
	})
	Kit.part(inst, {
		name = "CatEars",
		x = 0,
		y = 3.2,
		z = inst.cat.z,
		sx = 2.4,
		sy = 0.8,
		sz = 0.4,
		color = { 220, 230, 255 },
		mat = "Glass",
		alpha = 0.4,
		collide = false,
	})
	inst.found = 0
	Kit.spawnRow(inst, 8, 0, 20)
	Kit.pub(inst, { flipped = true, socks = 0, total = S.Socks })
end

function def.step(inst, dt)
	local t = inst.t
	local h = S.Size / 2
	local cat = inst.cat
	-- кот-призрак: к ближайшему игроку с носками (после 3 с), после кражи дремлет
	if t > 3 and t >= cat.nap then
		local target, td = nil, math.huge
		for _, p in inst.list do
			if p.score > 0 then
				local d = (p.x - cat.x) ^ 2 + (p.z - cat.z) ^ 2
				if d < td then
					target, td = p, d
				end
			end
		end
		if target then
			local dx, dz = target.x - cat.x, target.z - cat.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < S.CatGrab then
				target.score -= 1
				cat.nap = t + 4
				-- носок возвращается в подвал
				for _, sk in inst.socks do
					if not sk.live then
						sk.live = true
						sk.x, sk.z = inst.rng:range(-h + 3, h - 3), inst.cz + inst.rng:range(-h + 6, h - 3)
						Kit.set(inst, sk.name, { x = sk.x, y = 0.5, z = sk.z })
						break
					end
				end
				Kit.event(inst, { t = "meow", id = target.id })
			elseif d > 0.01 then
				cat.x += dx / d * S.Cat * dt
				cat.z += dz / d * S.Cat * dt
			end
		end
		Kit.set(inst, "Cat", { x = cat.x, z = cat.z })
		Kit.set(inst, "CatEars", { x = cat.x, z = cat.z })
	end
	for _, sk in inst.socks do
		if sk.live then
			for _, p in inst.list do
				if (p.x - sk.x) ^ 2 + (p.z - sk.z) ^ 2 < S.Pick * S.Pick then
					sk.live = false
					p.score += 1
					Kit.set(inst, sk.name, { y = -50 })
					Kit.event(inst, { t = "sock", id = p.id })
					break
				end
			end
		end
	end
	if math.floor(t * 2) ~= math.floor((t - dt) * 2) then
		local n = 0
		for _, sk in inst.socks do
			if not sk.live then
				n += 1
			end
		end
		Kit.pub(inst, { socks = n })
	end
end

function def.score(_inst, p)
	return p.score
end

-- Голова: к ближайшему носку, подальше от кота
function def.bot(view, mem)
	local me = view.me
	local cat = view.cat
	local live = {}
	local best, bv = nil, math.huge
	for _, sk in view.socks do
		if sk.live then
			table.insert(live, sk)
			local d = (sk.x - me.x) ^ 2 + (sk.z - me.z) ^ 2
			local dc = (sk.x - cat.x) ^ 2 + (sk.z - cat.z) ^ 2
			local v = d - math.min(dc, 100) * 0.5
			if v < bv then
				best, bv = sk, v
			end
		end
	end
	if #live == 0 then
		-- убегать от кота
		local dx, dz = me.x - cat.x, me.z - cat.z
		local d = math.max(0.1, math.sqrt(dx * dx + dz * dz))
		return Kit.go(me.x + dx / d * 10, me.z + dz / d * 10, 1)
	end
	if mem.random then
		if not mem.sock or not mem.sock.live or mem.rng:next() < 0.4 then
			mem.sock = live[mem.rng:int(1, #live)]
		end
		return Kit.go(mem.sock.x, mem.sock.z, 0.75)
	end
	if not mem.sock or not mem.sock.live or mem.sock ~= best then
		mem.sock = Kit.choose(mem, best, live)
	end
	return Kit.go(mem.sock.x, mem.sock.z, 1, { stop = 0.3 })
end

function def.view(inst, _p, v)
	v.socks = inst.socks
	v.cat = inst.cat
end

return def
