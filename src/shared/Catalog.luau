--[[
	Catalog — облик, который видят все. Всё из примитивов (без сторонних моделей и звуков):
	  • hat   — шапка на голове (детали, приваренные к голове);
	  • acc   — аксессуар (на шее, лице или спине);
	  • trail — след за персонажем (Trail);
	  • exit  — эффект «выход из лифта» (частицы у дверей, когда выходишь на этаж);
	  • pose  — поза на балконе зрителей;
	  • chime — звонок лифта (звучит, когда открываются двери на этаж, за который ты голосовал).
	Редкости: Default (у всех), Common/Rare/Epic/Legendary (капсула и магазин), Vip (геймпасс),
	Secret (только из Подвала). Шансы капсулы — в целых «сотых процента» (Config.WeightTotal),
	поэтому показанные проценты точные. Детали шапок — { shape, size = {x,y,z}, at = {x,y,z},
	color, mat } относительно центра головы.
]]

local Shared = script.Parent
local Config = require(Shared.Config)

local Catalog = {}

Catalog.Kinds = { "hat", "acc", "trail", "exit", "pose", "chime" }

local function item(id, kind, rarity, extra)
	local it = { id = id, kind = kind, rarity = rarity }
	for k, v in extra or {} do
		it[k] = v
	end
	return it
end

local GOLD = { 255, 200, 60 }

Catalog.Items = {
	-- по умолчанию
	item("hat_none", "hat", "Default", { parts = {} }),
	item("acc_none", "acc", "Default", { parts = {} }),
	item("trail_none", "trail", "Default", {}),
	item("exit_door", "exit", "Default", { colors = { { 255, 255, 255 } }, burst = 0 }),
	item("pose_sit", "pose", "Default", { pose = "sit" }),
	item("chime_ding", "chime", "Default", { notes = { 12 } }),
	-- Common (8 × 7.5%)
	item("hat_cap", "hat", "Common", {
		parts = {
			{ shape = "Ball", size = { 1.3, 1.3, 1.3 }, at = { 0, 0.45, 0 }, color = { 60, 120, 230 } },
			{ shape = "Block", size = { 1.2, 0.12, 0.8 }, at = { 0, 0.4, -0.75 }, color = { 60, 120, 230 } },
		},
	}),
	item("hat_chef", "hat", "Common", {
		parts = {
			{
				shape = "Cylinder",
				size = { 0.9, 1.15, 1.15 },
				at = { 0, 0.85, 0 },
				color = { 250, 250, 250 },
			},
			{ shape = "Ball", size = { 1.5, 1.1, 1.5 }, at = { 0, 1.4, 0 }, color = { 250, 250, 250 } },
		},
	}),
	item("acc_bowtie", "acc", "Common", {
		parts = {
			{
				shape = "Block",
				size = { 0.5, 0.35, 0.15 },
				at = { -0.3, -0.85, -0.55 },
				color = { 220, 40, 60 },
			},
			{
				shape = "Block",
				size = { 0.5, 0.35, 0.15 },
				at = { 0.3, -0.85, -0.55 },
				color = { 220, 40, 60 },
			},
			{ shape = "Ball", size = { 0.25, 0.25, 0.25 }, at = { 0, -0.85, -0.6 }, color = { 180, 20, 40 } },
		},
	}),
	item("acc_glasses", "acc", "Common", {
		parts = {
			{
				shape = "Cylinder",
				size = { 0.1, 0.45, 0.45 },
				at = { -0.25, 0.1, -0.6 },
				color = { 30, 30, 30 },
				ry = 90,
			},
			{
				shape = "Cylinder",
				size = { 0.1, 0.45, 0.45 },
				at = { 0.25, 0.1, -0.6 },
				color = { 30, 30, 30 },
				ry = 90,
			},
			{ shape = "Block", size = { 0.2, 0.06, 0.06 }, at = { 0, 0.12, -0.62 }, color = { 30, 30, 30 } },
		},
	}),
	item("trail_mint", "trail", "Common", { colors = { { 120, 240, 200 }, { 220, 255, 245 } } }),
	item(
		"exit_confetti",
		"exit",
		"Common",
		{ colors = { { 255, 90, 90 }, { 255, 220, 80 }, { 90, 200, 255 } }, burst = 40 }
	),
	item("pose_lie", "pose", "Common", { pose = "lie" }),
	item("chime_dingdong", "chime", "Common", { notes = { 16, 12 } }),
	-- Rare (4 × 7%)
	item("hat_top", "hat", "Rare", {
		parts = {
			{ shape = "Cylinder", size = { 1.3, 1.1, 1.1 }, at = { 0, 1.15, 0 }, color = { 30, 30, 35 } },
			{ shape = "Cylinder", size = { 0.1, 1.8, 1.8 }, at = { 0, 0.55, 0 }, color = { 30, 30, 35 } },
			{ shape = "Cylinder", size = { 0.25, 1.12, 1.12 }, at = { 0, 0.75, 0 }, color = { 200, 40, 60 } },
		},
	}),
	item("acc_balloon", "acc", "Rare", {
		parts = {
			{ shape = "Ball", size = { 1.6, 1.9, 1.6 }, at = { 0.9, 3.4, 1 }, color = { 255, 90, 160 } },
			{
				shape = "Block",
				size = { 0.05, 2.6, 0.05 },
				at = { 0.6, 1.4, 0.8 },
				color = { 240, 240, 240 },
			},
		},
	}),
	item(
		"trail_sunset",
		"trail",
		"Rare",
		{ colors = { { 255, 120, 60 }, { 255, 80, 160 }, { 120, 80, 255 } } }
	),
	item("chime_triple", "chime", "Rare", { notes = { 7, 12, 16 } }),
	-- Epic (4 × 2.5%)
	item("hat_crown", "hat", "Epic", {
		parts = {
			{ shape = "Cylinder", size = { 0.5, 1.3, 1.3 }, at = { 0, 0.75, 0 }, color = GOLD, mat = "Foil" },
			{
				shape = "Ball",
				size = { 0.3, 0.3, 0.3 },
				at = { 0, 1.15, -0.6 },
				color = { 220, 30, 60 },
				mat = "Neon",
			},
			{
				shape = "Ball",
				size = { 0.3, 0.3, 0.3 },
				at = { 0.6, 1.15, 0 },
				color = { 60, 120, 255 },
				mat = "Neon",
			},
			{
				shape = "Ball",
				size = { 0.3, 0.3, 0.3 },
				at = { -0.6, 1.15, 0 },
				color = { 60, 220, 120 },
				mat = "Neon",
			},
		},
	}),
	item("acc_wings", "acc", "Epic", {
		parts = {
			{
				shape = "Block",
				size = { 1.6, 2.2, 0.15 },
				at = { -1, -1.2, 0.8 },
				color = { 240, 250, 255 },
				mat = "Glass",
				ry = -20,
			},
			{
				shape = "Block",
				size = { 1.6, 2.2, 0.15 },
				at = { 1, -1.2, 0.8 },
				color = { 240, 250, 255 },
				mat = "Glass",
				ry = 20,
			},
		},
	}),
	item("exit_hearts", "exit", "Epic", { colors = { { 255, 80, 140 }, { 255, 170, 200 } }, burst = 60 }),
	item("pose_upside", "pose", "Epic", { pose = "upside" }),
	-- Legendary (2 × 1%)
	item("hat_halo", "hat", "Legendary", {
		parts = {
			{
				shape = "Cylinder",
				size = { 0.12, 1.6, 1.6 },
				at = { 0, 1.3, 0 },
				color = { 255, 240, 140 },
				mat = "Neon",
			},
		},
		rainbow = true,
	}),
	item("trail_rainbow", "trail", "Legendary", {
		colors = { { 255, 70, 70 }, { 255, 200, 60 }, { 90, 230, 110 }, { 70, 160, 255 }, { 190, 90, 255 } },
	}),
	-- только VIP
	item("hat_vip", "hat", "Vip", {
		parts = {
			{ shape = "Cylinder", size = { 1.3, 1.1, 1.1 }, at = { 0, 1.15, 0 }, color = GOLD, mat = "Foil" },
			{ shape = "Cylinder", size = { 0.1, 1.8, 1.8 }, at = { 0, 0.55, 0 }, color = GOLD, mat = "Foil" },
		},
	}),
	item("trail_gold", "trail", "Vip", { colors = { GOLD, { 255, 250, 210 } } }),
	item("exit_gold", "exit", "Vip", { colors = { GOLD, { 255, 255, 255 } }, burst = 70 }),
	-- секрет: только из Подвала
	item("hat_sock", "hat", "Secret", {
		parts = {
			{
				shape = "Block",
				size = { 0.7, 1.6, 0.7 },
				at = { 0, 1.3, 0 },
				color = { 255, 120, 120 },
				mat = "Fabric",
			},
			{
				shape = "Block",
				size = { 0.7, 0.5, 1.2 },
				at = { 0, 2.1, -0.3 },
				color = { 255, 120, 120 },
				mat = "Fabric",
			},
		},
	}),
}

Catalog.Default = {
	hat = "hat_none",
	acc = "acc_none",
	trail = "trail_none",
	exit = "exit_door",
	pose = "pose_sit",
	chime = "chime_ding",
}

-- Предмет за первый визит в Подвал
Catalog.BasementPrize = "hat_sock"

-- Реакции на балконе: базовые у всех, «плюс» — геймпасс «Эмоции+»
Catalog.Emotes = { "😂", "👏", "😱", "🔥", "❤️", "🙈" }
Catalog.EmotesPlus = { "🤡", "👑", "🥳", "🐔", "🫧", "💤" }

local byId = {}
local byRarity = {}
for _, it in Catalog.Items do
	byId[it.id] = it
	byRarity[it.rarity] = byRarity[it.rarity] or {}
	table.insert(byRarity[it.rarity], it)
end

function Catalog.get(id: string)
	return byId[id]
end

function Catalog.ofRarity(rarity: string)
	return byRarity[rarity] or {}
end

function Catalog.isTradable(it): boolean
	return Config.Rarity[it.rarity] ~= nil
end

function Catalog.price(id: string): number?
	local it = byId[id]
	local r = it and Config.Rarity[it.rarity]
	return r and r.price
end

function Catalog.refund(id: string): number
	local it = byId[id]
	local r = it and Config.Rarity[it.rarity]
	return if r then r.refund else 0
end

function Catalog.emoteAllowed(emote: string, hasPass: boolean): boolean
	if table.find(Catalog.Emotes, emote) then
		return true
	end
	return hasPass and table.find(Catalog.EmotesPlus, emote) ~= nil
end

-- Точные шансы капсулы: { {id, rarity, bp} }, bp — сотые доли процента; сумма = WeightTotal
function Catalog.odds()
	local out = {}
	for _, rarity in Config.RarityOrder do
		local items = byRarity[rarity] or {}
		local w = Config.Rarity[rarity].weight
		for _, it in items do
			table.insert(out, { id = it.id, rarity = rarity, bp = math.floor(w / #items) })
		end
	end
	return out
end

function Catalog.rarityPercent(rarity: string): string
	return Catalog.formatBp(Config.Rarity[rarity].weight)
end

-- 750 → "7.5%", 100 → "1%"
function Catalog.formatBp(bp: number): string
	local s = string.format("%.2f", bp / 100)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return s .. "%"
end

-- Бросок капсулы. randInt(a, b) — целое в [a, b]
function Catalog.roll(randInt: (number, number) -> number): string
	local odds = Catalog.odds()
	local r = randInt(1, Config.WeightTotal)
	local acc = 0
	for _, o in odds do
		acc += o.bp
		if r <= acc then
			return o.id
		end
	end
	return odds[#odds].id
end

return Catalog
