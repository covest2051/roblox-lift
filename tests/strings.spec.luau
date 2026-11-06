--[[
	Тексты: ключи RU и EN совпадают; у каждого этажа (название, правило), категории, предмета,
	редкости, цвета, бота, причины выбывания есть текст; каждый ключ из кода существует;
	утверждения «Правды или лжи» уникальны и заполнены на обоих языках.
]]

return function(t)
	local Strings = t.shared("Strings")
	local Catalog = t.shared("Catalog")
	local Floors = t.shared("Floors")
	local Bots = t.shared("Bots")
	local Questions = t.shared("Questions")

	t.test("strings: ru and en have the same keys", function()
		for k in Strings.ru do
			t.ok(Strings.en[k] ~= nil, "en missing " .. k)
		end
		for k in Strings.en do
			t.ok(Strings.ru[k] ~= nil, "ru missing " .. k)
		end
	end)

	t.test("strings: floors, categories, items, rarities, colours, bots", function()
		for _, id in Floors.Order do
			t.ok(Strings.ru["floor." .. id] and Strings.ru["rule." .. id], "floor " .. id)
			t.ok(Strings.ru["cat." .. Floors.get(id).cat], "cat of " .. id)
		end
		for _, c in { "fire", "race", "brain", "coop", "calm" } do
			t.ok(Strings.ru["cat." .. c] ~= nil, c)
		end
		for _, it in Catalog.Items do
			t.ok(Strings.ru["item." .. it.id] ~= nil, "item." .. it.id)
			t.ok(Strings.ru["rarity." .. it.rarity] ~= nil, "rarity." .. it.rarity)
		end
		for _, kind in Catalog.Kinds do
			t.ok(Strings.ru["shop.kind." .. kind] ~= nil, kind)
		end
		for _, c in Floors.get("colors").Colors do
			t.ok(Strings.ru["color." .. c.key] ~= nil, c.key)
		end
		for _, n in Bots.Names do
			t.ok(Strings.ru[n] ~= nil, n)
		end
		for _, r in { "fall", "lava", "strike", "foam", "shh", "chair", "vacuum", "spikes" } do
			t.ok(Strings.ru["out." .. r] ~= nil, "out." .. r)
		end
		for _, w in { "rare", "basement", "bought", "boss", "debug", "fallback" } do
			t.ok(Strings.ru["why." .. w] ~= nil, "why." .. w)
		end
		for _, w in { "notNow", "pending", "used", "late" } do
			t.ok(Strings.ru["shop.basementNo." .. w] ~= nil, w)
		end
	end)

	t.test("strings: questions are unique and bilingual", function()
		local seen = {}
		t.ok(#Questions.List >= 30, "enough statements")
		for _, q in Questions.List do
			t.ok(not seen[q.id], "unique " .. q.id)
			seen[q.id] = true
			t.ok(type(q.truth) == "boolean" and #q.ru > 5 and #q.en > 5, q.id)
		end
		local trues = 0
		for _, q in Questions.List do
			if q.truth then
				trues += 1
			end
		end
		t.ok(math.abs(trues - #Questions.List / 2) <= 2, "truths and lies are balanced")
	end)

	t.test("strings: substitution, nested keys, locale", function()
		t.eq(Strings.get("ru", "phase.lobby", { t = 5 }), "Лифт отправляется через 5")
		t.eq(Strings.get("en", "shop.bought", { item = "item.hat_top" }), "Bought: Top hat")
		t.eq(Strings.get("en", "no.such.key"), "no.such.key")
		t.eq(Strings.langFromLocale("ru-ru"), "ru")
		t.eq(Strings.langFromLocale(nil), "en")
		t.eq(Strings.formatSec(7.36), "8")
		t.eq(Strings.stars(2), "⭐⭐☆")
	end)

	t.test("strings: every key used in code exists", function()
		local fs = (require :: any)("@lune/fs")
		local known = {}
		for k in Strings.ru do
			local prefix = string.match(k, "^(%a+)%.")
			if prefix then
				known[prefix] = true
			end
		end
		local missing = {}
		local function scan(dir)
			for _, f in fs.readDir(dir) do
				local path = dir .. "/" .. f
				if fs.isDir(path) then
					scan(path)
				elseif string.find(f, "%.luau$") and f ~= "Strings.luau" then
					local src = fs.readFile(path)
					for key in string.gmatch(src, '"(%a+%.%a[%w%.]*%w)"') do
						local prefix = string.match(key, "^(%a+)%.")
						if known[prefix] and not Strings.ru[key] then
							missing[key .. " in " .. f] = true
						end
					end
				end
			end
		end
		scan("src")
		for k in missing do
			t.ok(false, "missing string " .. k)
		end
	end)
end
