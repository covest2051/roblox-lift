--[[
	🤝 Торт на доставку. Тележка с трёхъярусным тортом: толкайте вместе (упрись сзади и иди
	вперёд). Чем больше толкают — тем быстрее. Ухабы (жёлтые полосы): переехать быстро —
	верхний ярус падает. Довезли до двери хотя бы один ярус — прошли все. Место — по вкладу.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "cake",
	cat = "coop",
	icon = "🎂",
	duration = 50,
	minPlayers = 1,
}

local K = {
	Z0 = 12,
	Goal = 84,
	Per = 3.6, -- скорость от каждого толкающего
	Max = 8.5,
	Accel = 4,
	Friction = 5,
	Safe = 4.4, -- по ухабу медленнее — ярус цел
	Bumps = 5,
	PushHalfW = 3.2, -- упереться в тележку сзади
}
def.K = K

function def.build(inst)
	local rng = inst.rng
	inst.bounds = { -9, 9, 2, K.Goal + 4 }
	Kit.solid(inst, {
		name = "Road",
		x = 0,
		y = -0.5,
		z = 45,
		sx = 18,
		sy = 1,
		sz = 90,
		color = { 120, 120, 130 },
		mat = "Concrete",
	})
	for i, x in { -9.5, 9.5 } do
		Kit.part(
			inst,
			{ name = "Rail" .. i, x = x, y = 1, z = 45, sx = 1, sy = 2, sz = 90, color = { 255, 255, 255 } }
		)
	end
	inst.bumps = {}
	for i = 1, K.Bumps do
		local z = K.Z0 + 10 + (i - 1) * (K.Goal - K.Z0 - 16) / (K.Bumps - 1) + rng:range(-2, 2)
		table.insert(inst.bumps, { z = z, hit = false })
		Kit.part(inst, {
			name = "Bump" .. i,
			x = 0,
			y = 0.15,
			z = z,
			sx = 18,
			sy = 0.3,
			sz = 1.2,
			color = { 255, 210, 40 },
			collide = false,
		})
	end
	Kit.part(inst, {
		name = "Door",
		x = 0,
		y = 5,
		z = K.Goal + 3,
		sx = 8,
		sy = 10,
		sz = 1,
		color = { 200, 120, 60 },
		mat = "WoodPlanks",
	})
	Kit.part(inst, {
		name = "Cart",
		x = 0,
		y = 1.2,
		z = K.Z0,
		sx = 5,
		sy = 1.2,
		sz = 6,
		color = { 180, 180, 190 },
		mat = "Metal",
		collide = false,
	})
	local tierColors = { { 255, 240, 245 }, { 255, 190, 210 }, { 255, 140, 180 } }
	for k = 1, 3 do
		local d = 5.2 - k
		Kit.part(inst, {
			name = "Tier" .. k,
			shape = "Disc",
			x = 0,
			y = 2.3 + (k - 1) * 1.6,
			z = K.Z0,
			sx = d,
			sy = 1.5,
			color = tierColors[k],
			collide = false,
		})
	end
	Kit.part(inst, {
		name = "Cherry",
		shape = "Ball",
		x = 0,
		y = 7.2,
		z = K.Z0,
		sx = 0.8,
		color = { 220, 20, 40 },
		collide = false,
	})
	inst.cart = { z = K.Z0, v = 0, tiers = 3 }
	Kit.spawnRow(inst, K.Z0 - 6, 0, 12)
	Kit.pub(inst, { tiers = 3, dist = K.Goal - K.Z0 })
end

local function moveCart(inst)
	local c = inst.cart
	Kit.set(inst, "Cart", { z = c.z })
	for k = 1, 3 do
		if k <= c.tiers then
			Kit.set(inst, "Tier" .. k, { z = c.z })
		end
	end
	if c.tiers == 3 then
		Kit.set(inst, "Cherry", { z = c.z })
	end
end

function def.step(inst, dt)
	local c = inst.cart
	if c.tiers <= 0 or c.z >= K.Goal or inst.t < 3 then
		return
	end
	-- тележка твёрдая: кто упёрся в неё сзади — толкает
	local back = c.z - 3
	local pushers = 0
	for _, p in inst.list do
		if not p.out and math.abs(p.x) < K.PushHalfW then
			if p.bot and p.z > back and p.z < c.z + 3 and math.abs(p.x) < 2.8 then
				p.z = back -- упёрся (у людей это делает физика Roblox)
			end
			if p.z >= back - 1.8 and p.z <= back + 0.6 then
				pushers += 1
				p.contrib += dt
			end
		end
	end
	local want = math.min(K.Max, math.sqrt(pushers) * K.Per)
	if want > c.v then
		c.v = math.min(want, c.v + K.Accel * dt)
	else
		c.v = math.max(want, c.v - K.Friction * dt)
	end
	local z0 = c.z
	c.z += c.v * dt
	for i, b in inst.bumps do
		if not b.hit and z0 < b.z and c.z >= b.z then
			b.hit = true
			if c.v > K.Safe then
				Kit.set(
					inst,
					"Tier" .. c.tiers,
					{ y = 0.8, x = (if i % 2 == 0 then 3.5 else -3.5), z = b.z + 1 }
				)
				if c.tiers == 3 then
					Kit.set(inst, "Cherry", { y = 0.5, x = 2, z = b.z + 2 })
				end
				c.tiers -= 1
				Kit.event(inst, { t = "splat", tiers = c.tiers })
				Kit.pub(inst, { tiers = c.tiers })
			else
				Kit.event(inst, { t = "bumpOk" })
			end
		end
	end
	moveCart(inst)
	if math.floor(c.z) ~= math.floor(z0) then
		Kit.pub(inst, { dist = math.max(0, math.floor(K.Goal - c.z)), speed = math.floor(c.v * 10) / 10 })
	end
	if c.z >= K.Goal then
		Kit.event(inst, { t = "delivered", tiers = c.tiers })
	end
end

function def.done(inst)
	local c = inst.cart
	return c.tiers <= 0 or c.z >= K.Goal
end

function def.passed(inst, p)
	local c = inst.cart
	return c.z >= K.Goal and c.tiers > 0 and not p.out
end

function def.score(inst, p)
	return p.contrib + inst.cart.tiers * 0
end

-- Голова: встать сзади тележки и толкать; перед ухабом отпустить, пока скорость не упадёт
function def.bot(view, mem)
	local me = view.me
	local c = view.cart
	if view.t < 3 then
		return {}
	end
	local slot = ((tonumber(me.id) or 1) % 4 - 1.5) * 2
	local nextBump = nil
	for _, b in view.bumps do
		if b.z > c.z - 0.5 then
			nextBump = b
			break
		end
	end
	local push = true
	if mem.random then
		push = mem.rng:next() < 0.5
	elseif nextBump then
		local d = nextBump.z - c.z
		-- тормоз: успеть сбросить до безопасной скорости
		local brake = (c.v * c.v - (K.Safe - 0.6) ^ 2) / (2 * K.Friction) + 1
		if d < math.max(1.5, brake) and c.v > K.Safe - 0.8 then
			push = false
		end
		if mem.rng:next() < mem.err then
			push = not push
		end
	end
	if push then
		-- упереться сзади и идти вперёд
		return Kit.go(slot * 0.6, c.z + 6, 1)
	end
	return Kit.go(slot, c.z - 8, 1, { stop = 0.6 })
end

function def.view(inst, _p, v)
	v.cart = inst.cart
	v.bumps = inst.bumps
end

return def
