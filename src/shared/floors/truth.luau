--[[
	🧠 Правда или ложь. Табло показывает утверждение; встань на ЗЕЛЁНУЮ (правда) или
	КРАСНУЮ (ложь) половину. Время вышло — неверная половина и середина проваливаются
	в бассейн с поролоном (на балкон). 5 вопросов. Прошёл — ответил на все.
	Ответ клиенту до раскрытия не уходит (только номер вопроса).
]]

local Kit = require(script.Parent.Parent.FloorKit)
local Questions = require(script.Parent.Parent.Questions)

local def = {
	id = "truth",
	cat = "brain",
	icon = "❓",
	duration = 52,
	minPlayers = 1,
	ranked = false,
}

local Q = {
	Rounds = 5,
	Think = 7,
	Reveal = 2.5,
	Mid = 2, -- полуширина серой середины
	Fall = -3, -- ниже — в поролоне
	Know = { medium = 0.93, novice = 0.72 }, -- бот «знает» ответ с такой вероятностью
}
def.Q = Q

function def.build(inst)
	local rng = inst.rng
	inst.bounds = { -28, 28, 1, 40 }
	Kit.solid(
		inst,
		{ name = "Green", x = -15, y = -0.5, z = 22, sx = 26, sy = 1, sz = 34, color = { 70, 200, 90 } }
	)
	Kit.solid(
		inst,
		{ name = "Red", x = 15, y = -0.5, z = 22, sx = 26, sy = 1, sz = 34, color = { 230, 70, 70 } }
	)
	Kit.solid(
		inst,
		{ name = "Mid", x = 0, y = -0.5, z = 22, sx = 4, sy = 1, sz = 34, color = { 160, 160, 170 } }
	)
	Kit.solid(
		inst,
		{ name = "Entry", x = 0, y = -0.5, z = 2.5, sx = 56, sy = 1, sz = 5, color = { 160, 160, 170 } }
	)
	for i = 1, 40 do
		Kit.part(inst, {
			name = "Foam" .. i,
			x = rng:range(-26, 26),
			y = -10 + rng:range(0, 2),
			z = rng:range(6, 38),
			sx = 3,
			sy = 3,
			sz = 3,
			ry = rng:range(0, 90),
			color = ({ { 255, 220, 90 }, { 120, 200, 255 }, { 255, 140, 200 }, { 140, 240, 160 } })[i % 4 + 1],
			mat = "Foil",
			collide = false,
		})
	end
	Kit.part(inst, {
		name = "Board",
		x = 0,
		y = 12,
		z = 40,
		sx = 36,
		sy = 9,
		sz = 1,
		color = { 30, 30, 40 },
		label = "board",
	})
	Kit.part(inst, {
		name = "SignTrue",
		x = -15,
		y = 6,
		z = 40,
		sx = 10,
		sy = 3,
		sz = 0.6,
		color = { 70, 200, 90 },
		mat = "Neon",
		label = "truth.true",
	})
	Kit.part(inst, {
		name = "SignFalse",
		x = 15,
		y = 6,
		z = 40,
		sx = 10,
		sy = 3,
		sz = 0.6,
		color = { 230, 70, 70 },
		mat = "Neon",
		label = "truth.false",
	})
	-- вопросы без повторов
	local pool = {}
	for i = 1, #Questions.List do
		pool[i] = i
	end
	inst.qs = {}
	for k = 1, Q.Rounds do
		local j = rng:int(k, #pool)
		pool[k], pool[j] = pool[j], pool[k]
		table.insert(inst.qs, Questions.List[pool[k]])
	end
	inst.round = 0
	inst.phase = "intro"
	Kit.spawnRow(inst, 3, 0, 30)
	Kit.pub(inst, { phase = "intro", round = 0, rounds = Q.Rounds })
end

local function roundStart(k: number): number
	return 3 + (k - 1) * (Q.Think + Q.Reveal)
end

function def.step(inst, _dt)
	local t = inst.t
	local k = inst.round
	if inst.phase ~= "think" and k < Q.Rounds and t >= roundStart(k + 1) then
		inst.round = k + 1
		inst.phase = "think"
		Kit.vanish(inst, "Green", false)
		Kit.vanish(inst, "Red", false)
		Kit.vanish(inst, "Mid", false)
		Kit.vanish(inst, "Entry", false)
		Kit.pub(inst, {
			phase = "think",
			round = inst.round,
			q = inst.qs[inst.round].id,
			ends = roundStart(inst.round) + Q.Think,
			answer = nil,
		})
	elseif inst.phase == "think" and t >= roundStart(k) + Q.Think then
		inst.phase = "reveal"
		local truth = inst.qs[k].truth
		Kit.vanish(inst, if truth then "Red" else "Green", true)
		Kit.vanish(inst, "Mid", true)
		Kit.vanish(inst, "Entry", true)
		Kit.pub(inst, { phase = "reveal", answer = truth, ends = roundStart(k) + Q.Think + Q.Reveal })
		for _, p in inst.list do
			if not p.out then
				p.answered = (p.answered or 0) + 1
			end
		end
	elseif inst.phase == "reveal" and t >= roundStart(k) + Q.Think + Q.Reveal - 0.3 and k >= Q.Rounds then
		inst.phase = "done"
	end
	for _, p in inst.list do
		if not p.out and p.y < Q.Fall then
			Kit.out(inst, p, "foam")
		end
	end
end

function def.done(inst)
	return inst.phase == "done"
end

function def.score(_inst, p)
	return (if p.out then 0 else 10) + (p.answered or 0)
end

-- Бот «знает» ответ с вероятностью по уровню (наугад — 50/50); решает один раз на вопрос
function def.bot(view, mem)
	local pub = view.pub
	if pub.phase ~= "think" then
		return mem.intent
	end
	if mem.q ~= pub.q then
		mem.q = pub.q
		local know = Q.Know[mem.level] or 0.5
		if mem.random then
			know = 0.5
		end
		local right = mem.rng:next() < know
		local side = if view.botTruth == right then -1 else 1 -- −1 = зелёная (правда)
		mem.side = side
		mem.spot = { side * mem.rng:range(6, 24), mem.rng:range(8, 36) }
		-- медленный думает дольше перед тем, как пойти
		mem.wait = view.t + (if mem.level == "novice" then mem.rng:range(1, 4) else mem.rng:range(0.3, 2))
	end
	if view.t < mem.wait then
		return {}
	end
	return Kit.go(mem.spot[1], mem.spot[2], 1)
end

-- Только боту (на сервере): правильный ответ, чтобы «знать» его с вероятностью уровня
function def.view(inst, _p, v)
	local q = inst.qs[inst.round]
	v.botTruth = q and q.truth
end

return def
