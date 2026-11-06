--[[
	👑 Босс: Гигантский мыльный пузырь. Пузырь медленно опускается на поле мягких шипов
	в середине зала. Запрыгивай на батуты среди шипов и подбивай пузырь снизу головой.
	Шипы — на балкон. Пузырь дожил до конца — прошли все оставшиеся; лопнул — никто.
	Место — по вкладу (подбивания).
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "soapboss",
	cat = "boss",
	icon = "🫧",
	duration = 50,
	minPlayers = 1,
}

local P = {
	Spikes = 16, -- радиус поля шипов
	PadR = 6.5, -- батуты по кругу
	StoneR = 12, -- камни-ступеньки между краем и батутами
	StoneTop = 1.5,
	PadD = 6,
	PadTop = 3.5,
	Bounce = 80,
	R = 7, -- радиус пузыря
	Y0 = 30,
	Fall = 1.7, -- «гравитация» пузыря
	Kick = 6.5, -- подбил — скорость вверх
	MaxUp = 8,
	Drift = 9, -- пузырь гуляет в этом радиусе от центра
	Pop = 10, -- центр ниже — лопнул о шипы
	Cool = 0.6,
}
def.P = P

function def.build(inst)
	local rng = inst.rng
	local cz = 8 + 28
	inst.cz = cz
	inst.bounds = { -29, 29, 7, cz + 28 }
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = cz,
		sx = 60,
		sy = 1,
		sz = 60,
		color = { 200, 230, 250 },
		mat = "SmoothPlastic",
	})
	Kit.part(inst, {
		name = "SpikeBed",
		shape = "Disc",
		x = 0,
		y = 0.1,
		z = cz,
		sx = 2 * P.Spikes,
		sy = 0.2,
		color = { 255, 150, 200 },
		mat = "Fabric",
		collide = false,
	})
	for i = 1, 26 do
		local a, r = rng:range(0, math.pi * 2), rng:range(1, P.Spikes - 1)
		Kit.part(inst, {
			name = "Spike" .. i,
			shape = "Wedge",
			x = math.cos(a) * r,
			y = 1.2,
			z = cz + math.sin(a) * r,
			sx = 1.6,
			sy = 2.4,
			sz = 1.6,
			ry = rng:range(0, 180),
			color = { 255, 120, 180 },
			mat = "Foil",
			collide = false,
		})
	end
	inst.pads = {}
	local function pad(name, x, z)
		Kit.part(inst, {
			name = name .. "Post",
			shape = "Disc",
			x = x,
			y = (P.PadTop - 0.5) / 2,
			z = z,
			sx = 2,
			sy = P.PadTop - 0.5,
			color = { 120, 120, 140 },
			mat = "Metal",
			collide = false,
		})
		local s = Kit.solid(inst, {
			name = name,
			shape = "Disc",
			x = x,
			y = P.PadTop - 0.25,
			z = z,
			sx = P.PadD,
			sy = 0.5,
			color = { 90, 220, 255 },
			mat = "Neon",
			bounce = P.Bounce,
		})
		table.insert(inst.pads, s)
	end
	pad("Pad0", 0, cz)
	inst.stones = {}
	for k = 1, 6 do
		local a = k * 2 * math.pi / 6
		pad("Pad" .. k, math.cos(a) * P.PadR, cz + math.sin(a) * P.PadR)
		local st = Kit.solid(inst, {
			name = "Stone" .. k,
			shape = "Disc",
			x = math.cos(a) * P.StoneR,
			y = P.StoneTop / 2,
			z = cz + math.sin(a) * P.StoneR,
			sx = 3.4,
			sy = P.StoneTop,
			color = { 150, 140, 170 },
			mat = "Slate",
		})
		st.k = k
		table.insert(inst.stones, st)
	end
	inst.bub = { x = 0, y = P.Y0, z = cz, vx = 0, vy = 0, vz = 0, popped = false }
	Kit.part(inst, {
		name = "Bubble",
		shape = "Ball",
		x = 0,
		y = P.Y0,
		z = cz,
		sx = 2 * P.R,
		color = { 200, 240, 255 },
		mat = "Glass",
		alpha = 0.55,
		collide = false,
	})
	Kit.part(inst, {
		name = "BubbleShine",
		shape = "Ball",
		x = 2,
		y = P.Y0 + 3,
		z = cz - 3,
		sx = 2,
		color = { 255, 255, 255 },
		mat = "Neon",
		alpha = 0.3,
		collide = false,
	})
	Kit.spawnRow(inst, 10, 0, 30)
	Kit.pub(inst, { height = P.Y0, popped = false })
end

function def.step(inst, dt)
	local t = inst.t
	local b = inst.bub
	local cz = inst.cz
	local rng = inst.rng
	-- шипы под ногами
	for _, p in inst.list do
		if not p.out and p.grounded and p.on and p.on.name == "Floor" and Kit.near(p, 0, cz, P.Spikes) then
			Kit.out(inst, p, "spikes")
		end
	end
	if b.popped or t < 3 then
		return
	end
	-- пузырь: опускается, гуляет ветром
	b.vy = math.max(-6, b.vy - P.Fall * dt)
	b.vx += (rng:range(-2.5, 2.5) - b.x * 0.15) * dt
	b.vz += (rng:range(-2.5, 2.5) - (b.z - cz) * 0.15) * dt
	b.vx *= 1 - math.min(1, 0.4 * dt)
	b.vz *= 1 - math.min(1, 0.4 * dt)
	b.x += b.vx * dt
	b.y += b.vy * dt
	b.z += b.vz * dt
	local dx, dz = b.x, b.z - cz
	local d = math.sqrt(dx * dx + dz * dz)
	if d > P.Drift then
		b.x, b.z = dx / d * P.Drift, cz + dz / d * P.Drift
		b.vx, b.vz = -b.vx * 0.5, -b.vz * 0.5
	end
	if b.y > 40 then
		b.y, b.vy = 40, math.min(b.vy, 0)
	end
	-- подбили снизу головой
	for _, p in inst.list do
		if not p.out and (p.vy or 0) > 0 and t >= (p.kickCool or 0) then
			local head = p.y + 5
			if head >= b.y - P.R - 0.8 and p.y < b.y and Kit.near(p, b.x, b.z, P.R) then
				b.vy = math.min(P.MaxUp, math.max(b.vy, 0) + P.Kick)
				local px, pz = b.x - p.x, b.z - p.z
				local pl = math.max(0.1, math.sqrt(px * px + pz * pz))
				b.vx += px / pl * 2
				b.vz += pz / pl * 2
				p.vy = 0 -- стукнулся и падает обратно
				p.contrib += 1
				p.kickCool = t + P.Cool
				Kit.event(inst, { t = "boop", id = p.id })
			end
		end
	end
	Kit.set(inst, "Bubble", { x = b.x, y = b.y, z = b.z })
	Kit.set(inst, "BubbleShine", { x = b.x + 2, y = b.y + 3, z = b.z - 3 })
	if b.y <= P.Pop then
		b.popped = true
		inst.endAt = t + 2
		Kit.set(inst, "Bubble", { alpha = 1 })
		Kit.set(inst, "BubbleShine", { alpha = 1 })
		Kit.event(inst, { t = "pop" })
	end
	if math.floor(t * 2) ~= math.floor((t - dt) * 2) then
		Kit.pub(inst, { height = math.floor(b.y - P.Pop), popped = b.popped })
	end
end

function def.done(inst)
	return inst.endAt ~= nil and inst.t >= inst.endAt
end

function def.passed(inst, p)
	return not inst.bub.popped and not p.out
end

function def.score(_inst, p)
	return p.contrib + (if p.out then 0 else 0.5)
end

-- Голова: батут под пузырём; вверх — к пузырю, вниз — обратно на батут
function def.bot(view, mem)
	local me = view.me
	local b = view.bub
	local pads = view.pads
	if view.t < 3 then
		return {}
	end
	local function padNear(x, z)
		local best, bd = nil, math.huge
		for _, s in pads do
			local d = (s.x - x) ^ 2 + (s.z - z) ^ 2
			if d < bd then
				best, bd = s, d
			end
		end
		return best
	end
	if me.grounded and me.on and not me.on.bounce then
		me.lastBounce = nil
	end
	local onPadZone = (me.on and me.on.bounce) or (not me.grounded and me.lastBounce ~= nil)
	if not onPadZone then
		if not me.grounded then
			return mem.intent -- в прыжке — не передумывать
		end
		-- снаружи: к батуту под пузырём, запрыгнуть с края поля шипов
		local ring, best, bd = {}, nil, math.huge
		for _, s in pads do
			if s.name ~= "Pad0" then
				table.insert(ring, s)
				local d = (s.x - b.x) ^ 2 + (s.z - b.z) ^ 2
				if d < bd then
					best, bd = s, d
				end
			end
		end
		if
			not mem.pad
			or mem.pad.name == "Pad0"
			or (not mem.random and (mem.pad.x - b.x) ^ 2 + (mem.pad.z - b.z) ^ 2 > 100)
		then
			mem.pad = Kit.choose(mem, best, ring)
		end
		local pad = mem.pad
		-- подойти к краю шипов напротив батута (в обход поля по кругу), прыгнуть на камень, с него — на батут
		local cz = view.cz
		local R = P.Spikes + 1.5
		local k = tonumber(string.match(pad.name, "%d+")) or 1
		local stone = view.stones[k]
		if me.on and me.on == stone then
			return Kit.go(pad.x, pad.z, 1, { jump = true, jumpOnce = true, stop = 0.3 })
		end
		local want = math.atan2(pad.z - cz, pad.x)
		local ex, ez = math.cos(want) * R, cz + math.sin(want) * R
		if (me.x - ex) ^ 2 + (me.z - ez) ^ 2 > 4 then
			local mine = math.atan2(me.z - cz, me.x)
			local da = (want - mine + math.pi) % (2 * math.pi) - math.pi
			if math.abs(da) > 0.4 then
				local a = mine + math.clamp(da, -0.5, 0.5)
				return Kit.go(math.cos(a) * (R + 1), cz + math.sin(a) * (R + 1), 1, { stop = 0.5 })
			end
			return Kit.go(ex, ez, 1, { stop = 0.5 })
		end
		return Kit.go(stone.x, stone.z, 1, { jump = true, jumpOnce = true, stop = 0.3 })
	end

	if me.grounded and me.on and not me.on.bounce then
		me.lastBounce = nil
	end
	local onPadZone = (me.on and me.on.bounce) or (not me.grounded and me.lastBounce ~= nil)
	if not onPadZone then
		if not me.grounded then
			return mem.intent -- в прыжке — не передумывать
		end
		-- снаружи: к батуту под пузырём, запрыгнуть с края поля шипов
		local ring, best, bd = {}, nil, math.huge
		for _, s in pads do
			if s.name ~= "Pad0" then
				table.insert(ring, s)
				local d = (s.x - b.x) ^ 2 + (s.z - b.z) ^ 2
				if d < bd then
					best, bd = s, d
				end
			end
		end
		if
			not mem.pad
			or mem.pad.name == "Pad0"
			or (not mem.random and (mem.pad.x - b.x) ^ 2 + (mem.pad.z - b.z) ^ 2 > 100)
		then
			mem.pad = Kit.choose(mem, best, ring)
		end
		local pad = mem.pad
		-- подойти к краю шипов напротив батута (в обход поля шипов по кругу) и прыгнуть
		local cz = view.cz
		local R = P.Spikes + 1.5
		local want = math.atan2(pad.z - cz, pad.x)
		local mine = math.atan2(me.z - cz, me.x)
		local da = (want - mine + math.pi) % (2 * math.pi) - math.pi
		local myR = math.sqrt(me.x * me.x + (me.z - cz) ^ 2)
		if math.abs(da) > 0.15 or myR > R + 2 then
			local a = mine + math.clamp(da, -0.5, 0.5)
			local rr = math.max(R, math.min(myR, R + 4))
			return Kit.go(math.cos(a) * rr, cz + math.sin(a) * rr, 1, { stop = 0.5 })
		end
		local k = tonumber(string.match(pad.name, "%d+")) or 1
		local stone = view.stones[k]
		local onStone = me.on and me.on == stone
		if onStone then
			return Kit.go(pad.x, pad.z, 1, { jump = true, jumpOnce = true, stop = 0.3 })
		end
		local ex, ez = math.cos(want) * R, cz + math.sin(want) * R
		if not Kit.near(me, ex, ez, 1.5) and me.y < 1 then
			return Kit.go(ex, ez, 1, { stop = 0.8 })
		end
		return Kit.go(stone.x, stone.z, 1, { jump = true, jumpOnce = true, stop = 0.3 })
	end
	local err = mem.rng:next() < mem.err
	return {
		speed = 1,
		stop = 0.2,
		track = function(p)
			if p.vy > 0 and not mem.up then
				-- новый подскок: выбрать батут на этот полёт — ближе к пузырю, до которого долетим
				mem.up = true
				local cur = mem.pad or padNear(p.x, p.z)
				local best, bv = cur, (cur.x - b.x) ^ 2 + (cur.z - b.z) ^ 2 - 4
				for _, s in pads do
					if (s.x - p.x) ^ 2 + (s.z - p.z) ^ 2 < 64 then
						local v = (s.x - b.x) ^ 2 + (s.z - b.z) ^ 2
						if v < bv then
							best, bv = s, v
						end
					end
				end
				if err or mem.random then
					local near = {}
					for _, s in pads do
						if (s.x - p.x) ^ 2 + (s.z - p.z) ^ 2 < 64 then
							table.insert(near, s)
						end
					end
					best = near[mem.rng:int(1, #near)] or best
				end
				mem.pad = best
				mem.flight = best
				if mem.random and mem.rng:next() < 0.02 then
					-- наугад: прыгнул «куда-нибудь к пузырю», а не на батут
					mem.flight = { x = b.x + mem.rng:range(-4, 4), z = b.z + mem.rng:range(-4, 4) }
				end
			elseif p.vy <= 0 then
				mem.up = false
			end
			local pad = mem.flight or mem.pad or padNear(p.x, p.z)
			return pad.x, pad.z
		end,
	}
end

function def.view(inst, _p, v)
	v.cz = inst.cz
	v.bub = inst.bub
	v.pads = inst.pads
	v.stones = inst.stones
end

return def
