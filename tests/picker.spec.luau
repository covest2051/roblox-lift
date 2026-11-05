--[[
	Подбор этажей: 10 000 поездок со случайными голосами.
	Нет повторов, категория не больше 2 раз подряд, спокойный не чаще раза в 4 этажа,
	боссы на 5 и 10 (разные), сюрприз-остановки (редкие этажи и Подвал) с заданной частотой.
]]

return function(t)
	local Picker = t.shared("Picker")
	local Floors = t.shared("Floors")
	local Config = t.shared("Config")
	local Rng = t.shared("Rng")

	local function playRide(rng, n)
		local st = { history = {}, n = n or 4, bosses = Picker.bossOrder(rng), basementUsed = false }
		local plans = {}
		for stop = 1, Config.Ride.Stops do
			local plan = Picker.plan(stop, st, rng)
			local id
			if plan.kind == "vote" then
				local votes = {}
				for v = 1, rng:int(0, 4) do
					votes[v] = { k = rng:int(1, #plan.options), w = 1 }
				end
				local k = Picker.tally(plan.options, votes, rng)
				id = plan.options[k].id
			else
				id = plan.id
			end
			if id == "basement" then
				st.basementUsed = true
			end
			table.insert(st.history, id)
			table.insert(plans, plan)
		end
		return st.history, plans
	end

	t.test("picker: registry has 16 floors + 2 bosses + 1 secret", function()
		t.eq(#Floors.Order, 19)
		t.eq(#Floors.Bosses, 2)
		t.eq(#Floors.Regular + #Floors.Rare, 16)
		for _, id in Floors.Order do
			local d = Floors.get(id)
			t.ok(Floors.CatIcon[d.cat] ~= nil, id .. " category")
			t.ok(type(d.icon) == "string" and #d.icon > 0, id .. " icon")
		end
	end)

	t.test("picker: options are distinct categories, names hidden in view", function()
		local rng = Rng.new(5)
		local plan = Picker.plan(1, { history = {}, n = 4, bosses = Picker.bossOrder(rng) }, rng)
		for _ = 1, 50 do
			if plan.kind == "vote" then
				break
			end
			plan = Picker.plan(1, { history = {}, n = 4, bosses = Picker.bossOrder(rng) }, rng)
		end
		t.eq(plan.kind, "vote")
		t.eq(#plan.options, 3)
		local seen = {}
		for _, o in plan.options do
			t.ok(not seen[o.cat], "distinct categories")
			seen[o.cat] = true
			t.eq(Floors.get(o.id).cat, o.cat)
		end
	end)

	t.test("picker: tally — VIP weight, tie and no votes are random", function()
		local opts = { { cat = "fire" }, { cat = "race" }, { cat = "coop" } }
		local rng = Rng.new(3)
		local k = Picker.tally(opts, { a = { k = 1, w = 1 }, vip = { k = 2, w = 2 } }, rng)
		t.eq(k, 2, "VIP vote counts twice")
		local hits = { 0, 0, 0 }
		for _ = 1, 3000 do
			local kk = Picker.tally(opts, { a = { k = 1, w = 1 }, b = { k = 3, w = 1 } }, rng)
			hits[kk] += 1
		end
		t.eq(hits[2], 0, "a tie is between the leaders")
		t.ok(math.abs(hits[1] - hits[3]) < 300, "tie is a coin flip")
		local none = { 0, 0, 0 }
		for _ = 1, 3000 do
			local kk = Picker.tally(opts, {}, rng)
			none[kk] += 1
		end
		for i = 1, 3 do
			t.ok(none[i] > 800, "no votes → random")
		end
	end)

	t.test("picker: 10 000 rides — no repeats, categories, calm, bosses, surprises", function()
		local rng = Rng.new(2026)
		local N = 10000
		local regularStops = 0
		local count = {}
		local calmGapMin = math.huge
		for _ = 1, N do
			local h = playRide(rng, 4)
			t.eq(#h, 10)
			local seen = {}
			for i, id in h do
				t.ok(not seen[id], "repeat " .. id)
				seen[id] = true
				local cat = Floors.get(id).cat
				if i == 5 or i == 10 then
					t.eq(cat, "boss", "boss on stop " .. i)
				else
					t.ok(cat ~= "boss", "no boss on a regular stop")
					regularStops += 1
					count[id] = (count[id] or 0) + 1
				end
				if i >= 3 then
					local c1, c2 = Floors.get(h[i - 1]).cat, Floors.get(h[i - 2]).cat
					t.ok(not (cat == c1 and cat == c2), "3 of a category in a row")
				end
			end
			t.ok(h[5] ~= h[10], "two different bosses")
			local lastCalm = nil
			for i, id in h do
				if Floors.get(id).cat == "calm" then
					if lastCalm then
						calmGapMin = math.min(calmGapMin, i - lastCalm)
					end
					lastCalm = i
				end
			end
		end
		t.ok(
			calmGapMin >= Config.Picker.CalmEvery,
			"calm at most once per 4 floors (min gap " .. calmGapMin .. ")"
		)
		local lines = {}
		for _, id in Floors.Rare do
			local f = (count[id] or 0) / regularStops
			table.insert(lines, string.format("%s %.2f%%", id, f * 100))
			t.ok(f >= 0.03 and f <= 0.05, string.format("rare %s per stop %.2f%% (3–5%%)", id, f * 100))
		end
		local fb = (count.basement or 0) / regularStops
		table.insert(lines, string.format("basement %.2f%%", fb * 100))
		t.ok(fb >= 0.015 and fb <= 0.025, string.format("basement per stop %.2f%% (~2%%)", fb * 100))
		local calm = 0
		for id, c in count do
			if Floors.get(id).cat == "calm" then
				calm += c
			end
		end
		table.insert(lines, string.format("calm %.1f%% of regular stops", calm / regularStops * 100))
		for _, id in Floors.Regular do
			t.ok((count[id] or 0) > 0, "every regular floor is played: " .. id)
		end
		print("    picker: " .. table.concat(lines, " · "))
	end)

	t.test("picker: forced basement waits for a regular stop", function()
		local rng = Rng.new(1)
		local st = { history = { "lava", "mirror", "truth", "dark" }, n = 4, bosses = Picker.bossOrder(rng) }
		st.forced = "basement"
		local p5 = Picker.plan(5, st, rng)
		t.eq(Floors.get(p5.id).cat, "boss", "boss stop is not replaced")
		local p6 = Picker.plan(6, st, rng)
		t.eq(p6.id, "basement")
	end)
end
