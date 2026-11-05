--[[
	Picker — подбор следующего этажа (чистые функции).

	Правила:
	  • 5-я и 10-я остановки — боссы (два разных, порядок случайный);
	  • этаж не повторяется в поездке;
	  • одна категория не больше Config.Picker.MaxSameCat раз подряд;
	  • спокойный — не чаще раза в Config.Picker.CalmEvery этажей;
	  • minPlayers этажа ≤ числа участников;
	  • сюрприз-остановки: Подвал (Config.Picker.Basement) и редкие этажи (def.rare) — лифт
	    «сам решил», голосования нет; «Подвал сейчас!» (покупка) и отладка — принудительно;
	  • иначе — голосование: до 3 кнопок разных категорий, этаж внутри категории скрыт.

	plan = { kind = "vote", options = { { cat, id } } } | { kind = "surprise", id, why }
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Floors = require(Shared.Floors)

local Picker = {}

-- Случайный порядок боссов на поездку
function Picker.bossOrder(rng): { string }
	local b = table.clone(Floors.Bosses)
	if #b >= 2 and rng:next() < 0.5 then
		b[1], b[2] = b[2], b[1]
	end
	return b
end

function Picker.isBossStop(stop: number): boolean
	return table.find(Config.Ride.Bosses, stop) ~= nil
end

--[[
	Можно ли этаж id на этой остановке. st = { history = { id... }, n = участников }
]]
function Picker.eligible(id: string, st): boolean
	local def = Floors.get(id)
	if not def or table.find(st.history, id) then
		return false
	end
	if (def.minPlayers or 1) > (st.n or 1) then
		return false
	end
	local h = st.history
	local cat = def.cat
	local same = Config.Picker.MaxSameCat
	if #h >= same then
		local all = true
		for i = #h - same + 1, #h do
			if Floors.get(h[i]).cat ~= cat then
				all = false
				break
			end
		end
		if all then
			return false
		end
	end
	if cat == "calm" then
		for i = math.max(1, #h - Config.Picker.CalmEvery + 2), #h do
			if Floors.get(h[i]).cat == "calm" then
				return false
			end
		end
	end
	return true
end

local function shuffle(rng, list)
	for i = #list, 2, -1 do
		local j = rng:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

--[[
	План остановки stop (1..Stops). st = { history, n, bosses, forced?, basementUsed? }
]]
function Picker.plan(stop: number, st, rng)
	if Picker.isBossStop(stop) then
		local i = table.find(Config.Ride.Bosses, stop) :: number
		local id = st.bosses[i] or Floors.Bosses[1]
		if table.find(st.history, id) then
			-- запасной: другой босс
			for _, b in Floors.Bosses do
				if not table.find(st.history, b) then
					id = b
				end
			end
		end
		return { kind = "surprise", id = id, why = "boss" }
	end
	if st.forced then
		return { kind = "surprise", id = st.forced, why = st.forcedWhy or "debug" }
	end
	if not st.basementUsed and rng:next() < Config.Picker.Basement then
		return { kind = "surprise", id = "basement", why = "basement" }
	end
	for _, id in Floors.Rare do
		local def = Floors.get(id)
		if Picker.eligible(id, st) and rng:next() < def.rare then
			return { kind = "surprise", id = id, why = "rare" }
		end
	end
	-- голосование: категории с доступными обычными этажами
	local byCat = {}
	local cats = {}
	for _, id in Floors.Regular do
		if Picker.eligible(id, st) then
			local c = Floors.get(id).cat
			if not byCat[c] then
				byCat[c] = {}
				table.insert(cats, c)
			end
			table.insert(byCat[c], id)
		end
	end
	table.sort(cats)
	shuffle(rng, cats)
	local options = {}
	for i = 1, math.min(Config.Picker.Options, #cats) do
		local c = cats[i]
		local list = byCat[c]
		table.insert(options, { cat = c, id = list[rng:int(1, #list)] })
	end
	if #options == 0 then
		-- всё сыграно (не бывает при 10 остановках, но на всякий случай): любой несыгранный
		for _, id in Floors.Regular do
			if not table.find(st.history, id) then
				return { kind = "surprise", id = id, why = "fallback" }
			end
		end
		return { kind = "surprise", id = Floors.Regular[rng:int(1, #Floors.Regular)], why = "fallback" }
	end
	return { kind = "vote", options = options }
end

--[[
	Итог голосования. votes = { [кто] = { k, w } } (w — вес, VIP ×2).
	Ничья — случайно среди лидеров; никто не голосовал — случайно.
]]
function Picker.tally(options, votes, rng): (number, { number })
	local sum = {}
	for i = 1, #options do
		sum[i] = 0
	end
	local any = false
	for _, v in votes do
		if sum[v.k] then
			sum[v.k] += v.w
			any = true
		end
	end
	if not any then
		return rng:int(1, #options), sum
	end
	local best, lead = -1, {}
	for i, s in sum do
		if s > best then
			best, lead = s, { i }
		elseif s == best then
			table.insert(lead, i)
		end
	end
	return lead[rng:int(1, #lead)], sum
end

return Picker
