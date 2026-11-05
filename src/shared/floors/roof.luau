--[[
	Крыша — итоги поездки (сцена, не этаж): пьедестал, флажки, вид на город из кубиков.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "roof",
	cat = "stage",
	icon = "🏙",
	duration = 1e9,
	ranked = false,
}

function def.build(inst)
	inst.bounds = { -30, 30, 1, 56 }
	Kit.solid(inst, {
		name = "Roof",
		x = 0,
		y = -0.5,
		z = 28,
		sx = 64,
		sy = 1,
		sz = 58,
		color = { 150, 150, 160 },
		mat = "Concrete",
	})
	for i, h in { 3, 4.5, 2 } do
		local x = ({ -6, 0, 6 })[i]
		Kit.solid(inst, {
			name = "Podium" .. i,
			x = x,
			y = h / 2,
			z = 40,
			sx = 6,
			sy = h,
			sz = 6,
			color = ({ { 200, 200, 210 }, { 255, 205, 70 }, { 200, 130, 70 } })[i],
		})
	end
	for i = 1, 10 do
		local x = -30 + i * 6
		Kit.part(inst, {
			name = "Flag" .. i,
			x = x,
			y = 6,
			z = 57,
			sx = 3,
			sy = 2,
			sz = 0.2,
			color = ({ { 255, 90, 90 }, { 255, 205, 70 }, { 90, 200, 255 } })[i % 3 + 1],
			collide = false,
		})
	end
	local rng = inst.rng
	for i = 1, 14 do
		local h = rng:range(20, 70)
		Kit.part(inst, {
			name = "City" .. i,
			x = -90 + i * 13,
			y = -60 + h / 2,
			z = 110 + rng:range(0, 40),
			sx = 10,
			sy = h,
			sz = 10,
			color = { 90 + rng:int(0, 60), 110 + rng:int(0, 60), 160 },
			mat = "Glass",
			collide = false,
		})
	end
	local n = #inst.list
	for i, p in inst.list do
		local x = if n == 1 then 0 else -14 + 28 * (i - 1) / math.max(1, n - 1)
		p.spawn = { x, 0, 24 }
		Kit.place(p, x, 0, 24)
	end
end

function def.step(_inst, _dt) end

function def.bot(_view, _mem)
	return {}
end

return def
