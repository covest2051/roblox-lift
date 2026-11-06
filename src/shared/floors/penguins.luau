--[[
	🤝 Пингвины сбежали. Пингвины разбегаются от тех, кто подходит близко (но медленнее
	тебя). Догони и коснись — пингвин пойдёт за тобой гуськом (не больше 2). Приведи в
	вольер — общий счётчик. Набрали норму — прошли все. Место — по вкладу (сколько привёл).
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "penguins",
	cat = "coop",
	icon = "🐧",
	duration = 55,
	minPlayers = 1,
}

local N = {
	W = 64,
	Z0 = 6,
	Z1 = 70,
	Pen = { x = 0, z = 62, hw = 12, hd = 7 }, -- вольер у дальней стены, вход со стороны лифта
	Fear = 8, -- пингвин боится ближе
	Run = 9, -- убегает (медленнее игрока)
	Catch = 2.6, -- коснулся — поймал
	Train = 2, -- сколько пингвинов идёт за одним игроком
	Waddle = 2.5,
	Base = 8,
	PerPlayer = 1,
	Need = 0.6, -- доля пингвинов в вольере
}
def.N = N

local function inPen(x: number, z: number): boolean
	local P = N.Pen
	return math.abs(x - P.x) < P.hw and math.abs(z - P.z) < P.hd
end
def.inPen = inPen

function def.build(inst)
	local rng = inst.rng
	local h = N.W / 2
	inst.bounds = { -h + 1, h - 1, N.Z0, N.Z1 - 1 }
	Kit.solid(inst, {
		name = "Snow",
		x = 0,
		y = -0.5,
		z = (N.Z0 + N.Z1) / 2,
		sx = N.W,
		sy = 1,
		sz = N.Z1 - N.Z0 + 4,
		color = { 240, 245, 255 },
		mat = "Sand",
	})
	local P = N.Pen
	Kit.part(inst, {
		name = "PenFloor",
		x = P.x,
		y = 0.05,
		z = P.z,
		sx = 2 * P.hw,
		sy = 0.1,
		sz = 2 * P.hd,
		color = { 120, 200, 255 },
		mat = "Ice",
		collide = false,
	})
	for i, side in { -1, 1 } do
		Kit.part(inst, {
			name = "PenWall" .. i,
			x = P.x + side * P.hw,
			y = 1.5,
			z = P.z,
			sx = 0.6,
			sy = 3,
			sz = 2 * P.hd,
			color = { 160, 110, 70 },
			mat = "WoodPlanks",
			collide = false,
		})
	end
	Kit.part(inst, {
		name = "PenBack",
		x = P.x,
		y = 1.5,
		z = P.z + P.hd,
		sx = 2 * P.hw,
		sy = 3,
		sz = 0.6,
		color = { 160, 110, 70 },
		mat = "WoodPlanks",
		collide = false,
	})
	Kit.part(inst, {
		name = "PenSign",
		x = P.x,
		y = 5,
		z = P.z + P.hd,
		sx = 8,
		sy = 2,
		sz = 0.4,
		color = { 255, 205, 70 },
		label = "penguins.pen",
	})
	for i = 1, 6 do
		Kit.part(inst, {
			name = "Floe" .. i,
			shape = "Disc",
			x = rng:range(-h + 6, h - 6),
			y = 0.1,
			z = rng:range(14, 50),
			sx = rng:range(4, 8),
			sy = 0.2,
			color = { 200, 230, 255 },
			mat = "Ice",
			collide = false,
		})
	end
	local count = math.min(20, N.Base + N.PerPlayer * #inst.list)
	inst.pengs = {}
	for k = 1, count do
		local pg = {
			k = k,
			name = "Peng" .. k,
			x = rng:range(-h + 6, h - 6),
			z = rng:range(16, 48),
			dir = rng:range(0, math.pi * 2),
			caught = false,
			by = nil,
		}
		table.insert(inst.pengs, pg)
		Kit.part(inst, {
			name = pg.name,
			shape = "Ball",
			x = pg.x,
			y = 1.4,
			z = pg.z,
			sx = 2.6,
			color = { 30, 30, 40 },
			collide = false,
		})
		Kit.part(inst, {
			name = pg.name .. "Belly",
			shape = "Ball",
			x = pg.x,
			y = 1.3,
			z = pg.z - 0.6,
			sx = 1.8,
			color = { 250, 250, 250 },
			collide = false,
		})
	end
	inst.need = math.ceil(count * N.Need)
	inst.caught = 0
	Kit.spawnRow(inst, 8, 0, 24)
	for _, p in inst.list do
		p.carry = 0
	end
	Kit.pub(inst, { caught = 0, need = inst.need, total = count })
end

function def.step(inst, dt)
	local rng = inst.rng
	local h = N.W / 2
	local P = N.Pen
	local t = inst.t
	for _, pg in inst.pengs do
		local vx, vz = 0, 0
		local nx, nz
		if pg.caught then
			-- в вольере гуляет по кругу
			pg.dir += dt * 0.8
			vx, vz = math.cos(pg.dir) * 1.5, math.sin(pg.dir) * 1.5
			nx = math.clamp(pg.x + vx * dt, P.x - P.hw + 1, P.x + P.hw - 1)
			nz = math.clamp(pg.z + vz * dt, P.z - P.hd + 1, P.z + P.hd - 1)
		elseif pg.leader then
			-- идёт гуськом за игроком
			local p = pg.leader
			if p.out then
				pg.leader = nil
				nx, nz = pg.x, pg.z
			else
				local gap = 2.5 * pg.slot
				local dx, dz = pg.x - p.x, pg.z - p.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d > gap then
					nx, nz = p.x + dx / d * gap, p.z + dz / d * gap
				else
					nx, nz = pg.x, pg.z
				end
				vx, vz = (nx - pg.x) / dt, (nz - pg.z) / dt
				if inPen(nx, nz) then
					pg.caught = true
					pg.leader = nil
					p.carry -= 1
					p.contrib += 1
					inst.caught += 1
					Kit.event(inst, { t = "penguin", id = p.id, caught = inst.caught })
					Kit.pub(inst, { caught = inst.caught })
				end
			end
		else
			local fx, fz, scared = 0, 0, false
			for _, p in inst.list do
				if not p.out then
					local dx, dz = pg.x - p.x, pg.z - p.z
					local d2 = dx * dx + dz * dz
					if t >= 3 and d2 < N.Catch * N.Catch and p.carry < N.Train then
						-- поймал: пингвин встаёт в хвост
						p.carry += 1
						pg.leader = p
						pg.slot = p.carry
						Kit.event(inst, { t = "grab", id = p.id })
						scared = false
						fx, fz = 0, 0
						break
					end
					if d2 < N.Fear * N.Fear and d2 > 0.0001 then
						local d = math.sqrt(d2)
						scared = true
						local w = (N.Fear - d) / N.Fear
						fx += dx / d * w
						fz += dz / d * w
					end
				end
			end
			if pg.leader then
				nx, nz = pg.x, pg.z
			else
				if scared then
					local m = math.sqrt(fx * fx + fz * fz)
					if m > 0 then
						vx, vz = fx / m * N.Run, fz / m * N.Run
					end
				else
					if rng:next() < dt * 0.5 then
						pg.dir = rng:range(0, math.pi * 2)
					end
					vx, vz = math.cos(pg.dir) * N.Waddle, math.sin(pg.dir) * N.Waddle
				end
				nx = math.clamp(pg.x + vx * dt, -h + 1.5, h - 1.5)
				nz = math.clamp(pg.z + vz * dt, N.Z0 + 2, P.z - P.hd - 2)
			end
		end
		pg.x, pg.z = nx, nz
		Kit.set(inst, pg.name, { x = nx, z = nz })
		local m = math.sqrt(vx * vx + vz * vz)
		if m > 0.1 then
			Kit.set(inst, pg.name .. "Belly", { x = nx + vx / m * 0.6, z = nz + vz / m * 0.6 })
		end
	end
end

function def.done(inst)
	return inst.caught >= inst.need
end

function def.passed(inst, p)
	return inst.caught >= inst.need and not p.out
end

function def.score(_inst, p)
	return p.contrib
end

-- Голова: догнать ближайшего свободного пингвина; с двумя (или если рядом никого) — в вольер
function def.bot(view, mem)
	local me = view.me
	local P = N.Pen
	local free = {}
	for _, pg in view.pengs do
		if not pg.caught and not pg.leader then
			table.insert(free, pg)
		end
	end
	local home = me.carry >= N.Train or (me.carry > 0 and #free == 0)
	if not home and me.carry > 0 and not mem.random then
		local nearest, d = Kit.nearest(me, free)
		home = nearest == nil or d > 18
	end
	if mem.random then
		if not mem.goal or mem.rng:next() < 0.25 then
			if me.carry > 0 and mem.rng:next() < 0.5 then
				mem.goal = { P.x, P.z }
			elseif #free > 0 then
				local pg = free[mem.rng:int(1, #free)]
				mem.goal = { pg.x, pg.z }
			end
		end
		if mem.goal then
			return Kit.go(mem.goal[1], mem.goal[2], 1)
		end
		return {}
	end
	if home then
		return Kit.go(P.x, P.z, 1, { stop = 1 })
	end
	if #free == 0 then
		return {}
	end
	if not mem.peng or mem.peng.caught or mem.peng.leader or mem.rng:next() < mem.err then
		local best, bv = nil, math.huge
		for _, pg in free do
			local v = (pg.x - me.x) ^ 2 + (pg.z - me.z) ^ 2
			if v < bv then
				best, bv = pg, v
			end
		end
		mem.peng = Kit.choose(mem, best, free)
	end
	return {
		speed = 1,
		stop = 0.2,
		track = function(p)
			local pg = mem.peng
			-- упреждение: куда убежит
			local dx, dz = pg.x - p.x, pg.z - p.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < N.Fear and d > 0.01 then
				return pg.x + dx / d * 2, pg.z + dz / d * 2
			end
			return pg.x, pg.z
		end,
	}
end

function def.view(inst, _p, v)
	v.pengs = inst.pengs
end

return def
