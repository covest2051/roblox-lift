--[[
	🧠 Музыкальные стулья. Играет музыка — гуляй по кругу. Музыка стихла — из пола всплывают
	стулья (на один меньше, чем игроков): подбеги и «Сесть». Не успел — на балкон.
	Раунды, пока не останется половина. Прошёл — остался. Место — по порядку выбывания.
]]

local Kit = require(script.Parent.Parent.FloorKit)
local Config = require(script.Parent.Parent.Config)

local def = {
	id = "chairs",
	cat = "brain",
	icon = "🪑",
	duration = 58,
	minPlayers = 2,
}

local H = {
	Music = { 3, 5.5 },
	Window = 3.2, -- сколько стулья стоят
	Pause = 1.2,
	R = 20, -- радиус зала
	SitRange = 4,
	React = { medium = { 0.15, 0.5 }, novice = { 0.35, 1.1 }, random = { 0.8, 1.8 } },
}
def.H = H

function def.build(inst)
	inst.bounds = { -H.R, H.R, 6, 6 + 2 * H.R }
	inst.cz = 6 + H.R
	Kit.solid(inst, {
		name = "Floor",
		shape = "Disc",
		x = 0,
		y = -0.5,
		z = inst.cz,
		sx = 2 * H.R + 6,
		sy = 1,
		color = { 230, 200, 120 },
		mat = "WoodPlanks",
	})
	Kit.part(inst, {
		name = "Rug",
		shape = "Disc",
		x = 0,
		y = 0.05,
		z = inst.cz,
		sx = 14,
		sy = 0.1,
		color = { 200, 60, 90 },
		mat = "Fabric",
		collide = false,
	})
	Kit.part(inst, {
		name = "Gramophone",
		x = 0,
		y = 1.5,
		z = inst.cz,
		sx = 2,
		sy = 3,
		sz = 2,
		color = { 120, 80, 40 },
		mat = "WoodPlanks",
	})
	Kit.part(inst, {
		name = "Horn",
		shape = "Ball",
		x = 0,
		y = 4,
		z = inst.cz,
		sx = 3,
		color = { 230, 190, 70 },
		mat = "Foil",
		collide = false,
	})
	local n = #inst.list
	inst.chairs = {}
	for k = 1, math.max(1, n - 1) do
		local c = { k = k, name = "Chair" .. k, x = 0, z = inst.cz, up = false, by = nil }
		table.insert(inst.chairs, c)
		Kit.part(inst, {
			name = c.name,
			x = 0,
			y = -4,
			z = inst.cz,
			sx = 2.6,
			sy = 2.6,
			sz = 2.6,
			color = { 90, 170, 255 },
			collide = false,
		})
		Kit.part(inst, {
			name = c.name .. "Back",
			x = 0,
			y = -4,
			z = inst.cz,
			sx = 2.6,
			sy = 3,
			sz = 0.5,
			color = { 70, 140, 230 },
			collide = false,
		})
	end
	inst.round = 0
	inst.phase = "intro"
	inst.phaseEnd = 3
	inst.alive0 = n
	inst.target = math.max(1, math.ceil(n / 2))
	for i, p in inst.list do
		local a = (i - 1) / n * math.pi * 2
		local x, z = math.cos(a) * 12, inst.cz + math.sin(a) * 12
		p.spawn = { x, 0, z }
		Kit.place(p, x, 0, z)
		p.round = 0
	end
	Kit.pub(inst, { phase = "intro", act = "sit" })
end

local function hideChairs(inst)
	for _, c in inst.chairs do
		c.up, c.by = false, nil
		Kit.set(inst, c.name, { y = -4 })
		Kit.set(inst, c.name .. "Back", { y = -4 })
	end
end

local function raise(inst, count)
	local rng = inst.rng
	local used = {}
	for k, c in inst.chairs do
		if k <= count then
			local x, z
			for _ = 1, 30 do
				local a, r = rng:range(0, math.pi * 2), rng:range(5, H.R - 3)
				x, z = math.cos(a) * r, inst.cz + math.sin(a) * r
				local ok = true
				for _, u in used do
					if (u[1] - x) ^ 2 + (u[2] - z) ^ 2 < 25 then
						ok = false
						break
					end
				end
				if ok then
					break
				end
			end
			table.insert(used, { x, z })
			c.x, c.z, c.up, c.by = x, z, true, nil
			Kit.set(inst, c.name, { x = x, y = 1.3, z = z, color = { 90, 170, 255 } })
			Kit.set(inst, c.name .. "Back", { x = x, y = 3.5, z = z + 1.1 })
		end
	end
end

function def.step(inst, _dt)
	local t = inst.t
	if t < inst.phaseEnd then
		return
	end
	local alive = Kit.active(inst)
	if inst.phase == "intro" or inst.phase == "pause" then
		if #alive <= inst.target then
			inst.phase = "over"
			inst.phaseEnd = math.huge
			return
		end
		inst.round += 1
		inst.phase = "music"
		inst.phaseEnd = t + inst.rng:range(H.Music[1], H.Music[2])
		hideChairs(inst)
		for _, p in alive do
			p.seat = nil
		end
		Kit.pub(inst, { phase = "music", round = inst.round })
	elseif inst.phase == "music" then
		inst.phase = "sit"
		inst.phaseEnd = t + H.Window
		inst.count = #alive - 1
		raise(inst, inst.count)
		Kit.pub(inst, { phase = "sit", chairs = inst.count, ends = inst.phaseEnd })
	elseif inst.phase == "sit" then
		for _, p in alive do
			if not p.seat then
				Kit.out(inst, p, "chair")
			else
				p.round = inst.round
				p.score += 1
			end
		end
		inst.phase = "pause"
		inst.phaseEnd = t + H.Pause
		Kit.pub(inst, { phase = "pause" })
	end
end

function def.input(inst, p, a)
	if a.t ~= "sit" then
		return false, "bad"
	end
	if inst.phase ~= "sit" or p.seat then
		return false, "notNow"
	end
	local c = Kit.nearest(p, inst.chairs, function(c)
		return c.up and not c.by
	end)
	if not c or not Kit.near(p, c.x, c.z, H.SitRange) then
		return false, "far"
	end
	c.by = p.id
	p.seat = c
	p.score += 0.01 * math.max(0, inst.phaseEnd - inst.t) -- кто быстрее сел
	Kit.place(p, c.x, 2.6, c.z)
	Kit.set(inst, c.name, { color = { 255, 205, 70 } })
	Kit.event(inst, { t = "sit", id = p.id, k = c.k })
	return true, nil
end

function def.done(inst)
	return inst.phase == "over"
end

function def.score(_inst, p)
	return p.score
end

-- Голова: в музыку гулять по кругу; стулья всплыли — к ближайшему свободному и «Сесть»
function def.bot(view, mem)
	local me = view.me
	local pub = view.pub
	if me.seat then
		return {}
	end
	if pub.phase == "music" or pub.phase == "pause" or pub.phase == "intro" then
		mem.seen = nil
		if view.t < 3 then
			return {}
		end
		local a = math.atan2(me.z - view.cz, me.x) + 0.6
		return Kit.go(math.cos(a) * 12, view.cz + math.sin(a) * 12, 0.5)
	end
	if pub.phase ~= "sit" then
		return {}
	end
	if mem.seen ~= pub.ends then
		mem.seen = pub.ends
		local r = H.React[mem.level] or { 0.4, 1 }
		mem.wake = view.t + mem.rng:range(r[1], r[2])
		mem.pick = nil
	end
	if view.t < mem.wake then
		return {}
	end
	local free = {}
	local best, bd = nil, math.huge
	for _, c in view.chairs do
		if c.up and not c.by then
			table.insert(free, c)
			local d = (c.x - me.x) ^ 2 + (c.z - me.z) ^ 2
			if d < bd then
				best, bd = c, d
			end
		end
	end
	if mem.pick and (mem.pick.by or not mem.pick.up) then
		mem.pick = nil
	end
	mem.pick = mem.pick or Kit.choose(mem, best, free)
	local c = mem.pick
	if not c then
		return {}
	end
	if Kit.near(me, c.x, c.z, H.SitRange - 0.8) then
		return { act = { t = "sit" } }
	end
	return Kit.go(c.x, c.z, 1, { stop = 1 })
end

function def.view(inst, _p, v)
	v.chairs = inst.chairs
	v.cz = inst.cz
	_ = Config
end

return def
