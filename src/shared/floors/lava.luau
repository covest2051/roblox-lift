--[[
	🔥 Пол — лава. Платформы над лавой; занятая платформа медленно тонет, пустая всплывает
	обратно; лава поднимается. Коснулся лавы — смешно улетел на балкон. Пережил — прошёл.
	Место — по времени на этаже.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "lava",
	cat = "fire",
	icon = "🌋",
	duration = 45,
	minPlayers = 1,
}

local P = {
	Lava0 = -3, -- уровень лавы в начале
	Rise = 0.07, -- подъём лавы (studs/с) после первых 3 с
	Sink = 0.45, -- занятая платформа тонет
	Float = 0.35, -- пустая всплывает к своей высоте
	Grid = 5, -- платформ по стороне
	Gap = 10.5, -- шаг сетки
}
def.P = P

function def.build(inst)
	local rng = inst.rng
	local n = math.max(P.Grid, math.ceil(math.sqrt(10 + #inst.list * 2.2)))
	local half = (n - 1) * P.Gap / 2
	local z0 = 14
	inst.bounds = { -half - 8, half + 8, 1, z0 + 2 * half + 8 }
	inst.lava = P.Lava0
	inst.plats = {}
	Kit.part(inst, {
		name = "Lava",
		x = 0,
		y = P.Lava0 - 5,
		z = z0 + half,
		sx = 2 * half + 30,
		sy = 10,
		sz = 2 * half + 30,
		color = { 255, 110, 30 },
		mat = "Neon",
		collide = false,
	})
	-- пристань у двери (тоже тонет)
	local dock = Kit.solid(inst, {
		name = "Dock",
		x = 0,
		y = 1,
		z = 5,
		sx = 26,
		sy = 2,
		sz = 7,
		color = { 150, 110, 80 },
		mat = "WoodPlanks",
	})
	dock.base = 2
	table.insert(inst.plats, dock)
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local x = -half + i * P.Gap + rng:range(-1.5, 1.5)
			local z = z0 + j * P.Gap + rng:range(-1.5, 1.5)
			local d = rng:range(7, 9.5)
			local top = rng:range(1.5, 4.5)
			local s = Kit.solid(inst, {
				name = string.format("Plat_%d_%d", i, j),
				shape = "Disc",
				x = x,
				y = top - 2,
				z = z,
				sx = d,
				sy = 4,
				color = { 90, 80, 90 },
				mat = "Basalt",
			})
			s.base = top
			table.insert(inst.plats, s)
		end
	end
	for k = 1, 6 do
		Kit.part(inst, {
			name = "Rock" .. k,
			shape = "Ball",
			x = rng:range(-half, half),
			y = P.Lava0 + 1,
			z = z0 + rng:range(0, 2 * half),
			sx = rng:range(2, 4),
			color = { 60, 50, 50 },
			mat = "Basalt",
			collide = false,
		})
	end
	Kit.spawnRow(inst, 5, 2, 20)
	Kit.pub(inst, { lava = inst.lava })
end

function def.step(inst, dt)
	local t = inst.t
	local G = 3
	if t > G then
		inst.lava = P.Lava0 + P.Rise * (t - G)
	end
	-- кто на какой платформе
	local occ = {}
	for _, p in inst.list do
		if not p.out and p.grounded and p.on then
			occ[p.on] = true
		end
	end
	for _, s in inst.plats do
		local top = s.y + s.sy / 2
		local newTop = top
		if t > G and occ[s] then
			newTop = top - P.Sink * dt
		elseif top < s.base then
			newTop = math.min(s.base, top + P.Float * dt)
		end
		if math.abs(newTop - top) > 1e-6 then
			local warm = math.clamp(1 - (newTop - inst.lava) / 4, 0, 1)
			Kit.set(inst, s.name, {
				y = newTop - s.sy / 2,
				color = {
					90 + math.floor(150 * warm),
					80 + math.floor(20 * warm),
					90 - math.floor(60 * warm),
				},
			})
			-- стоящие на платформе опускаются вместе с ней
			for _, p in inst.list do
				if p.on == s and not p.out then
					p.y = newTop
				end
			end
		end
	end
	if t <= G then
		for _, p in inst.list do
			if p.y < inst.lava then
				Kit.respawn(inst, p, true)
			end
		end
	else
		Kit.set(inst, "Lava", { y = inst.lava - 5 })
		for _, p in inst.list do
			if not p.out and p.y < inst.lava + 0.2 then
				Kit.out(inst, p, "lava")
			end
		end
	end
	if math.floor(t) ~= math.floor(t - dt) then
		Kit.pub(inst, { lava = math.floor(inst.lava * 10) / 10 })
	end
end

-- Голова: стоять на высокой платформе без соседей; ниже соседних или тонет — прыгнуть на лучшую
function def.bot(view, mem)
	local me = view.me
	local inst = view.inst
	if not me.grounded then
		return mem.intent
	end
	local cur = me.on
	local lava = inst.lava
	local curTop = if cur then cur.y + cur.sy / 2 else me.y
	local crowd = {}
	for _, p in view.list do
		if not p.out and p.on and p ~= me then
			crowd[p.on] = (crowd[p.on] or 0) + 1
		end
	end
	local function value(s)
		local top = s.y + s.sy / 2
		local v = top - lava - (crowd[s] or 0) * 2
		if s.name == "Dock" then
			v -= 3
		end
		return v
	end
	local cands, best, bestV = {}, nil, -math.huge
	for _, s in inst.plats do
		if s ~= cur then
			local top = s.y + s.sy / 2
			-- зазор между краями: прыгаем с края своей платформы
			local d = Kit.gap(cur, me, s)
			local reach = Kit.reach(top - me.y, view.gravity)
			if reach and d < reach - 3 and top > lava + 0.8 then
				table.insert(cands, s)
				local v = value(s) - d * 0.15
				if v > bestV then
					best, bestV = s, v
				end
			end
		end
	end
	if mem.random then
		-- наугад: прыгает на случайную соседнюю, когда вздумается
		if mem.target and mem.target ~= cur and mem.target.y + mem.target.sy / 2 > lava then
			return Kit.go(mem.target.x, mem.target.z, 1, { edgeJump = true })
		end
		if cur and mem.rng:next() < 0.75 then
			return Kit.go(cur.x, cur.z, 0.6)
		end
		mem.target = if #cands > 0 then cands[mem.rng:int(1, #cands)] else nil
		return mem.intent
	end
	local curV = if cur then value(cur) else -math.huge
	local stay = cur ~= nil and curTop - lava > 2.5 and curV >= bestV - 1.5
	if stay or not best then
		mem.target = nil
		return Kit.go(if cur then cur.x else me.x, if cur then cur.z else me.z, 0.6)
	end
	local pick = Kit.choose(mem, best, cands)
	mem.target = pick
	return Kit.go(pick.x, pick.z, 1, { edgeJump = true })
end

function def.view(inst, _p, v)
	v.inst = inst
end

return def
