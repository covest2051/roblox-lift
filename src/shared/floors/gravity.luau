--[[
	🔥 Гравитация пляшет (редкий). Острова над пустотой; каждые 6 с гравитация меняется:
	обычная → лунная (прыжок до небес) → тяжёлая (еле подпрыгнешь). В воздухе висят звёзды —
	собирай прыжками. Остров, на котором стоят долго, «устаёт»: мигает и крошится (потом
	вырастает снова). Упал — на балкон. Пережил — прошёл. Место — по звёздам.
]]

local Kit = require(script.Parent.Parent.FloorKit)
local Body = require(script.Parent.Parent.Body)

local def = {
	id = "gravity",
	cat = "fire",
	icon = "🪐",
	duration = 45,
	minPlayers = 1,
	rare = 0.045,
}

local G = {
	Every = 6,
	Modes = {
		normal = 196.2,
		moon = 60,
		heavy = 280,
	},
	Tired = 9, -- столько стоят на острове — и он начинает крошиться
	Warn = 2.5, -- мигает перед тем, как исчезнуть
	Regrow = 6,
	Stars = 7,
	Pick = 3, -- радиус сбора звезды
}
def.G = G

function def.build(inst)
	local rng = inst.rng
	inst.bounds = { -34, 34, 2, 72 }
	inst.isles = {}
	local pts = {}
	local k = 0
	local tries = 0
	local want = 11 + math.floor(#inst.list / 2)
	while #pts < want and tries < 2000 do
		tries += 1
		local x, z = rng:range(-28, 28), rng:range(16, 66)
		local ok = true
		for _, q in pts do
			local d = math.sqrt((q[1] - x) ^ 2 + (q[2] - z) ^ 2)
			if d < 11.5 then
				ok = false
				break
			end
		end
		if ok then
			table.insert(pts, { x, z })
		end
	end
	-- стартовый остров у двери
	table.insert(pts, 1, { 0, 6 })
	for _, q in pts do
		k += 1
		local top = if k == 1 then 0 else rng:range(-1, 6)
		local d = if k == 1 then 16 else rng:range(9, 12)
		local s = Kit.solid(inst, {
			name = "Isle" .. k,
			shape = "Disc",
			x = q[1],
			y = top - 1.5,
			z = q[2],
			sx = d,
			sy = 3,
			color = { 120, 200, 140 },
			mat = "Grass",
		})
		s.load, s.warnAt, s.goneUntil = 0, nil, nil
		table.insert(inst.isles, s)
	end
	inst.stars = {}
	for i = 1, G.Stars do
		local st = { name = "Star" .. i }
		table.insert(inst.stars, st)
		Kit.part(inst, {
			name = st.name,
			shape = "Ball",
			x = 0,
			y = -100,
			z = 0,
			sx = 2,
			color = { 255, 230, 90 },
			mat = "Neon",
			collide = false,
		})
	end
	for _, st in inst.stars do
		def.placeStar(inst, st)
	end
	inst.mode = "normal"
	inst.nextSwitch = 3 + G.Every
	Kit.spawnRow(inst, 6, 0, 12)
	Kit.pub(inst, { mode = "normal", next = inst.nextSwitch })
end

function def.placeStar(inst, st)
	local rng = inst.rng
	local isle = inst.isles[rng:int(2, #inst.isles)]
	local top = isle.y + isle.sy / 2
	st.x = isle.x + rng:range(-2, 2)
	st.z = isle.z + rng:range(-2, 2)
	st.y = top + rng:range(4, 12)
	Kit.set(inst, st.name, { x = st.x, y = st.y, z = st.z })
end

local ORDER = { "moon", "heavy", "normal" }

function def.step(inst, dt)
	local t = inst.t
	if t >= inst.nextSwitch then
		local choices = {}
		for _, m in ORDER do
			if m ~= inst.mode then
				table.insert(choices, m)
			end
		end
		inst.mode = choices[inst.rng:int(1, #choices)]
		inst.gravity = G.Modes[inst.mode]
		inst.nextSwitch = t + G.Every
		Kit.pub(inst, { mode = inst.mode, next = inst.nextSwitch })
	end
	-- острова устают под теми, кто стоит
	local occ = {}
	for _, p in inst.list do
		if not p.out and p.grounded and p.on then
			occ[p.on] = true
		end
	end
	for _, s in inst.isles do
		if s.goneUntil then
			if t >= s.goneUntil then
				s.goneUntil = nil
				s.load = 0
				Kit.vanish(inst, s.name, false)
				Kit.set(inst, s.name, { color = { 120, 200, 140 } })
			end
		elseif s.warnAt then
			if t >= s.warnAt + G.Warn then
				s.warnAt = nil
				s.goneUntil = t + G.Regrow
				Kit.vanish(inst, s.name, true)
			end
		elseif t > 3 then
			if occ[s] then
				s.load += dt
			else
				s.load = math.max(0, s.load - dt * 0.5)
			end
			if s.load >= G.Tired then
				s.warnAt = t
				Kit.set(inst, s.name, { color = { 255, 120, 90 } })
			end
		end
	end
	for _, st in inst.stars do
		for _, p in inst.list do
			if
				not p.out and (p.x - st.x) ^ 2 + (p.y + 2.5 - st.y) ^ 2 + (p.z - st.z) ^ 2 < G.Pick * G.Pick
			then
				p.score += 1
				Kit.event(inst, { t = "star", id = p.id })
				def.placeStar(inst, st)
				break
			end
		end
	end
end

function def.score(_inst, p)
	return p.score + (if p.out then 0 else 0.5)
end

-- Голова: остров устал — перепрыгнуть на свежий; звезда над своим островом — подпрыгнуть
function def.bot(view, mem)
	local me = view.me
	local inst = view.inst
	if not me.grounded then
		return mem.intent
	end
	local cur = me.on
	local g = view.gravity
	local apex = (50 * 50) / (2 * g)
	-- уходить заранее, пока гравитация позволяет прыгнуть далеко
	local heavy = g > 250
	local leaveAt = if heavy then G.Tired - 1 else G.Tired - 4.5
	if cur and not cur.warnAt and (cur.load or 0) < leaveAt and not mem.random then
		-- звезда над этим островом?
		local best, bd = nil, math.huge
		for _, st in inst.stars do
			local h = st.y - (me.y + 2.5)
			if
				(st.x - cur.x) ^ 2 + (st.z - cur.z) ^ 2 < (cur.sx / 2 - 1) ^ 2
				and h > -1
				and h < apex - 0.5
			then
				local d = (st.x - me.x) ^ 2 + (st.z - me.z) ^ 2
				if d < bd then
					best, bd = st, d
				end
			end
		end
		if best then
			local close = bd < 1.5
			return Kit.go(best.x, best.z, 0.6, { jump = close, stop = 0.5 })
		end
		return Kit.go(cur.x, cur.z, 0.4)
	end
	-- пора уходить: ближайший свежий остров в досягаемости
	local cands, best, bestV = {}, nil, -math.huge
	for _, s in inst.isles do
		if s ~= cur and s.alive and not s.warnAt then
			local top = s.y + s.sy / 2
			local gap = Kit.gap(cur, me, s)
			local reach = Kit.reach(top - me.y, g)
			if reach and gap < reach - 3.5 and gap < 14 then
				table.insert(cands, s)
				local v = -gap - (s.load or 0)
				if v > bestV then
					best, bestV = s, v
				end
			end
		end
	end
	if mem.random and cur and not cur.warnAt and mem.rng:next() < 0.6 then
		return Kit.go(cur.x, cur.z, 0.4)
	end
	local pick = Kit.choose(mem, best, cands)
	if not pick then
		return Kit.go(if cur then cur.x else me.x, if cur then cur.z else me.z, 0.4)
	end
	return Kit.go(pick.x, pick.z, 1, { edgeJump = true })
end

function def.view(inst, _p, v)
	v.inst = inst
	_ = Body
end

return def
