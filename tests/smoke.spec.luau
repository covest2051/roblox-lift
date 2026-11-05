return function(t)
	t.test("smoke: shared modules load", function()
		local Rng = t.shared("Rng")
		local r = Rng.new(1)
		t.ok(r:next() >= 0)
	end)
end
