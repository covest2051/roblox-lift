--[[
	Каталог и профиль: шансы капсулы ровно 100% (Common 60 / Rare 28 / Epic 10 / Legendary 2),
	бросок по шансам, покупки, VIP, дубликаты, коллекция и рекорды, ежедневный подарок, миграция.
]]

return function(t)
	local Catalog = t.shared("Catalog")
	local Config = t.shared("Config")
	local Profile = t.shared("Profile")
	local Floors = t.shared("Floors")
	local Rewards = t.shared("Rewards")
	local Rng = t.shared("Rng")

	t.test("catalog: exact odds sum to 100%", function()
		local sum, byR = 0, {}
		for _, o in Catalog.odds() do
			sum += o.bp
			byR[o.rarity] = (byR[o.rarity] or 0) + o.bp
		end
		t.eq(sum, Config.WeightTotal)
		t.eq(byR.Common, 6000)
		t.eq(byR.Rare, 2800)
		t.eq(byR.Epic, 1000)
		t.eq(byR.Legendary, 200)
		for _, r in Config.RarityOrder do
			t.eq(Config.Rarity[r].weight % #Catalog.ofRarity(r), 0, r .. " divides evenly")
		end
		t.eq(Catalog.rarityPercent("Legendary"), "2%")
	end)

	t.test("catalog: rolls follow the odds", function()
		local rng = Rng.new(9)
		local n, cnt = 40000, {}
		for _ = 1, n do
			local it = Catalog.get(Catalog.roll(function(a, b)
				return rng:int(a, b)
			end))
			cnt[it.rarity] = (cnt[it.rarity] or 0) + 1
		end
		t.near(cnt.Common / n, 0.6, 0.015)
		t.near(cnt.Rare / n, 0.28, 0.015)
		t.near(cnt.Epic / n, 0.10, 0.01)
		t.near(cnt.Legendary / n, 0.02, 0.005)
	end)

	t.test("catalog: every kind has a default; secret and VIP are not for sale", function()
		for _, kind in Catalog.Kinds do
			local it = Catalog.get(Catalog.Default[kind])
			t.ok(it and it.kind == kind, kind)
		end
		t.ok(not Catalog.isTradable(Catalog.get("hat_vip")))
		t.ok(not Catalog.isTradable(Catalog.get(Catalog.BasementPrize)))
		t.eq(#Catalog.Emotes, 6)
		t.eq(#Catalog.EmotesPlus, 6)
		t.ok(
			Catalog.emoteAllowed("😂", false)
				and not Catalog.emoteAllowed("🤡", false)
				and Catalog.emoteAllowed("🤡", true)
		)
	end)

	t.test("profile: buy, equip, VIP, duplicates, direct", function()
		local d = Profile.new()
		t.ok(not Profile.buyWithCoins(d, "hat_top"), "no coins")
		d.coins = 1000
		t.ok(Profile.buyWithCoins(d, "hat_top"))
		t.eq(d.coins, 1000 - Catalog.price("hat_top"))
		t.ok(Profile.equip(d, "hat_top", false))
		t.eq(Profile.effective(d, "hat", false), "hat_top")
		t.ok(not Profile.equip(d, "hat_vip", false), "VIP needs the pass")
		t.ok(Profile.equip(d, "hat_vip", true))
		t.eq(Profile.effective(d, "hat", false), "hat_none", "VIP falls off without the pass")
		local r = Profile.grantItem(d, "hat_top")
		t.ok(r.dup and r.refund == Catalog.refund("hat_top"))
		t.eq(Profile.pickDirect(d, "Rare", "hat_top") ~= "hat_top", true)
	end)

	t.test("profile: collection, records, daily gift, migration", function()
		local d = Profile.new()
		t.ok(Profile.recordFloor(d, "lava", 2, 30.5, true), "first time")
		t.ok(not Profile.recordFloor(d, "lava", 3, 12, true))
		t.eq(d.floors.lava.n, 2)
		t.eq(d.floors.lava.best, 3)
		t.eq(d.floors.lava.score, 30.5)
		t.eq(d.stars, 5)
		local n, total = Profile.opened(d)
		t.eq(n, 1)
		t.eq(total, #Floors.Order)
		Profile.recordRide(d, 7)
		Profile.recordRide(d, 4)
		t.eq(d.bestFloors, 7)
		t.ok(Profile.claimDaily(d, 100))
		t.ok(not Profile.claimDaily(d, 100), "once a day")
		t.ok(Profile.claimDaily(d, 101))
		t.eq(d.coins, 2 * Config.Rewards.DailyGift)
		local m = Profile.migrate({
			coins = 50.7,
			floors = { lava = { n = 3, best = 9, score = 4 }, nope = { n = 1 }, lobby = { n = 1 } },
			owned = { hat_top = true, junk = true },
			equipped = { hat = "hat_top", acc = "hat_top" },
		})
		t.eq(m.coins, 50)
		t.eq(m.floors.lava.best, 3)
		t.ok(m.floors.nope == nil and m.floors.lobby == nil, "unknown floors and stages dropped")
		t.ok(m.owned.hat_top and not m.owned.junk)
		t.eq(m.equipped.acc, "acc_none", "wrong kind is not equipped")
		t.eq(Profile.migrate(nil).coins, 0)
	end)

	t.test("profile: coin multiplier", function()
		t.eq(Rewards.multiplier(false, false), 1)
		t.eq(Rewards.multiplier(true, false), 2)
		t.near(Rewards.multiplier(true, true), 2.2, 1e-9)
		t.eq(Rewards.apply(15, 2.2), 33)
	end)
end
