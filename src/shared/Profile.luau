--[[
	Profile — данные игрока и операции над ними (чистые функции; сервер хранит в DataStore,
	тесты проверяют правила): монеты и звёзды, рекорд «этажей за поездку», коллекция этажей
	с рекордами, ежедневный подарок, облик, чеки покупок.
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Floors = require(Shared.Floors)

local Profile = {}

Profile.Version = 1

export type FloorCard = { n: number, best: number, score: number, passed: number }

export type Data = {
	v: number,
	coins: number,
	stars: number,
	bestFloors: number, -- рекорд: этажей пройдено за одну поездку
	rides: number,
	roofs: number,
	earned: number,
	chests: number,
	floors: { [string]: FloorCard },
	daily: number, -- номер дня (UTC), когда взят ежедневный подарок
	owned: { [string]: boolean },
	equipped: { [string]: string },
	receipts: { string },
}

local STATS = { "coins", "stars", "bestFloors", "rides", "roofs", "earned", "chests", "daily" }

function Profile.new(): Data
	local owned, equipped = {}, {}
	for _, kind in Catalog.Kinds do
		owned[Catalog.Default[kind]] = true
		equipped[kind] = Catalog.Default[kind]
	end
	local d = { v = Profile.Version, floors = {}, owned = owned, equipped = equipped, receipts = {} }
	for _, k in STATS do
		d[k] = 0
	end
	return d :: any
end

-- Приводит сохранённые данные к текущему формату (новые поля, неизвестные предметы и этажи)
function Profile.migrate(raw: any): Data
	local d = Profile.new()
	if type(raw) ~= "table" then
		return d
	end
	for _, k in STATS do
		if type(raw[k]) == "number" then
			(d :: any)[k] = math.max(0, math.floor(raw[k]))
		end
	end
	if type(raw.floors) == "table" then
		for id, c in raw.floors do
			if Floors.get(id) and Floors.get(id).cat ~= "stage" and type(c) == "table" then
				d.floors[id] = {
					n = math.max(0, math.floor(tonumber(c.n) or 0)),
					best = math.clamp(math.floor(tonumber(c.best) or 0), 0, 3),
					score = tonumber(c.score) or 0,
					passed = math.max(0, math.floor(tonumber(c.passed) or 0)),
				}
			end
		end
	end
	if type(raw.owned) == "table" then
		for id, v in raw.owned do
			if v == true and type(id) == "string" and Catalog.get(id) then
				d.owned[id] = true
			end
		end
	end
	if type(raw.equipped) == "table" then
		for _, kind in Catalog.Kinds do
			local id = raw.equipped[kind]
			local it = type(id) == "string" and Catalog.get(id)
			if it and it.kind == kind then
				d.equipped[kind] = id
			end
		end
	end
	if type(raw.receipts) == "table" then
		for _, r in raw.receipts do
			if type(r) == "string" then
				table.insert(d.receipts, r)
			end
		end
	end
	return d
end

function Profile.addCoins(d: Data, n: number)
	d.coins = math.max(0, d.coins + math.floor(n))
end

function Profile.earn(d: Data, n: number)
	if n > 0 then
		Profile.addCoins(d, n)
		d.earned += math.floor(n)
	end
end

--[[
	Итог этажа: открывает карточку в коллекции, обновляет рекорды.
	Возвращает true, если этаж открыт впервые.
]]
function Profile.recordFloor(d: Data, floorId: string, stars: number, score: number, passed: boolean): boolean
	local card = d.floors[floorId]
	local first = card == nil
	if not card then
		card = { n = 0, best = 0, score = 0, passed = 0 }
		d.floors[floorId] = card
	end
	card.n += 1
	card.best = math.max(card.best, math.clamp(stars, 0, 3))
	card.score = math.max(card.score, math.floor(score * 10 + 0.5) / 10)
	if passed then
		card.passed += 1
	end
	d.stars += math.max(0, stars)
	return first
end

-- Итог поездки (на крыше): рекорд этажей за поездку
function Profile.recordRide(d: Data, passed: number)
	d.rides += 1
	d.roofs += 1
	d.bestFloors = math.max(d.bestFloors, passed)
end

-- Сколько этажей открыто из всех (16 + 2 босса + 1 секретный)
function Profile.opened(d: Data): (number, number)
	local n = 0
	for _, id in Floors.Order do
		if d.floors[id] then
			n += 1
		end
	end
	return n, #Floors.Order
end

-- Ежедневный подарок: день — номер суток UTC (os.time() // 86400). true — выдан сейчас
function Profile.claimDaily(d: Data, day: number): boolean
	if d.daily >= day then
		return false
	end
	d.daily = day
	Profile.addCoins(d, Config.Rewards.DailyGift)
	return true
end

function Profile.owns(d: Data, id: string): boolean
	return d.owned[id] == true
end

-- Выдать предмет. Дубликат → монеты. { id, dup, refund }
function Profile.grantItem(d: Data, id: string)
	if d.owned[id] then
		local refund = Catalog.refund(id)
		Profile.addCoins(d, refund)
		return { id = id, dup = true, refund = refund }
	end
	d.owned[id] = true
	return { id = id, dup = false, refund = 0 }
end

function Profile.buyWithCoins(d: Data, id: string): (boolean, string?)
	local it = Catalog.get(id)
	if not it or not Catalog.isTradable(it) then
		return false, "shop.notForSale"
	end
	if d.owned[id] then
		return false, "shop.owned"
	end
	local price = Catalog.price(id) :: number
	if d.coins < price then
		return false, "shop.noCoins"
	end
	d.coins -= price
	d.owned[id] = true
	return true, nil
end

-- Надеть. VIP-предметам нужен геймпасс, остальным — владение
function Profile.equip(d: Data, id: string, hasVip: boolean): boolean
	local it = Catalog.get(id)
	if not it then
		return false
	end
	if not (d.owned[id] or (it.rarity == "Vip" and hasVip)) then
		return false
	end
	d.equipped[it.kind] = id
	return true
end

-- Что реально надето (VIP снимается без геймпасса)
function Profile.effective(d: Data, kind: string, hasVip: boolean): string
	local id = d.equipped[kind]
	local it = Catalog.get(id)
	if not it or it.kind ~= kind then
		return Catalog.Default[kind]
	end
	if it.rarity == "Vip" then
		return if hasVip then id else Catalog.Default[kind]
	end
	if not d.owned[id] then
		return Catalog.Default[kind]
	end
	return id
end

function Profile.pickDirect(d: Data, rarity: string, wanted: string?): string?
	local it = wanted and Catalog.get(wanted)
	if it and it.rarity == rarity and not d.owned[wanted :: string] then
		return wanted
	end
	for _, x in Catalog.ofRarity(rarity) do
		if not d.owned[x.id] then
			return x.id
		end
	end
	return nil
end

function Profile.hasReceipt(d: Data, purchaseId: string): boolean
	return table.find(d.receipts, purchaseId) ~= nil
end

function Profile.addReceipt(d: Data, purchaseId: string)
	table.insert(d.receipts, purchaseId)
	while #d.receipts > Config.DataStore.ReceiptLog do
		table.remove(d.receipts, 1)
	end
end

return Profile
