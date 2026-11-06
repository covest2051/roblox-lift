--[[
	Анти-чит на чистой модели: клиент шлёт только намерения, сервер проверяет фазу, место,
	расстояние и время; позиция для правил двигается не быстрее Config.Floor.MaxSpeed.
]]

return function(t)
	local Floors = t.shared("Floors")
	local Config = t.shared("Config")

	local function solo(id)
		return Floors.new(id, { seed = 4, roster = { { id = "h", name = "H" } } })
	end

	t.test("anti-cheat: teleport to the race button is not a finish", function()
		local inst = solo("mirror")
		local p = inst.byId.h
		local f = inst.nodes[#inst.nodes]
		for _ = 1, 40 do
			inst.t += 0.1
			Floors.setPos(inst, "h", p.x, p.y, p.z, 0.1)
		end
		Floors.setPos(inst, "h", f[1], 0, f[2] + 2, 0.1)
		Floors.step(inst, 0.1)
		t.ok(p.finished == nil, "not finished")
		t.ok((p.clamped or 0) > 0, "the jump was clamped")
		t.ok(math.abs(p.z - f[2]) > 20, "the rule position stayed near the start")
	end)

	t.test("anti-cheat: press, sit and gift only up close and in time", function()
		local dark = solo("dark")
		local ok, why = Floors.input(dark, "h", { t = "press" })
		t.ok(not ok and why == "far", "press from afar")
		local sw = dark.switches[1]
		dark.byId.h.x, dark.byId.h.z = sw.x + Config.Floor.ActRange - 1, sw.z
		t.ok((Floors.input(dark, "h", { t = "press" })), "press up close")
		local chairs = Floors.new(
			"chairs",
			{ seed = 2, roster = { { id = "h", name = "H" }, { id = "b", name = "B" } } }
		)
		t.ok(not Floors.input(chairs, "h", { t = "sit" }), "no sitting while the music plays")
		local cafe = solo("cafe")
		t.ok(not Floors.input(cafe, "h", { t = "gift" }), "gift from the door is refused")
		t.ok(not Floors.input(cafe, "h", { t = "hack" }), "unknown intent")
		t.ok(not Floors.input(cafe, "h", "gift"), "not a table")
	end)

	t.test("anti-cheat: the truth answer is not in the client view before the reveal", function()
		local inst = solo("truth")
		local p = inst.byId.h
		while inst.pub.phase ~= "think" do
			Floors.step(inst, 0.1)
			_ = p
		end
		local pub = Floors.public(inst)
		t.ok(pub.q ~= nil, "the question id is shown")
		t.eq(pub.answer, nil, "no answer while thinking")
		while inst.pub.phase == "think" do
			Floors.step(inst, 0.1)
		end
		t.ok(Floors.public(inst).answer ~= nil, "answer after the reveal")
	end)
end
