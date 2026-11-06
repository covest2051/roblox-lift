--[[
	😌 Кафе — передышка. Стойка с подарком (маленький подарок каждому, раз в день —
	ежедневный подарок), витрина облика (манекены в случайных вещах из магазина),
	фото-зона со вспышкой. Выбывания и мест нет: прошли все.
]]

local Kit = require(script.Parent.Parent.FloorKit)
local Config = require(script.Parent.Parent.Config)

local def = {
	id = "cafe",
	cat = "calm",
	icon = "☕",
	duration = 30,
	minPlayers = 1,
	ranked = false,
}

def.Spots = {
	gift = { x = -12, z = 30 }, -- стойка
	photo = { x = 14, z = 34 }, -- фото-зона
	show = { x = 0, z = 44 }, -- витрина
}

function def.build(inst)
	inst.bounds = { -24, 24, 2, 50 }
	Kit.solid(inst, {
		name = "Floor",
		x = 0,
		y = -0.5,
		z = 26,
		sx = 50,
		sy = 1,
		sz = 50,
		color = { 200, 160, 120 },
		mat = "WoodPlanks",
	})
	local S = def.Spots
	Kit.part(inst, {
		name = "Counter",
		x = S.gift.x,
		y = 2,
		z = S.gift.z + 3,
		sx = 12,
		sy = 4,
		sz = 3,
		color = { 120, 70, 50 },
		mat = "WoodPlanks",
	})
	Kit.part(inst, {
		name = "GiftBox",
		x = S.gift.x,
		y = 5,
		z = S.gift.z + 3,
		sx = 2.5,
		sy = 2.5,
		sz = 2.5,
		color = { 255, 90, 120 },
		mat = "SmoothPlastic",
		collide = false,
	})
	Kit.part(inst, {
		name = "GiftRibbon",
		x = S.gift.x,
		y = 5,
		z = S.gift.z + 3,
		sx = 2.7,
		sy = 0.5,
		sz = 2.7,
		color = { 255, 230, 90 },
		collide = false,
	})
	Kit.part(inst, {
		name = "PhotoFrame",
		x = S.photo.x,
		y = 5,
		z = S.photo.z + 4,
		sx = 10,
		sy = 9,
		sz = 0.6,
		color = { 255, 205, 70 },
		mat = "Foil",
		label = "cafe.photo",
	})
	Kit.part(inst, {
		name = "PhotoBack",
		x = S.photo.x,
		y = 5,
		z = S.photo.z + 4.4,
		sx = 9,
		sy = 8,
		sz = 0.2,
		color = { 120, 220, 220 },
		collide = false,
	})
	for i = 1, 4 do
		local x = S.show.x - 12 + (i - 1) * 8
		Kit.part(inst, {
			name = "Mannequin" .. i,
			x = x,
			y = 3,
			z = S.show.z + 3,
			sx = 1.8,
			sy = 5,
			sz = 1,
			color = { 240, 230, 220 },
		})
		Kit.part(inst, {
			name = "MannequinHead" .. i,
			shape = "Ball",
			x = x,
			y = 6.4,
			z = S.show.z + 3,
			sx = 1.6,
			color = { 240, 230, 220 },
			collide = false,
		})
		Kit.part(inst, {
			name = "Stand" .. i,
			shape = "Disc",
			x = x,
			y = 0.25,
			z = S.show.z + 3,
			sx = 4,
			sy = 0.5,
			color = { 255, 255, 255 },
			mat = "Marble",
		})
	end
	for i = 1, 6 do
		local x, z = -18 + ((i - 1) % 3) * 8, 12 + math.floor((i - 1) / 3) * 8
		Kit.part(inst, {
			name = "Table" .. i,
			shape = "Disc",
			x = x + 14,
			y = 2.5,
			z = z,
			sx = 4,
			sy = 0.4,
			color = { 255, 255, 255 },
			mat = "Marble",
			collide = false,
		})
		Kit.part(inst, {
			name = "Leg" .. i,
			x = x + 14,
			y = 1.2,
			z = z,
			sx = 0.4,
			sy = 2.4,
			sz = 0.4,
			color = { 60, 60, 60 },
			collide = false,
		})
	end
	-- витрина: что надето на манекенах — выбирает сервер по каталогу (облик видят все)
	inst.show = {}
	for i = 1, 4 do
		inst.show[i] = inst.rng:int(1, 1000)
	end
	Kit.spawnRow(inst, 8, 0, 22)
	for _, p in inst.list do
		p.gift, p.photo = false, false
	end
	Kit.pub(inst, { show = inst.show })
end

function def.step(_inst, _dt) end

function def.input(inst, p, a)
	local S = def.Spots
	local R = Config.Floor.ActRange + 1
	if a.t == "gift" then
		if p.gift then
			return false, "done"
		end
		if not Kit.near(p, S.gift.x, S.gift.z, R) then
			return false, "far"
		end
		p.gift = true
		p.score += 1
		Kit.event(inst, { t = "gift", id = p.id })
		return true, nil
	elseif a.t == "photo" then
		if not Kit.near(p, S.photo.x, S.photo.z, R) then
			return false, "far"
		end
		if p.photo and inst.t - p.photo < 2 then
			return false, "wait"
		end
		p.photo = inst.t
		Kit.event(inst, { t = "photo", id = p.id, x = p.x, z = p.z })
		return true, nil
	end
	return false, "bad"
end

function def.score(_inst, p)
	return p.score
end

-- Голова: взять подарок, сфотографироваться, поглазеть на витрину
function def.bot(view, mem)
	local me = view.me
	local S = def.Spots
	if mem.random then
		if not mem.goal or mem.rng:next() < 0.2 then
			mem.goal = { mem.rng:range(-20, 20), mem.rng:range(8, 46) }
		end
		return Kit.go(mem.goal[1], mem.goal[2], 0.6)
	end
	if not me.gift then
		if Kit.near(me, S.gift.x, S.gift.z, 3) then
			return { act = { t = "gift" } }
		end
		return Kit.go(S.gift.x, S.gift.z, 0.7, { stop = 2 })
	end
	if not me.photo then
		if Kit.near(me, S.photo.x, S.photo.z, 3) then
			return { act = { t = "photo" } }
		end
		return Kit.go(S.photo.x, S.photo.z, 0.7, { stop = 2 })
	end
	return Kit.go(S.show.x + ((tonumber(me.id) or 0) % 5 - 2) * 3, S.show.z - 2, 0.5, { stop = 1 })
end

return def
