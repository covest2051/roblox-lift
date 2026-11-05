--[[
	🏁 Каток. Скользкий лёд (разгон и торможение медленные), трамплины подбрасывают, в середине
	полынья — упал в воду: обратно на край (падение считается). Собирай монеты: каждая —
	очко, на месте собранной появляется новая. Прошёл — собрал ≥ 12. Место — по монетам.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "ice",
	cat = "race",
	icon = "⛸",
	duration = 45,
	minPlayers = 1,
	respawn = true,
}

local I = {
	Size = 60,
	Hole = 12, -- полынья в центре
	Coins = 7,
	Pick = 2.6,
	Need = 12,
	Ramp = 58, -- трамплин подбрасывает
}
def.I = I

function def.build(inst)
	local rng = inst.rng
	local h = I.Size / 2
	local cz = 6 + h
	inst.cz = cz
	inst.bounds = { -h + 1, h - 1, 7, 6 + I.Size - 1 }
	inst.killY = -6
	-- лёд вокруг полыньи: 4 куска
	local H = I.Hole / 2
	local pieces = {
		{ "IceN", 0, cz + (H + h) / 2, I.Size, h - H },
		{ "IceS", 0, cz - (H + h) / 2, I.Size, h - H },
		{ "IceW", -(H + h) / 2, cz, h - H, 2 * H },
		{ "IceE", (H + h) / 2, cz, h - H, 2 * H },
	}
	for _, q in pieces do
		Kit.solid(inst, {
			name = q[1],
			x = q[2],
			y = -0.5,
			z = q[3],
			sx = q[4],
			sy = 1,
			sz = q[5],
			color = { 200, 235, 255 },
			mat = "Ice",
			ice = true,
		})
	end
	Kit.part(inst, {
		name = "Water",
		x = 0,
		y = -2,
		z = cz,
		sx = I.Hole,
		sy = 1,
		sz = I.Hole,
		color = { 40, 90, 160 },
		mat = "Glass",
		alpha = 0.3,
		collide = false,
	})
	Kit.solid(
		inst,
		{ name = "Start", x = 0, y = -0.5, z = 4, sx = 20, sy = 1, sz = 6, color = { 150, 150, 160 } }
	)
	for i = 1, 4 do
		local a = (i - 0.5) * math.pi / 2
		local x, z = math.cos(a) * 18, cz + math.sin(a) * 18
		local r = Kit.solid(inst, {
			name = "Ramp" .. i,
			x = x,
			y = 0.2,
			z = z,
			sx = 5,
			sy = 0.4,
			sz = 5,
			color = { 120, 200, 255 },
			mat = "Neon",
			bounce = I.Ramp,
		})
		r.ice = true
	end
	for i, x in { -h - 1, h + 1 } do
		Kit.part(inst, {
			name = "Board" .. i,
			x = x,
			y = 1.5,
			z = cz,
			sx = 1,
			sy = 3,
			sz = I.Size,
			color = { 240, 240, 250 },
		})
	end
	inst.coins = {}
	for i = 1, I.Coins do
		local c = { name = "Coin" .. i }
		table.insert(inst.coins, c)
		Kit.part(inst, {
			name = c.name,
			shape = "Cylinder",
			x = 0,
			y = 2,
			z = 0,
			sx = 0.4,
			sy = 2.4,
			sz = 2.4,
			ry = 0,
			color = { 255, 210, 60 },
			mat = "Neon",
			collide = false,
		})
		def.placeCoin(inst, c)
	end
	_ = rng
	Kit.spawnRow(inst, 4, 0, 16)
	Kit.pub(inst, { need = I.Need })
end

function def.placeCoin(inst, c)
	local rng = inst.rng
	local h = I.Size / 2 - 3
	local x, z
	repeat
		x, z = rng:range(-h, h), inst.cz + rng:range(-h, h)
	until math.abs(x) > I.Hole / 2 + 2 or math.abs(z - inst.cz) > I.Hole / 2 + 2
	c.x, c.z = x, z
	Kit.set(inst, c.name, { x = x, z = z })
end

function def.step(inst, _dt)
	for _, p in inst.list do
		if not p.out then
			-- чекпоинт — край катка ближе к тому месту, где катался
			if p.grounded and p.on and p.on.ice then
				p.checkpoint =
					{ math.clamp(p.x, -I.Size / 2 + 3, I.Size / 2 - 3), 0, inst.cz - I.Size / 2 + 4 }
			end
			for _, c in inst.coins do
				if (p.x - c.x) ^ 2 + (p.z - c.z) ^ 2 < I.Pick * I.Pick and p.y < 5 then
					p.score += 1
					Kit.event(inst, { t = "coin", id = p.id })
					def.placeCoin(inst, c)
				end
			end
		end
	end
end

function def.passed(_inst, p)
	return p.score >= I.Need
end

function def.score(_inst, p)
	return p.score
end

-- Голова: ближайшая монета не за полыньёй; на льду целиться с поправкой на занос
function def.bot(view, mem)
	local me = view.me
	local cz = view.cz
	local function blocked(c)
		-- путь пересекает полынью?
		local steps = 6
		for k = 1, steps - 1 do
			local x = me.x + (c.x - me.x) * k / steps
			local z = me.z + (c.z - me.z) * k / steps
			if math.abs(x) < I.Hole / 2 + 1.5 and math.abs(z - cz) < I.Hole / 2 + 1.5 then
				return true
			end
		end
		return false
	end
	local best, bd, all = nil, math.huge, {}
	for _, c in view.coins do
		table.insert(all, c)
		local d = (c.x - me.x) ^ 2 + (c.z - me.z) ^ 2
		if blocked(c) then
			d *= 4
		end
		if d < bd then
			best, bd = c, d
		end
	end
	local c = if mem.random then all[mem.rng:int(1, #all)] else Kit.choose(mem, best, all)
	if not c then
		return {}
	end
	-- поправка на занос: целиться так, чтобы погасить текущую скорость
	local lead = if mem.random then 0 else 0.35
	local tx = c.x - me.vx * lead
	local tz = c.z - me.vz * lead
	if not mem.random and blocked(c) then
		-- объехать полынью по краю
		local side = if me.x >= 0 then 1 else -1
		tx = side * (I.Hole / 2 + 5)
		tz = me.z + (c.z - me.z) * 0.5
	end
	return Kit.go(tx, tz, 1, { stop = 0.3 })
end

function def.view(inst, _p, v)
	v.coins = inst.coins
	v.cz = inst.cz
end

return def
