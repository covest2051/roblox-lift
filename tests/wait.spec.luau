--[[
	Поездка на ботах целиком (настоящие этажи): длина поездки и скука на балконе.
	  • поездка 10 этажей — 7–11 минут (обычно 8–10) (с кабиной, итогами, крышей и падением);
	  • самое долгое ожидание на балконе за поездку (выбыл → снова в кабине) ограничено;
	  • вошедший посреди этажа ждёт не дольше одного этажа.
	Числа печатаются строкой «ride …» — их берёт README.
]]

return function(t)
	local Ride = t.shared("Ride")
	local RideSim = require("./lib/RideSim").make(t.shared)

	local MAX_WAIT = 64 -- с

	t.test("ride length and the longest balcony wait (bots)", function()
		local times, waits = {}, {}
		local worst = 0
		for s = 1, 24 do
			local level = if s % 2 == 0 then "novice" else "medium"
			local _, info = RideSim.run({ seed = 300 + s, humans = 1 + s % 4, level = level })
			t.ok(info.time ~= nil, "ride finished (seed " .. s .. ")")
			table.insert(times, info.time)
			table.insert(waits, info.maxBalcony)
			worst = math.max(worst, info.maxBalcony)
		end
		table.sort(times)
		table.sort(waits)
		local med = times[math.floor(#times / 2) + 1]
		t.ok(
			times[1] >= 7 * 60 and times[#times] <= 11 * 60,
			string.format("ride %.1f–%.1f min", times[1] / 60, times[#times] / 60)
		)
		t.ok(worst <= MAX_WAIT, string.format("longest balcony wait %.0fs ≤ %ds", worst, MAX_WAIT))
		print(
			string.format(
				"    ride: length %.1f–%.1f min (median %.1f) · longest balcony wait %.0f s (median of rides %.0f s)",
				times[1] / 60,
				times[#times] / 60,
				med / 60,
				worst,
				waits[math.floor(#waits / 2) + 1]
			)
		)
	end)

	t.test("a late joiner waits at most one floor", function()
		local joinedAt, enteredAt = nil, nil
		local ride = RideSim.run({
			seed = 77,
			humans = 1,
			maxTime = 400,
			untilTime = true,
			onStep = function(r, now)
				if not joinedAt and r.phase == "floor" and r.floor and r.floor.t > 1 then
					Ride.join(r, "late", "Late")
					joinedAt = now
				end
				if joinedAt and not enteredAt and r.people.late and r.people.late.where == "cabin" then
					enteredAt = now
				end
			end,
		})
		t.ok(joinedAt and enteredAt, "joined and entered the cabin")
		local w = enteredAt - joinedAt
		t.ok(w <= 60 + 5, string.format("waited %.0fs", w))
		_ = ride
	end)
end
