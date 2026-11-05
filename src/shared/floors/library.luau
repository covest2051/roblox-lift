--[[
	🧠 Библиотекарь. Дойди до стойки библиотекарши. Пока она читает — иди; страница
	шуршит — она сейчас обернётся; обернулась и видит, что ты шевелишься (идёшь или прыгаешь) —
	«Тсс!» и ты улетаешь на балкон. Прошёл — дошёл до стойки. Место — по времени.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "library",
	cat = "brain",
	icon = "📚",
	duration = 45,
	minPlayers = 1,
	freeze = true,
}

local L = {
	Read = { 2.2, 4.5 }, -- читает
	Turn = 0.8, -- шуршит страница — сейчас обернётся
	Watch = { 1.8, 3.2 }, -- смотрит
	Grace = 0.25, -- в первый миг взгляда ещё можно остановиться
	Move = 2.5, -- быстрее (studs/с) — «шевелится»
	Goal = 84, -- стойка
}
def.L = L

function def.build(inst)
	local rng = inst.rng
	inst.bounds = { -16, 16, 2, 88 }
	inst.speedMul = 0.5 -- в библиотеке — на цыпочках
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = 45,
		sx = 32,
		sy = 1,
		sz = 90,
		color = { 150, 100, 70 },
		mat = "WoodPlanks",
	})
	Kit.part(inst, {
		name = "Carpet",
		x = 0,
		y = 0.05,
		z = 45,
		sx = 10,
		sy = 0.1,
		sz = 84,
		color = { 60, 110, 70 },
		mat = "Fabric",
		collide = false,
	})
	for i = 1, 10 do
		for side = -1, 1, 2 do
			local z = 8 + (i - 1) * 8
			Kit.part(inst, {
				name = string.format("Shelf%d_%d", i, side),
				x = side * 15,
				y = 6,
				z = z,
				sx = 2,
				sy = 12,
				sz = 6,
				color = { 110, 70, 40 },
				mat = "WoodPlanks",
			})
			for b = 1, 3 do
				Kit.part(inst, {
					name = string.format("Books%d_%d_%d", i, side, b),
					x = side * 13.8,
					y = 2 + b * 3,
					z = z + rng:range(-1, 1),
					sx = 0.6,
					sy = 2,
					sz = 4.5,
					color = ({ { 200, 60, 60 }, { 60, 120, 200 }, { 230, 190, 60 }, { 90, 170, 90 } })[rng:int(
						1,
						4
					)],
					collide = false,
				})
			end
		end
	end
	Kit.part(inst, {
		name = "Desk",
		x = 0,
		y = 2,
		z = L.Goal + 2,
		sx = 14,
		sy = 4,
		sz = 3,
		color = { 120, 80, 50 },
		mat = "WoodPlanks",
	})
	-- библиотекарша из примитивов (сервер поворачивает модель целиком по ry)
	Kit.part(inst, {
		name = "Librarian",
		x = 0,
		y = 5,
		z = L.Goal + 5,
		sx = 3,
		sy = 6,
		sz = 2,
		ry = 180,
		color = { 140, 60, 120 },
		collide = false,
	})
	Kit.part(inst, {
		name = "LibHead",
		shape = "Ball",
		x = 0,
		y = 9.2,
		z = L.Goal + 5,
		sx = 2.6,
		color = { 240, 200, 170 },
		collide = false,
	})
	Kit.part(inst, {
		name = "LibBun",
		shape = "Ball",
		x = 0,
		y = 10.6,
		z = L.Goal + 5.4,
		sx = 1.4,
		color = { 90, 60, 40 },
		collide = false,
	})
	Kit.part(inst, {
		name = "LibGlasses",
		x = 0,
		y = 9.3,
		z = L.Goal + 3.6,
		sx = 2.2,
		sy = 0.5,
		sz = 0.2,
		color = { 30, 30, 30 },
		collide = false,
	})
	Kit.part(inst, {
		name = "Book",
		x = 0,
		y = 7,
		z = L.Goal + 6.4,
		sx = 2.4,
		sy = 1.6,
		sz = 0.3,
		color = { 200, 60, 60 },
		collide = false,
	})
	inst.state = "read"
	inst.stateEnd = 3 + rng:range(L.Read[1], L.Read[2])
	Kit.spawnRow(inst, 6, 0, 22)
	Kit.pub(inst, { state = "read", goal = L.Goal })
end

local function face(inst, watching: boolean)
	-- спиной к залу, когда читает; лицом — когда смотрит
	local z = L.Goal + 5
	Kit.set(inst, "Librarian", { ry = if watching then 180 else 0 })
	Kit.set(inst, "LibGlasses", { z = if watching then z - 1.4 else z + 1.4 })
	Kit.set(inst, "LibBun", { z = if watching then z + 0.4 else z - 0.4 })
	Kit.set(inst, "Book", { z = if watching then z - 1.4 else z + 1.4 })
end

function def.start(inst)
	face(inst, false)
end

function def.step(inst, _dt)
	local t = inst.t
	local rng = inst.rng
	if t >= inst.stateEnd then
		if inst.state == "read" then
			inst.state = "turn"
			inst.stateEnd = t + L.Turn
		elseif inst.state == "turn" then
			inst.state = "watch"
			inst.watchFrom = t
			inst.stateEnd = t + rng:range(L.Watch[1], L.Watch[2])
			face(inst, true)
		else
			inst.state = "read"
			inst.stateEnd = t + rng:range(L.Read[1], L.Read[2])
			face(inst, false)
		end
		Kit.pub(inst, { state = inst.state, ends = inst.stateEnd })
	end
	for _, p in inst.list do
		if not p.out and not p.finished then
			if inst.state == "watch" and t >= inst.watchFrom + L.Grace then
				local moving = (p.spd or 0) > L.Move or (not p.grounded and math.abs(p.vy or 0) > 4)
				if moving then
					Kit.out(inst, p, "shh")
				end
			end
			if not p.out and p.z >= L.Goal then
				p.finished = t
				Kit.event(inst, { t = "finish", id = p.id, at = t })
			end
		end
	end
end

function def.done(inst)
	for _, p in inst.list do
		if not p.out and not p.finished then
			return false
		end
	end
	return true
end

function def.passed(_inst, p)
	return p.finished ~= nil and not p.out
end

function def.score(inst, p)
	if p.finished then
		return 100 + inst.duration - p.finished
	end
	if p.out then
		return 0
	end
	return p.z / 10
end

-- Голова: идти, пока читает; услышал шорох — замереть (реакция = скорость «головы»)
function def.bot(view, mem)
	local me = view.me
	if me.finished then
		return {}
	end
	local st = view.pub.state
	if mem.random then
		-- наугад: на каждый сигнал решает подбросом монетки (3 из 4 — замереть)
		local phase = st .. tostring(view.pub.ends)
		if mem.phase ~= phase then
			mem.phase = phase
			mem.go = if st == "read" then mem.rng:next() < 0.8 else mem.rng:next() < 0.25
		end
		if mem.go then
			return Kit.go(me.x, L.Goal + 2, 1)
		end
		return {}
	end
	if st == "read" then
		-- ошибка: замешкался
		if mem.rng:next() < mem.err * 0.5 then
			return {}
		end
		return Kit.go(me.x * 0.95, L.Goal + 2, 1)
	end
	-- шорох или смотрит — стоять (новичок иногда не замечает шороха)
	if st == "turn" and mem.rng:next() < mem.err then
		return Kit.go(me.x, L.Goal + 2, 1)
	end
	return {}
end

return def
