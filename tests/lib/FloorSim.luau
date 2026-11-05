--[[
	FloorSim — этаж на чистой модели с ботами (та же голова, что у ботов-пассажиров в игре).
	  local FloorSim = require("./lib/FloorSim").make(shared)
	  local inst, rows, info = FloorSim.run("lava", { levels = { "idle", "random", "novice", "medium" }, seed = 1 })
	rows — Floors.results (по местам), info.outs = { { id, t, reason } }, info.byId[id] = row,
	info.metric[id] = звёзды + 0.5 × (очки / лучшие очки в забеге).
]]

local FloorSim = {}

function FloorSim.make(shared)
	local Floors = shared("Floors")
	local Bots = shared("Bots")

	local function run(id: string, opts)
		local levels = opts.levels
		local roster = {}
		for i, lv in levels do
			roster[i] = { id = i, name = lv .. i, bot = true }
		end
		local seed = opts.seed or 1
		local inst = Floors.new(id, { seed = seed, roster = roster })
		local mems = {}
		for i, lv in levels do
			mems[i] = Bots.mem(lv, seed * 131 + i * 7)
		end
		local dt = opts.dt or 0.1
		local info = { outs = {}, byId = {}, metric = {}, events = {} }
		local guard = 0
		while not inst.over and guard < 100000 do
			guard += 1
			for i, p in inst.list do
				Floors.botStep(inst, p, mems[i], dt)
			end
			Floors.step(inst, dt)
			for _, e in Floors.drainEvents(inst) do
				if e.t == "out" then
					table.insert(info.outs, { id = e.id, t = e.at, reason = e.reason })
				end
				if opts.keepEvents then
					table.insert(info.events, e)
				end
			end
			Floors.Kit.drainChanges(inst)
			if opts.onStep then
				opts.onStep(inst, mems)
			end
		end
		local rows = Floors.results(inst)
		local best = 0
		for _, r in rows do
			info.byId[r.id] = r
			best = math.max(best, r.score)
		end
		for _, r in rows do
			info.metric[r.id] = r.stars + 0.5 * (if best > 0 then math.max(0, r.score) / best else 0)
		end
		info.t = inst.endT or inst.t
		return inst, rows, info
	end

	return { run = run }
end

return FloorSim
