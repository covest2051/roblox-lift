--[[
	🔥 Тающая плитка. Два слоя плитки над пустотой; плитка тает через миг после того, как
	на неё встали (стоишь — тоже тает). Упал со второго слоя — на балкон. Пережил — прошёл.
	Место — по времени на этаже.
]]

local Kit = require(script.Parent.Parent.FloorKit)

local def = {
	id = "melt",
	cat = "fire",
	icon = "🧊",
	duration = 40,
	minPlayers = 1,
}

local M = {
	Tile = 5,
	Melt = 1.25, -- через сколько тает плитка под ногами
	Layers = { 0, -14 },
	PerPlayer = 18, -- плиток в слое на игрока (+ база)
	Base = 40,
}
def.M = M

local COLORS = { { 120, 220, 255 }, { 170, 240, 255 }, { 200, 180, 255 } }

function def.build(inst)
	local n = math.ceil(math.sqrt(M.Base + M.PerPlayer * #inst.list))
	local half = n * M.Tile / 2
	local z0 = 8
	inst.n = n
	inst.killY = M.Layers[#M.Layers] - 10
	inst.bounds = { -half + 0.5, half - 0.5, 2, z0 + n * M.Tile - 0.5 }
	inst.tiles = {}
	for L, y in M.Layers do
		for i = 0, n - 1 do
			for j = 0, n - 1 do
				local s = Kit.solid(inst, {
					name = string.format("T%d_%d_%d", L, i, j),
					x = -half + (i + 0.5) * M.Tile,
					y = y - 0.5,
					z = z0 + (j + 0.5) * M.Tile,
					sx = M.Tile,
					sy = 1,
					sz = M.Tile,
					color = COLORS[(i + j) % 3 + 1],
					mat = "Ice",
				})
				s.layer, s.i, s.j = L, i, j
				s.meltAt = nil
				table.insert(inst.tiles, s)
			end
		end
	end
	Kit.solid(
		inst,
		{ name = "Porch", x = 0, y = -0.5, z = 4, sx = 2 * half, sy = 1, sz = 4, color = { 160, 160, 170 } }
	)
	inst.porch = inst.parts.Porch
	Kit.spawnRow(inst, z0 + M.Tile * 1.5, 0, math.min(2 * half - 6, 30))
	-- на центр плитки
	for _, p in inst.list do
		local x = (math.floor((p.x + half) / M.Tile) + 0.5) * M.Tile - half
		p.spawn = { x, 0, p.z }
		Kit.place(p, x, 0, p.z)
	end
	Kit.pub(inst, { tiles = #inst.tiles })
end

function def.step(inst, _dt)
	local t = inst.t
	if t < 3 then
		return
	end
	-- крыльцо у двери исчезает после старта
	if inst.porch.alive then
		Kit.vanish(inst, "Porch", true)
	end
	for _, p in inst.list do
		local s = p.on
		if not p.out and p.grounded and s and s.layer and not s.meltAt then
			s.meltAt = t + M.Melt
			Kit.set(inst, s.name, { color = { 255, 255, 255 }, alpha = 0.35 })
		end
	end
	for _, s in inst.tiles do
		if s.meltAt and s.alive and t >= s.meltAt then
			Kit.vanish(inst, s.name, true)
		end
	end
end

-- Голова: на соседнюю целую плитку, где вокруг больше целых и нет соседей-игроков
function def.bot(view, mem)
	local me = view.me
	local inst = view.inst
	local cur = me.on
	if not cur or not cur.layer then
		return mem.intent
	end
	local n = inst.n
	local layer = cur.layer
	local function tileAt(i, j)
		if i < 0 or j < 0 or i >= n or j >= n then
			return nil
		end
		return inst.parts[string.format("T%d_%d_%d", layer, i, j)]
	end
	local function fresh(s)
		return s and s.alive and not s.meltAt
	end
	local taken = {}
	for _, p in view.list do
		if p ~= me and not p.out and p.on then
			taken[p.on] = true
		end
	end
	local cands, best, bestV = {}, nil, -math.huge
	for di = -1, 1 do
		for dj = -1, 1 do
			if di ~= 0 or dj ~= 0 then
				local s = tileAt(cur.i + di, cur.j + dj)
				if s and s.alive then
					table.insert(cands, s)
					if fresh(s) and not taken[s] then
						local v = 0
						for ei = -1, 1 do
							for ej = -1, 1 do
								if fresh(tileAt(s.i + ei, s.j + ej)) then
									v += 1
								end
							end
						end
						v += mem.rng:next() * 0.5
						if di ~= 0 and dj ~= 0 then
							v -= 2.5 -- по диагонали дольше идти
						end
						if v > bestV then
							best, bestV = s, v
						end
					end
				end
			end
		end
	end
	local pick = if mem.random
		then cands[mem.rng:int(1, math.max(1, #cands))]
		else Kit.choose(mem, best, cands)
	if not pick then
		return Kit.go(me.x, me.z, 0)
	end
	-- стоять, пока плитка держит (видно, как она бледнеет), уйти в последний момент
	local left = if cur.meltAt then cur.meltAt - view.t else M.Melt
	if not mem.random and left > 0.75 and not taken[cur] then
		return Kit.go(cur.x, cur.z, 0.5)
	end
	if mem.random and mem.rng:next() < 0.5 then
		return Kit.go(cur.x, cur.z, 0.5)
	end
	return Kit.go(pick.x, pick.z, 1)
end

function def.view(inst, _p, v)
	v.inst = inst
end

return def
