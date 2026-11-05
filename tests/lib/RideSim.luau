--[[
	RideSim — поездка на чистой модели: люди под автопилотом той же головы бота.
	  local RideSim = require("./lib/RideSim").make(shared)
	  local ride, info = RideSim.run({ seed = 1, humans = 1, level = "medium", dt = 0.1 })
	info: phases (последовательность), floors (сыгранные), rewards (по людям), maxBalcony,
	time (длина поездки, с), events (если opts.keep).
	opts.onStep(ride, now) — вмешаться (войти/выйти посреди поездки, купить Подвал).
]]

local RideSim = {}

function RideSim.make(shared)
	local Ride = shared("Ride")

	local function run(opts)
		local ride = Ride.new({ seed = opts.seed or 1, now = 0 })
		local dt = opts.dt or 0.1
		local now = 0
		for i = 1, opts.humans or 1 do
			local id = "h" .. i
			Ride.join(ride, id, "Human" .. i, { vip = opts.vip and i == 1, mult = 1 })
			Ride.setAuto(ride, id, opts.level or "medium")
		end
		local info = { phases = {}, floors = {}, rewards = {}, rideRewards = {}, events = {}, outs = 0 }
		local startRide, endRide = nil, nil
		local guard = 0
		local maxT = opts.maxTime or 1500
		while now < maxT do
			guard += 1
			now += dt
			if opts.onStep then
				opts.onStep(ride, now)
			end
			if ride.phase == "cabin" and ride.plan and ride.plan.kind == "vote" and opts.vote ~= false then
				for _, P in Ride.list(ride, "cabin") do
					if not P.bot and not ride.votes[P.id] and ride.rng:next() < 0.2 then
						Ride.vote(ride, P.id, ride.rng:int(1, #ride.plan.options))
					end
				end
			end
			Ride.step(ride, now)
			for _, e in Ride.drain(ride) do
				if opts.keep then
					table.insert(info.events, e)
				end
				if e.t == "phase" then
					if info.phases[#info.phases] ~= e.phase then
						table.insert(info.phases, e.phase)
					end
					if e.phase == "cabin" and not startRide then
						startRide = now
					end
					if e.phase == "lobby" and startRide and not endRide then
						endRide = now
					end
				elseif e.t == "doors" then
					table.insert(info.floors, e.id)
				elseif e.t == "reward" then
					info.rewards[e.id] = info.rewards[e.id] or {}
					table.insert(info.rewards[e.id], e)
				elseif e.t == "rideReward" then
					info.rideRewards[e.id] = e
				elseif e.t == "out" then
					info.outs += 1
				end
			end
			if endRide and not opts.untilTime then
				break
			end
		end
		info.time = if startRide and endRide then endRide - startRide else nil
		info.maxBalcony = ride.stats.maxBalcony
		info.now = now
		return ride, info
	end

	return { run = run }
end

return RideSim
