--[[
	Лобби — холл перед лифтом (сцена, не этаж): ковёр, диванчики, вывеска, фонтанчик-конфетти.
	Игроки гуляют, пока идёт отсчёт; в конце все садятся в кабину.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "lobby",
	cat = "stage",
	icon = "🛗",
	duration = 1e9,
	ranked = false,
}

function def.build(inst)
	inst.bounds = { -28, 28, 1, 44 }
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = 22,
		sx = 60,
		sy = 1,
		sz = 46,
		color = { 220, 205, 180 },
		mat = "WoodPlanks",
	})
	Kit.part(inst, {
		name = "Carpet",
		x = 0,
		y = 0.05,
		z = 18,
		sx = 12,
		sy = 0.1,
		sz = 30,
		color = { 170, 40, 60 },
		mat = "Fabric",
		collide = false,
	})
	Kit.part(
		inst,
		{ name = "WallBack", x = 0, y = 12, z = 45.5, sx = 60, sy = 24, sz = 1, color = { 60, 160, 160 } }
	)
	Kit.part(
		inst,
		{ name = "WallL", x = -30.5, y = 12, z = 22, sx = 1, sy = 24, sz = 46, color = { 70, 175, 170 } }
	)
	Kit.part(
		inst,
		{ name = "WallR", x = 30.5, y = 12, z = 22, sx = 1, sy = 24, sz = 46, color = { 70, 175, 170 } }
	)
	Kit.part(inst, {
		name = "Sign",
		x = 0,
		y = 16,
		z = 44.8,
		sx = 30,
		sy = 6,
		sz = 0.4,
		color = { 255, 205, 70 },
		mat = "Neon",
		label = "sign.title",
	})
	for i, x in { -20, 20 } do
		Kit.solid(inst, {
			name = "Sofa" .. i,
			x = x,
			y = 1,
			z = 32,
			sx = 10,
			sy = 2,
			sz = 4,
			color = { 120, 60, 160 },
			mat = "Fabric",
		})
		Kit.part(inst, {
			name = "SofaBack" .. i,
			x = x,
			y = 2.5,
			z = 34,
			sx = 10,
			sy = 3,
			sz = 1,
			color = { 110, 50, 150 },
			mat = "Fabric",
		})
	end
	Kit.part(inst, {
		name = "Plant1",
		shape = "Ball",
		x = -26,
		y = 3,
		z = 6,
		sx = 5,
		color = { 70, 170, 80 },
		mat = "Grass",
	})
	Kit.part(inst, {
		name = "Plant2",
		shape = "Ball",
		x = 26,
		y = 3,
		z = 6,
		sx = 5,
		color = { 70, 170, 80 },
		mat = "Grass",
	})
	Kit.part(inst, {
		name = "Fountain",
		shape = "Disc",
		x = 0,
		y = 1,
		z = 30,
		sx = 8,
		sy = 2,
		color = { 120, 200, 255 },
		mat = "Glass",
	})
	inst.spawns = {}
	for i = 1, 12 do
		local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
		table.insert(inst.spawns, { -10 + col * 4, 0, 14 + row * 5 })
	end
end

function def.step(_inst, _dt) end

function def.bot(_view, _mem)
	return {}
end

return def
