--[[
	🔥 Цветная плитка. Табло называет цвет — через несколько секунд вся плитка другого цвета
	проваливается. Потом плитка возвращается с новыми цветами, отсчёт короче. Упал — на балкон.
	Пережил — прошёл. Место — по времени на этаже.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "colors",
	cat = "fire",
	icon = "🎨",
	duration = 45,
	minPlayers = 1,
}

local C = {
	Tile = 6,
	Grid = 8,
	Count = { 4.2, 2.2 }, -- отсчёт до провала: в начале … в конце
	Drop = 1.8, -- плитка внизу
	Pause = 0.8,
	Delay = { medium = { 0.2, 0.6 }, novice = { 0.5, 1.4 } }, -- бот «читает» табло
}
def.C = C

-- Цвета (ключи Strings: color.red …)
def.Colors = {
	{ key = "red", rgb = { 235, 70, 70 } },
	{ key = "blue", rgb = { 60, 120, 240 } },
	{ key = "green", rgb = { 70, 200, 90 } },
	{ key = "yellow", rgb = { 250, 210, 60 } },
	{ key = "purple", rgb = { 160, 80, 220 } },
	{ key = "orange", rgb = { 255, 140, 40 } },
}

local function paint(inst)
	local rng = inst.rng
	local n = #def.Colors
	-- каждый цвет — поровну (± 1), порядок случайный
	local bag = {}
	for i = 1, #inst.tiles do
		bag[i] = (i - 1) % n + 1
	end
	for i = #bag, 2, -1 do
		local j = rng:int(1, i)
		bag[i], bag[j] = bag[j], bag[i]
	end
	for i, s in inst.tiles do
		s.c = bag[i]
		Kit.set(inst, s.name, { color = def.Colors[s.c].rgb })
	end
end

function def.build(inst)
	local n = math.max(C.Grid, math.ceil(math.sqrt(48 + 3 * #inst.list)))
	local half = n * C.Tile / 2
	local z0 = 6
	inst.bounds = { -half + 0.5, half - 0.5, z0 + 0.5, z0 + n * C.Tile - 0.5 }
	inst.tiles = {}
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local s = Kit.solid(inst, {
				name = string.format("C%d_%d", i, j),
				x = -half + (i + 0.5) * C.Tile,
				y = -0.5,
				z = z0 + (j + 0.5) * C.Tile,
				sx = C.Tile,
				sy = 1,
				sz = C.Tile,
				color = { 255, 255, 255 },
				mat = "SmoothPlastic",
			})
			table.insert(inst.tiles, s)
		end
	end
	Kit.part(inst, {
		name = "Board",
		x = 0,
		y = 14,
		z = z0 + n * C.Tile + 2,
		sx = 26,
		sy = 8,
		sz = 1,
		color = { 30, 30, 40 },
		label = "board",
	})
	Kit.part(inst, {
		name = "Swatch",
		x = 0,
		y = 14,
		z = z0 + n * C.Tile + 1.4,
		sx = 10,
		sy = 5,
		sz = 0.4,
		color = { 255, 255, 255 },
		mat = "Neon",
		collide = false,
	})
	paint(inst)
	inst.round = 0
	inst.phase = "wait"
	inst.phaseEnd = 3
	-- на центры плиток в середине поля
	for k, p in inst.list do
		local i = math.floor(n / 2) - 2 + (k - 1) % 4
		local j = math.floor(n / 2) - 1 + math.floor((k - 1) / 4)
		local s = inst.parts[string.format("C%d_%d", math.clamp(i, 0, n - 1), math.clamp(j, 0, n - 1))]
		p.spawn = { s.x, 0, s.z }
		Kit.place(p, s.x, 0, s.z)
	end
	Kit.pub(inst, { phase = "wait", round = 0 })
end

function def.step(inst, _dt)
	local t = inst.t
	if t < inst.phaseEnd then
		return
	end
	if inst.phase == "wait" then
		inst.round += 1
		inst.color = inst.rng:int(1, #def.Colors)
		local k = math.clamp((t - 3) / (inst.duration - 10), 0, 1)
		local count = C.Count[1] + (C.Count[2] - C.Count[1]) * k
		inst.phase = "count"
		inst.phaseEnd = t + count
		Kit.set(inst, "Swatch", { color = def.Colors[inst.color].rgb })
		Kit.pub(
			inst,
			{ phase = "count", round = inst.round, color = def.Colors[inst.color].key, ends = inst.phaseEnd }
		)
	elseif inst.phase == "count" then
		inst.phase = "drop"
		inst.phaseEnd = t + C.Drop
		for _, s in inst.tiles do
			if s.c ~= inst.color then
				Kit.vanish(inst, s.name, true)
			end
		end
		Kit.pub(inst, { phase = "drop" })
	elseif inst.phase == "drop" then
		inst.phase = "wait"
		inst.phaseEnd = t + C.Pause
		for _, s in inst.tiles do
			if not s.alive then
				Kit.vanish(inst, s.name, false)
			end
		end
		paint(inst)
		Kit.set(inst, "Swatch", { color = { 255, 255, 255 } })
		Kit.pub(inst, { phase = "wait", color = nil })
	end
end

-- Голова: прочитать цвет (с задержкой), встать в центр ближайшей плитки этого цвета
function def.bot(view, mem)
	local me = view.me
	local pub = view.pub
	if pub.phase ~= "count" then
		mem.seen = nil
		return Kit.go(me.x, me.z, 0)
	end
	if mem.seen ~= pub.round then
		mem.seen = pub.round
		local d = C.Delay[mem.level] or { 0.3, 1 }
		mem.readAt = view.t + mem.rng:range(d[1], d[2])
		mem.pick = nil
	end
	if view.t < mem.readAt then
		return Kit.go(me.x, me.z, 0)
	end
	if not mem.pick then
		local want = nil
		for i, c in def.Colors do
			if c.key == pub.color then
				want = i
			end
		end
		local best, bd, all = nil, math.huge, {}
		for _, s in view.tiles do
			table.insert(all, s)
			if s.c == want then
				local d = (s.x - me.x) ^ 2 + (s.z - me.z) ^ 2
				if d < bd then
					best, bd = s, d
				end
			end
		end
		if mem.random then
			-- наугад: табло не читает, цвет угадывает по образцу — путает похожие
			local guess = if mem.rng:next() < 0.4 then want else mem.rng:int(1, #def.Colors)
			local list = {}
			for _, s in view.tiles do
				if s.c == guess then
					table.insert(list, s)
				end
			end
			mem.pick = list[mem.rng:int(1, #list)]
		else
			mem.pick = Kit.choose(mem, best, all)
		end
	end
	return Kit.go(mem.pick.x, mem.pick.z, 1, { stop = 0.4 })
end

function def.view(inst, _p, v)
	v.tiles = inst.tiles
end

return def
