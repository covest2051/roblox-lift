--[[
	🔥 Боулинг. Наклонная дорожка; сверху катятся огромные шары — ты кегля. Сбит — смешно
	улетел на балкон. Шары всё чаще. Пережил — прошёл. Место — по времени на этаже.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "bowling",
	cat = "fire",
	icon = "🎳",
	duration = 40,
	minPlayers = 1,
}

local B = {
	W = 44, -- ширина дорожки
	Z0 = 6,
	Z1 = 70,
	Rise = 12, -- подъём дорожки к дальнему краю
	R = 3.6, -- радиус шара
	Speed = { 15, 22 },
	Every = { 1.7, 0.85 }, -- интервал запуска: в начале … в конце
	Pool = 16,
}
def.B = B

local COLORS = { { 40, 40, 60 }, { 200, 40, 60 }, { 40, 90, 200 }, { 60, 160, 90 }, { 120, 50, 160 } }

local function slopeY(z: number): number
	return B.Rise * math.clamp((z - B.Z0) / (B.Z1 - B.Z0), 0, 1)
end
def.slopeY = slopeY

function def.build(inst)
	local W = B.W + math.max(0, #inst.list - 4) * 2
	inst.W = W
	inst.bounds = { -W / 2 + 1, W / 2 - 1, B.Z0 - 3, B.Z1 - 14 }
	Kit.solid(inst, {
		name = "Lane",
		x = 0,
		y = B.Rise / 2 - 0.5,
		z = (B.Z0 + B.Z1) / 2,
		sx = W,
		sy = 1,
		sz = B.Z1 - B.Z0,
		slope = { 0, B.Rise },
		color = { 230, 190, 130 },
		mat = "WoodPlanks",
	})
	Kit.solid(inst, {
		name = "Apron",
		x = 0,
		y = -0.5,
		z = B.Z0 - 2,
		sx = W,
		sy = 1,
		sz = 4,
		color = { 200, 160, 110 },
		mat = "WoodPlanks",
	})
	for i, x in { -W / 2 - 1, W / 2 + 1 } do
		Kit.part(inst, {
			name = "Gutter" .. i,
			x = x,
			y = B.Rise / 2,
			z = (B.Z0 + B.Z1) / 2,
			sx = 2,
			sy = 2,
			sz = B.Z1 - B.Z0,
			color = { 60, 60, 70 },
			mat = "Metal",
		})
	end
	Kit.part(inst, {
		name = "Return",
		x = 0,
		y = B.Rise + 4,
		z = B.Z1 + 1,
		sx = W,
		sy = 8,
		sz = 2,
		color = { 90, 40, 120 },
	})
	inst.balls = {}
	for k = 1, B.Pool do
		local b = { k = k, name = "Ball" .. k, live = false, x = 0, z = -100, vx = 0, vz = 0 }
		table.insert(inst.balls, b)
		Kit.part(inst, {
			name = b.name,
			shape = "Ball",
			x = 0,
			y = -100,
			z = -100,
			sx = 2 * B.R,
			color = COLORS[k % #COLORS + 1],
			mat = "SmoothPlastic",
			collide = false,
		})
	end
	inst.nextBall = 3
	-- стоим кеглями: треугольником в середине дорожки
	local n = #inst.list
	for i, p in inst.list do
		local row = math.floor((math.sqrt(8 * (i - 1) + 1) - 1) / 2)
		local first = row * (row + 1) / 2
		local col = (i - 1) - first
		local x = (col - row / 2) * 5
		local z = 26 + row * 4
		x = math.clamp(x, -W / 2 + 3, W / 2 - 3)
		p.spawn = { x, slopeY(z), z }
		Kit.place(p, x, slopeY(z), z)
	end
	_ = n
	Kit.pub(inst, { balls = 0 })
end

local function launch(inst)
	local rng = inst.rng
	for _, b in inst.balls do
		if not b.live then
			b.live = true
			b.x = rng:range(-inst.W / 2 + B.R, inst.W / 2 - B.R)
			b.z = B.Z1 - 2
			b.vz = -rng:range(B.Speed[1], B.Speed[2])
			b.vx = rng:range(-3, 3)
			return b
		end
	end
	return nil
end

function def.step(inst, dt)
	local t = inst.t
	if t >= inst.nextBall then
		local k = math.clamp((t - 3) / (inst.duration - 3), 0, 1)
		local every = B.Every[1] + (B.Every[2] - B.Every[1]) * k
		launch(inst)
		if inst.rng:next() < 0.2 + 0.3 * k then
			launch(inst) -- дуплет
		end
		inst.nextBall = t + every * inst.rng:range(0.8, 1.2) / math.max(1, math.sqrt(#inst.list / 4))
	end
	for _, b in inst.balls do
		if b.live then
			b.x += b.vx * dt
			b.z += b.vz * dt
			if math.abs(b.x) > inst.W / 2 - B.R then
				b.vx = -b.vx
				b.x = math.clamp(b.x, -inst.W / 2 + B.R, inst.W / 2 - B.R)
			end
			if b.z < B.Z0 - 8 then
				b.live = false
				Kit.set(inst, b.name, { y = -100, z = -100 })
			else
				local y = slopeY(b.z) + B.R
				Kit.set(inst, b.name, { x = b.x, y = y, z = b.z })
				if t >= 3 then
					for _, p in inst.list do
						if
							not p.out
							and (p.x - b.x) ^ 2 + (p.z - b.z) ^ 2 < (B.R + 0.9) ^ 2
							and p.y < y + B.R - 1
						then
							Kit.out(inst, p, "strike")
						end
					end
				end
			end
		end
	end
end

-- Голова: шар катится на меня в ближайшие секунды — шагнуть в сторону, где свободно
function def.bot(view, mem)
	local me = view.me
	local inst = view.inst
	local W = inst.W
	local function danger(x: number, z: number): number
		local d = 0
		for _, b in inst.balls do
			if b.live and b.z > z - 1 then
				local tt = (b.z - z) / -b.vz
				if tt < 2.2 then
					local bx = b.x + b.vx * tt
					local dx = math.abs(bx - x)
					if dx < B.R + 3 then
						d += (B.R + 3 - dx) * (2.2 - tt)
					end
				end
			end
		end
		return d
	end
	local zHome = 28
	local here = danger(me.x, me.z)
	if here <= 0 and mem.random then
		if not mem.goal or mem.rng:next() < 0.3 then
			mem.goal = { mem.rng:range(-W / 2 + 2, W / 2 - 2), mem.rng:range(22, 34) }
		end
		return Kit.go(mem.goal[1], mem.goal[2], 0.5)
	end
	if here <= 0 then
		-- спокойно: держаться середины своей полосы
		return Kit.go(me.x, zHome, 0.5, { stop = 1 })
	end
	local best, bestV, all = nil, math.huge, {}
	for dx = -12, 12, 3 do
		local x = math.clamp(me.x + dx, -W / 2 + 2, W / 2 - 2)
		local v = danger(x, me.z) + math.abs(dx) * 0.08
		if math.abs(dx) >= 6 then
			table.insert(all, x)
		end
		if v < bestV then
			best, bestV = x, v
		end
	end
	local x = Kit.choose(mem, best, all)
	return Kit.go(x, me.z, 1, { stop = 0.3 })
end

function def.view(inst, _p, v)
	v.inst = inst
end

return def
