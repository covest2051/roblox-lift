--[[
	Этажи на ботах (та же голова, что у ботов-пассажиров). Для каждого этажа:
	  • строится из примитивов (имена уникальны, размеры > 0, материалы из списка);
	  • работает при 1 и при 12 игроках, длится не дольше лимита (30–60 с);
	  • никто не выбывает в первые 3 с;
	  • «ничего не делает» < «наугад» < «новичок» < «средний» (звёзды + доля очков, смешанные забеги);
	  • 🔥 выживание: 4 средних бота проходят в 50–85% случаев.
	Числа печатаются строкой «floor …» — их берёт README.
]]

return function(t)
	local Floors = t.shared("Floors")
	local Config = t.shared("Config")
	local FloorSim = require("./lib/FloorSim").make(t.shared)

	local MATS = {
		SmoothPlastic = true,
		Neon = true,
		Glass = true,
		Ice = true,
		Foil = true,
		Fabric = true,
		WoodPlanks = true,
		Wood = true,
		Basalt = true,
		Slate = true,
		Concrete = true,
		Grass = true,
		Metal = true,
		DiamondPlate = true,
		Marble = true,
		Brick = true,
		Sand = true,
		ForceField = true,
		Plastic = true,
		Cobblestone = true,
		Pebble = true,
	}
	local SHAPES = { Block = true, Ball = true, Disc = true, Cylinder = true, Wedge = true }
	local LEVELS = { "idle", "random", "novice", "medium" }
	local SEEDS = 40

	local real = {}
	for _, id in Floors.Order do
		if not Floors.get(id).stub then
			table.insert(real, id)
		end
	end

	for _, id in real do
		local def = Floors.get(id)

		t.test("floor " .. id .. ": primitives, 1 and 12 players, duration", function()
			t.ok(
				def.duration >= Config.Floor.MinDuration and def.duration <= Config.Floor.MaxDuration,
				"duration in 30–60"
			)
			for _, n in { 1, 12 } do
				local lv = {}
				for i = 1, n do
					lv[i] = "medium"
				end
				local inst, rows, info = FloorSim.run(id, { levels = lv, seed = 5 + n })
				t.eq(#rows, n)
				t.ok(info.t <= def.duration + 1e-6, "ends in time")
				t.ok(inst.bounds ~= nil, "bounds")
				local names = {}
				for _, name in inst.order do
					local s = inst.parts[name]
					t.ok(not names[name], "unique " .. name)
					names[name] = true
					t.ok(SHAPES[s.shape], name .. " shape " .. tostring(s.shape))
					t.ok(s.sx > 0 and s.sy > 0 and s.sz > 0, name .. " size")
					t.ok(s.mat == nil or MATS[s.mat], name .. " material " .. tostring(s.mat))
					if s.color then
						for _, c in s.color do
							t.ok(c >= 0 and c <= 255, name .. " colour")
						end
					end
				end
				t.ok(#inst.order <= 900, "not too many parts: " .. #inst.order)
			end
		end)

		t.test("floor " .. id .. ": nobody is out in the first 3 s; skill order", function()
			local sum = { 0, 0, 0, 0 }
			local passed = { 0, 0, 0, 0 }
			for s = 1, SEEDS do
				local inst, _, info = FloorSim.run(id, { levels = LEVELS, seed = s })
				for _, o in info.outs do
					t.ok(o.t >= Config.Floor.Grace, string.format("out at %.1fs (seed %d)", o.t, s))
				end
				t.eq(inst.graceSaves, 0, "no rule-outs during the grace period")
				for i = 1, 4 do
					sum[i] += info.metric[i]
					if info.byId[i].passed then
						passed[i] += 1
					end
				end
			end
			local m = {}
			for i = 1, 4 do
				m[i] = sum[i] / SEEDS
			end
			local line = string.format(
				"floor %-9s idle %.2f · random %.2f · novice %.2f · medium %.2f",
				id,
				m[1],
				m[2],
				m[3],
				m[4]
			)
			if def.ranked == false and def.cat == "calm" then
				t.ok(m[1] <= m[4] + 1e-9, "calm: idle is not better than medium")
			else
				t.ok(
					m[1] < m[2] and m[2] < m[3] and m[3] < m[4],
					"order idle < random < novice < medium: " .. line
				)
			end
			if def.cat == "fire" then
				local p, total = 0, 0
				for s = 1, 50 do
					local _, rows = FloorSim.run(
						id,
						{ levels = { "medium", "medium", "medium", "medium" }, seed = 1000 + s }
					)
					for _, r in rows do
						total += 1
						if r.passed then
							p += 1
						end
					end
				end
				local rate = p / total
				line ..= string.format(" · 4 medium pass %.0f%%", rate * 100)
				t.ok(rate >= 0.5 and rate <= 0.85, "medium survives 50–85%: " .. line)
			end
			print("    " .. line)
		end)
	end
end
