--[[
	Модель поездки: фазы, голосование, боты-пассажиры, вход и выход посреди поездки,
	«Подвал сейчас!», окно оплаты, награды только людям, отладка.
]]

return function(t)
	local Ride = t.shared("Ride")
	local Config = t.shared("Config")
	local Floors = t.shared("Floors")
	local RideSim = require("./lib/RideSim").make(t.shared)

	local function stepUntil(ride, now, fn, maxT)
		local t0 = now
		while not fn() and now - t0 < (maxT or 600) do
			now += 0.1
			Ride.step(ride, now)
		end
		return now, fn()
	end

	t.test("ride: one human + 3 bots, 10 floors, roof, fall, lobby", function()
		local ride, info = RideSim.run({ seed = 11, humans = 1 })
		t.ok(info.time ~= nil, "ride finished")
		t.eq(#info.floors, 10, "10 floors")
		t.eq(Floors.get(info.floors[5]).cat, "boss")
		t.eq(Floors.get(info.floors[10]).cat, "boss")
		local order = table.concat(info.phases, ",")
		t.ok(string.find(order, "lobby,cabin,doors,floor,floorEnd,cabin", 1, true) ~= nil, order)
		t.ok(string.find(order, "floorEnd,roof,fall,lobby", 1, true) ~= nil, order)
		t.eq(#info.rewards.h1, 10, "a reward per floor for the human")
		for id in info.rewards do
			t.ok(string.sub(id, 1, 3) ~= "bot", "bots get no rewards")
		end
		t.ok(info.rideRewards.h1 and info.rideRewards.h1.coins == Config.Rewards.RideBonus, "ride bonus")
		t.eq(ride.phase, "lobby")
	end)

	t.test("ride: bots fill the crew to 4 and leave when people come", function()
		local ride = Ride.new({ seed = 2 })
		Ride.join(ride, "a", "A")
		local now = stepUntil(ride, 0, function()
			return ride.phase == "cabin"
		end)
		t.eq(#Ride.list(ride), 4, "1 human + 3 bots")
		local bots = 0
		for _, P in Ride.list(ride) do
			if P.bot then
				bots += 1
				t.ok(string.sub(P.name, 1, 4) == "bot.", "bot name key " .. P.name)
			end
		end
		t.eq(bots, 3)
		for i = 1, 3 do
			Ride.join(ride, "p" .. i, "P" .. i)
		end
		now = stepUntil(ride, now, function()
			return ride.phase == "cabin" and ride.stop == 2
		end)
		t.eq(#Ride.list(ride), 4, "4 humans, no bots")
		for _, P in Ride.list(ride) do
			t.ok(not P.bot, "no bots with 4 people")
		end
	end)

	t.test("ride: votes — only in the cabin, people only, VIP ×2", function()
		local ride = Ride.new({ seed = 3 })
		Ride.join(ride, "a", "A")
		Ride.join(ride, "v", "V", { vip = true })
		local now = 0
		local voteSeen = false
		for _ = 1, 10 do
			now = stepUntil(ride, now, function()
				return ride.phase == "cabin"
			end)
			if ride.plan.kind == "vote" then
				voteSeen = true
				break
			end
			now = stepUntil(ride, now, function()
				return ride.phase ~= "cabin"
			end)
		end
		t.ok(voteSeen, "a vote happened")
		t.ok(not Ride.vote(ride, "a", 9), "no such button")
		local bot
		for _, P in Ride.list(ride) do
			if P.bot then
				bot = P
			end
		end
		t.ok(bot ~= nil and not Ride.vote(ride, bot.id, 1), "bots don't vote")
		t.ok(Ride.vote(ride, "a", 1) and Ride.vote(ride, "v", 2), "people vote")
		local v = Ride.view(ride, "a")
		t.eq(v.votes[1], 1)
		t.eq(v.votes[2], 2, "VIP vote weighs 2")
		t.eq(v.myVote, 1)
		t.ok(v.options[1].id == nil and v.options[1].cat ~= nil, "the view hides floor names")
		local want = ride.plan.options[2].id
		now = stepUntil(ride, now, function()
			return ride.phase == "doors"
		end)
		t.eq(ride.floorId, want, "VIP's button wins 2:1")
		t.ok(not Ride.vote(ride, "a", 1), "no voting with the doors open")
	end)

	t.test("ride: late joiner waits on the balcony, enters at the next stop", function()
		local ride = Ride.new({ seed = 4 })
		Ride.join(ride, "a", "A")
		local now = stepUntil(ride, 0, function()
			return ride.phase == "floor"
		end)
		local P = Ride.join(ride, "late", "Late")
		t.eq(P.where, "balcony")
		t.ok(ride.floor.byId.late == nil, "not on the floor in progress")
		now = stepUntil(ride, now, function()
			return ride.phase == "cabin"
		end)
		t.eq(P.where, "cabin", "in the cabin at the next stop")
		now = stepUntil(ride, now, function()
			return ride.phase == "floor"
		end)
		t.ok(ride.floor.byId.late ~= nil, "plays the next floor")
		local Q = Ride.join(ride, "late2", "Late2")
		t.eq(Q.where, "balcony")
		Ride.leave(ride, "late2")
		t.ok(ride.people.late2 == nil, "left")
	end)

	t.test("ride: leaving mid-floor, all people gone → idle, no bots", function()
		local ride = Ride.new({ seed = 5 })
		Ride.join(ride, "a", "A")
		Ride.join(ride, "b", "B")
		local now = stepUntil(ride, 0, function()
			return ride.phase == "floor"
		end)
		Ride.leave(ride, "a")
		t.ok(ride.floor.byId.a.out and ride.floor.byId.a.left, "the leaver is out of the floor")
		t.eq(ride.phase, "floor", "the floor goes on")
		Ride.leave(ride, "b")
		t.eq(ride.phase, "idle")
		t.eq(#Ride.list(ride), 0, "bot passengers removed")
		local c0 = ride.clock
		Ride.step(ride, now + 5)
		t.eq(ride.clock, c0, "idle ride does not tick")
		Ride.join(ride, "c", "C")
		t.eq(ride.phase, "lobby", "a new person wakes the lift")
	end)

	t.test("ride: «Basement now!» — next regular floor for everyone, once per ride", function()
		local ride = Ride.new({ seed = 6 })
		Ride.join(ride, "a", "A")
		local now = stepUntil(ride, 0, function()
			return ride.phase == "cabin"
		end)
		Ride.drain(ride)
		local ok = Ride.forceBasement(ride, "A")
		t.ok(ok, "bought in the cabin")
		t.eq(ride.plan.kind, "surprise")
		t.eq(ride.plan.id, "basement", "this stop becomes the basement")
		local ann = false
		for _, e in Ride.drain(ride) do
			if e.t == "announce" and e.name == "A" then
				ann = true
			end
		end
		t.ok(ann, "everyone is told who called it")
		t.ok(not Ride.forceBasement(ride, "A"), "not twice")
		now = stepUntil(ride, now, function()
			return ride.phase == "floor"
		end)
		t.eq(ride.floorId, "basement")
		local ok2, why = Ride.canBasement(ride)
		t.ok(not ok2 and why == "used", "once per ride: " .. tostring(why))
	end)

	t.test("ride: basement bought before a boss waits for the next regular stop", function()
		local ride = Ride.new({ seed = 7 })
		Ride.join(ride, "a", "A")
		local now = stepUntil(ride, 0, function()
			return ride.phase == "floorEnd" and ride.stop == 4
		end)
		t.ok(Ride.forceBasement(ride, "A"))
		now = stepUntil(ride, now, function()
			return ride.phase == "doors" and ride.stop == 5
		end)
		t.eq(Floors.get(ride.floorId).cat, "boss", "boss stays")
		now = stepUntil(ride, now, function()
			return ride.phase == "doors" and ride.stop == 6
		end)
		t.eq(ride.floorId, "basement")
		now = stepUntil(ride, now, function()
			return ride.phase == "floorEnd" and ride.stop == 9
		end)
		local ok, why = Ride.canBasement(ride)
		t.ok(not ok, "after floor 9 nothing regular is left: " .. tostring(why))
	end)

	t.test("ride: payment window holds the cabin once per ride", function()
		local ride = Ride.new({ seed = 8 })
		Ride.join(ride, "a", "A")
		local now = stepUntil(ride, 0, function()
			return ride.phase == "cabin"
		end)
		local e0 = ride.phaseEnd
		t.ok(Ride.holdCabin(ride), "held")
		t.near(ride.phaseEnd, e0 + Config.Ride.PayHold, 1e-6)
		t.ok(not Ride.holdCabin(ride), "only once")
		_ = now
	end)

	t.test("ride: debug — floor, boss, basement, bots, speed, state", function()
		local ride = Ride.new({ seed = 9 })
		Ride.join(ride, "a", "A")
		local now = stepUntil(ride, 0, function()
			return ride.phase == "cabin"
		end)
		t.ok(string.find(Ride.debug(ride, "floor", "truth"), "truth", 1, true) ~= nil)
		now = stepUntil(ride, now, function()
			return ride.phase == "doors"
		end)
		t.eq(ride.floorId, "truth")
		t.ok(string.find(Ride.debug(ride, "state"), "floor=truth", 1, true) ~= nil, "state")
		Ride.debug(ride, "boss")
		now = stepUntil(ride, now, function()
			return ride.phase == "doors" and ride.stop == 2
		end)
		t.eq(Floors.get(ride.floorId).cat, "boss")
		Ride.debug(ride, "basement")
		now = stepUntil(ride, now, function()
			return ride.phase == "doors" and ride.stop == 3
		end)
		t.eq(ride.floorId, "basement")
		Ride.debug(ride, "bots", "6")
		now = stepUntil(ride, now, function()
			return ride.phase == "cabin"
		end)
		t.eq(#Ride.list(ride), 7, "1 + 6 bots")
		Ride.debug(ride, "speed", "4")
		t.eq(ride.speed, 4)
		t.ok(string.find(Ride.debug(ride, "nope"), "unknown", 1, true) ~= nil)
	end)
end
