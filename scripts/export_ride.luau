--[[
	Экспорт поездки ботов в JSON для картинки README:
	  lune run scripts/export_ride.luau [seed] build/ride.json
	Один «человек» под автопилотом (средний) + 3 бота-пассажира. Для каждой остановки:
	этаж, категория, как выбран (голос: какие категории были на кнопках / сюрприз), детали
	этажа из примитивов (вид сверху), итоги (звёзды, прошёл, выбыл ли), длительность.
	Без seed — ищется поездка, где был сюрприз-этаж и хотя бы один выбывший.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Loader = require("../tests/lib/Loader")
local RideSim = require("../tests/lib/RideSim").make(Loader.shared)
local Floors = Loader.shared("Floors")
local Strings = Loader.shared("Strings")
local ru = Strings.ru

local function record(seed)
	local stops = {}
	local cur = nil
	local plan = nil
	local ride, info = RideSim.run({
		seed = seed,
		humans = 1,
		level = "medium",
		keep = true,
		onStep = function(r)
			if r.phase == "cabin" and r.plan then
				plan = r.plan
			end
			if r.phase == "doors" and r.floor and (not cur or cur.inst ~= r.floor) then
				local inst = r.floor
				local parts = {}
				for _, name in inst.order do
					local s = inst.parts[name]
					table.insert(parts, {
						shape = s.shape,
						x = s.x,
						y = s.y,
						z = s.z,
						sx = s.sx,
						sz = s.sz,
						c = s.color or { 200, 200, 200 },
						a = s.alpha or 0,
					})
				end
				local opts = {}
				if plan and plan.kind == "vote" then
					for _, o in plan.options do
						table.insert(
							opts,
							{ cat = o.cat, name = ru["cat." .. o.cat], chosen = o.id == inst.id }
						)
					end
				end
				cur = {
					inst = inst,
					stop = r.stop,
					id = inst.id,
					name = ru["floor." .. inst.id],
					cat = inst.def.cat,
					catName = ru["cat." .. inst.def.cat],
					why = plan and plan.kind == "surprise" and plan.why or nil,
					options = opts,
					parts = parts,
					bounds = inst.bounds,
				}
				table.insert(stops, cur)
			end
		end,
	})
	local k = 0
	for _, e in info.events do
		if e.t == "floorEnd" then
			k += 1
			local rows = {}
			for _, r in e.rows do
				table.insert(rows, {
					name = if r.bot then ru[r.name] or r.name else "Игрок",
					bot = r.bot == true,
					stars = r.stars,
					passed = r.passed,
				})
			end
			if stops[k] then
				stops[k].rows = rows
				stops[k].time = math.floor((stops[k].inst.endT or 0) * 10) / 10
			end
		end
	end
	for _, s in stops do
		s.inst = nil
	end
	return { seed = seed, stops = stops, time = info.time, maxBalcony = ride.stats.maxBalcony }, info
end

local seed = tonumber(process.args[1])
local out = process.args[2] or "build/ride.json"
local data
if seed then
	data = record(seed)
else
	for s = 1, 200 do
		local d, info = record(s)
		local surprise = false
		for _, st in d.stops do
			if st.why == "rare" or st.why == "basement" then
				surprise = true
			end
		end
		if surprise and info.outs > 0 and #d.stops == 10 then
			data = d
			break
		end
	end
end
_ = Floors
fs.writeFile(out, serde.encode("json", data, true))
print("seed " .. data.seed .. " → " .. out)
