--[[
	Config — все числа баланса, времени и ID товаров в одном месте.
	После правки: `lune run tests/run.luau` (тесты на ботах скажут, если этаж стал
	слишком лёгким/трудным, ожидание на балконе — долгим, а подбор — нечестным).
]]

local Config = {}

Config.Version = "1.0.0"

-- Поездка (с)
Config.Ride = {
	Stops = 10, -- этажей за поездку
	Bosses = { 5, 10 }, -- остановки-боссы
	FirstLobby = 20, -- отсчёт в лобби перед первой поездкой сервера
	Lobby = 15, -- после падения
	Cabin = 9, -- между этажами: голосование и события кабины
	Doors = 1.5, -- двери открываются
	FloorEnd = 5, -- итог этажа (звёзды), потом все в кабину
	Roof = 12, -- итоги поездки на крыше
	Fall = 6, -- падение в лобби
	PayHold = 12, -- продление кабины один раз за поездку, пока открыт промпт «Подвала»
	Step = 1 / 15, -- шаг логики сервера
	MaxDt = 0.25, -- если сервер подвис — не прыгать дальше
	CabinFxChance = 0.4, -- шанс события в кабине (свет, тряска, чих конфетти)
}

-- Подбор этажей
Config.Picker = {
	Options = 3, -- кнопок голосования
	MaxSameCat = 2, -- одна категория не больше 2 раз подряд
	CalmEvery = 4, -- спокойный не чаще раза в 4 этажа
	Basement = 0.02, -- шанс Подвала на обычной остановке
}

-- Боты-пассажиры
Config.Bots = {
	MinCrew = 4, -- людей меньше — добираем ботами
	Max = 3,
	Skills = { "medium", "novice", "medium" }, -- по порядку посадки
}

-- Общие правила этажей
Config.Floor = {
	Grace = 3, -- первые 3 с никто не выбывает (упал — ставим обратно)
	KillY = -25, -- ниже — упал (относительно пола этажа)
	MinDuration = 30,
	MaxDuration = 60,
	OutFlight = 1.2, -- полёт на балкон (с)
	RespawnDelay = 1, -- гонки: упал — через 1 с обратно на чекпоинт
	MaxSpeed = 30, -- анти-чит: позиция для правил двигается не быстрее (studs/с) …
	MaxRise = 120, -- … и вверх не быстрее (батуты)
	ActRange = 6, -- «сесть», «нажать» — не дальше (studs)
}

-- Тело бота и тестов (кинематика как у персонажа Roblox)
Config.Body = {
	Walk = 16,
	Jump = 50, -- начальная скорость прыжка (JumpPower)
	Gravity = 196.2,
	StepUp = 1.2, -- на сколько можно «шагнуть» вверх
	IceGrip = 1.6, -- лёд: скорость догоняет желаемую с этим коэффициентом (1/с)
}

-- Награды
Config.Rewards = {
	CoinsPerStar = 5,
	RideBonus = 25, -- доехал до крыши
	DoubleCoins = 2,
	VipBonus = 0.1,
	DailyGift = 60, -- ежедневный подарок в Кафе
	CafeGift = 10, -- маленький подарок в Кафе каждому
}

-- Сцена (координаты относительно порога двери лифта; +Z — от двери на этаж)
Config.Stage = {
	-- кабина: пол на y = 0, внутри x ∈ [-9, 9], z ∈ [-15, -1]
	CabinSpots = { x0 = -7, x1 = 7, z0 = -13, z1 = -3 },
	-- балкон зрителей: мягкий, высоко над дальним краем этажа
	Balcony = { x = 0, y = 34, z = 104, w = 44, d = 10 },
	Roof = { x = 0, z = 30 },
	Lobby = { x = 0, z = 22 },
}

-- Косметика: цены и вес в капсуле (веса — в сотых долях процента: 6000 = 60.00%)
Config.Rarity = {
	Common = { weight = 6000, price = 300, refund = 75, color = { 200, 205, 215 } },
	Rare = { weight = 2800, price = 700, refund = 175, color = { 90, 170, 255 } },
	Epic = { weight = 1000, price = 1600, refund = 400, color = { 190, 110, 255 } },
	Legendary = { weight = 200, price = 4000, refund = 1000, color = { 255, 190, 60 } },
}
Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary" }
Config.WeightTotal = 10000

--[[
	ID товаров из Creator Hub (Monetization → Passes / Developer Products).
	Пока ID = 0: в Studio покупка эмулируется, в живой игре кнопка «скоро».
]]
Config.Passes = {
	DoubleCoins = { id = 0, robux = 149 },
	Vip = { id = 0, robux = 249 },
	Emotes = { id = 0, robux = 79 },
}
Config.PassOrder = { "Emotes", "DoubleCoins", "Vip" }
Config.Products = {
	Coins500 = { id = 0, robux = 25, coins = 500 },
	Coins3000 = { id = 0, robux = 99, coins = 3000 },
	Basement = { id = 0, robux = 29 },
	Chest = { id = 0, robux = 35 },
	DirectRare = { id = 0, robux = 49, rarity = "Rare" },
	DirectEpic = { id = 0, robux = 99, rarity = "Epic" },
	DirectLegendary = { id = 0, robux = 199, rarity = "Legendary" },
}
Config.ProductOrder =
	{ "Coins500", "Coins3000", "Basement", "Chest", "DirectRare", "DirectEpic", "DirectLegendary" }
Config.ChestFallbackCoins = 500

-- Бейджи (вписать ID из Creator Hub → Badges; 0 — не выдаются)
Config.Badges = {
	Roof = 0, -- «Доехал до крыши»
	Basement = 0, -- «Нашёл подвал»
}

Config.DataStore = {
	Name = "LiftProfiles_v1",
	AutosaveEvery = 90,
	Retries = 4,
	ReceiptLog = 100,
}

-- Встроенные звуки (rbxasset://). Мелодия лифта и звонки — синтез из «пинга» с разной высотой.
Config.Sounds = {
	Ping = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Speed = 1 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Speed = 1 },
	Boing = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.5, Speed = 1.2 },
	Thud = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.6, Speed = 0.8 },
	Whoosh = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.5, Speed = 1 },
}

-- Мелодия лифта: ноты (полутоны от базовой высоты) и длительности (доли такта)
Config.Music = {
	Tempo = 0.28, -- с на долю
	Notes = { 0, 4, 7, 12, 11, 7, 4, 5, 9, 12, 9, 5, 7, 4, 2, -1, 0, 4, 7, 9, 7, 4, 2, 0 },
	Volume = 0.12,
}

return Config
