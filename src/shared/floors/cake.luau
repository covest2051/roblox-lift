--[[
	Заготовка этажа «cake» (заменяется настоящим модулем на этапе 3).
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "cake",
	cat = "coop",
	icon = "🎂",
	duration = 30,
	minPlayers = 1,
}

function def.build(inst)
	inst.bounds = { -30, 30, 2, 60 }
	Kit.solid(
		inst,
		{ name = "Floor", x = 0, y = -0.5, z = 30, sx = 60, sy = 1, sz = 60, color = { 200, 200, 200 } }
	)
	Kit.spawnRow(inst, 6, 0)
end

function def.step(_inst, _dt) end

function def.bot(_view, _mem)
	return {}
end

return def
