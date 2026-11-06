--[[
	Hud — интерфейс поездки:
	  • Board (сверху): плитка «🔥 3/10» (табло этажа), название этажа или фазы, строка табло
	    этажа (утверждение, цвет, «Смотрит!»), полоска времени;
	  • Stats (слева сверху): звёзды поездки, монеты, открыто этажей N/19;
	  • Menu: Коллекция, Магазин;
	  • Actions (справа снизу): голосование (3 кнопки категорий, VIP ×2), кнопка действия на
	    этаже (Сесть/Нажать/Подарок/Фото), реакции на балконе. Левый низ свободен для стика;
	  • всплывающее: баннер этажа (название + правило), итог этажа (звёзды), итоги поездки,
	    объявления («Х вызвал Подвал!»), подсказки.
	Раскладка: широкая и узкая (телефон); проверяется тестом на 667×375, 812×375 и 1.25.
]]

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Floors = require(Shared.Floors)
local Questions = require(Shared.Questions)
local Strings = require(Shared.Strings)

local Ui = require(script.Parent.Ui)
local Lang = require(script.Parent.Lang)

local Hud = {}

local C = Ui.colors
local Make = Ui.Make

Hud.info = {
	v = nil :: any, -- вид поездки (Ride.view)
	phaseEnd = 0, -- серверное время конца фазы
	phaseLen = 1,
	pub = nil :: any, -- публичное состояние этажа
	profile = nil :: any,
	passes = {},
}

-- колбэки (ставит init)
Hud.onVote = nil :: ((number) -> ())?
Hud.onAct = nil :: ((string) -> ())?
Hud.onEmote = nil :: ((string) -> ())?
Hud.onShop = nil :: (() -> ())?
Hud.onCollection = nil :: (() -> ())?

local ui: ScreenGui
local hud: Frame
local board: Frame
local stats: Frame
local menu: Frame
local actions: Frame
local voteF: Frame
local actF: Frame
local emoteF: Frame
local toastL: TextLabel
local banner: Frame
local result: Frame
local rideWin: Frame
local toastUntil, bannerUntil, resultUntil = 0, 0, 0
local clock = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

-------------------------------------------------------------------------------
-- Построение
-------------------------------------------------------------------------------
local function corner(obj, r)
	Make("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = obj })
end

function Hud.build()
	ui = Ui.screen()
	hud =
		Make("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = ui })

	-- табло сверху
	board = Ui.scaled(Ui.panel({ Name = "Board", Size = UDim2.fromOffset(500, 92), Parent = hud }), 0.75)
	Ui.stroke(board, C.brass, 2)
	local tile = Ui.label({
		Name = "Tile",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(96, 52),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BackgroundTransparency = 0,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Font = Ui.fontBold,
		TextScaled = true,
		Text = "🛗",
		Parent = board,
	})
	corner(tile, 8)
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(112, 6),
		Size = UDim2.new(1, -120, 0, 30),
		Font = Ui.fontBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = board,
	})
	Ui.label({
		Name = "Info",
		Position = UDim2.fromOffset(112, 36),
		Size = UDim2.new(1, -120, 0, 40),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.text,
		Text = "",
		Parent = board,
	})
	local timer = Make("Frame", {
		Name = "Timer",
		Position = UDim2.new(0, 8, 1, -12),
		Size = UDim2.new(1, -16, 0, 6),
		BackgroundColor3 = Color3.fromRGB(10, 20, 24),
		BorderSizePixel = 0,
		Parent = board,
	})
	corner(timer, 3)
	local fill = Make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.gold,
		BorderSizePixel = 0,
		Parent = timer,
	})
	corner(fill, 3)

	-- счёт слева сверху
	stats = Ui.scaled(Ui.panel({ Name = "Stats", Size = UDim2.fromOffset(200, 76), Parent = hud }), 0.75)
	Ui.label({
		Name = "Stars",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.fromOffset(90, 34),
		Font = Ui.fontBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "⭐ 0",
		Parent = stats,
	})
	Ui.label({
		Name = "Coins",
		Position = UDim2.fromOffset(100, 4),
		Size = UDim2.fromOffset(96, 34),
		Font = Ui.fontBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🪙 0",
		Parent = stats,
	})
	Ui.label({
		Name = "Opened",
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.fromOffset(180, 30),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.dim,
		Text = "🏢 0/19",
		Parent = stats,
	})

	-- меню
	menu = Ui.scaled(
		Make(
			"Frame",
			{ Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 80), Parent = hud }
		),
		0.75
	)
	local cb = Ui.button({
		Name = "CollectionButton",
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 17,
		Text = "",
		Parent = menu,
	})
	local sb = Ui.button({
		Name = "ShopButton",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 17,
		BackgroundColor3 = C.robux,
		Text = "",
		Parent = menu,
	})
	cb.Activated:Connect(function()
		if Hud.onCollection then
			Hud.onCollection()
		end
	end)
	sb.Activated:Connect(function()
		if Hud.onShop then
			Hud.onShop()
		end
	end)

	-- действия справа снизу
	actions = Ui.scaled(
		Make(
			"Frame",
			{ Name = "Actions", BackgroundTransparency = 1, Size = UDim2.fromOffset(430, 96), Parent = hud }
		),
		0.75
	)
	actions.AnchorPoint = Vector2.new(1, 1)
	voteF = Make("Frame", {
		Name = "Vote",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = actions,
	})
	for k = 1, 3 do
		local b = Ui.button({
			Name = "Option_" .. k,
			Position = UDim2.fromOffset((k - 1) * 146, 0),
			Size = UDim2.fromOffset(138, 96),
			TextSize = 20,
			TextWrapped = true,
			Text = "?",
			Parent = voteF,
		})
		Ui.label({
			Name = "Count",
			Position = UDim2.new(1, -34, 0, 4),
			Size = UDim2.fromOffset(30, 24),
			TextSize = 18,
			Font = Ui.fontBold,
			Text = "",
			Parent = b,
		})
		Ui.stroke(b, C.text, 0).Name = "Mine"
		b.Activated:Connect(function()
			if Hud.onVote then
				Hud.onVote(k)
			end
		end)
	end
	actF = Make("Frame", {
		Name = "Act",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = actions,
	})
	for i, name in { "ActButton", "ActButton2" } do
		local b = Ui.button({
			Name = name,
			Position = UDim2.new(1, -(if i == 1 then 210 else 430), 0, 0),
			Size = UDim2.fromOffset(210, 96),
			TextSize = 26,
			BackgroundColor3 = Color3.fromRGB(230, 120, 40),
			Text = "",
			Visible = false,
			Parent = actF,
		})
		b.Activated:Connect(function()
			local a = b:GetAttribute("Act")
			if a and Hud.onAct then
				Hud.onAct(a)
			end
		end)
	end
	emoteF = Make("Frame", {
		Name = "Emotes",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = actions,
	})
	Make("UIGridLayout", {
		CellSize = UDim2.fromOffset(66, 44),
		CellPadding = UDim2.fromOffset(6, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = emoteF,
	})
	local all = table.clone(Catalog.Emotes)
	for _, e in Catalog.EmotesPlus do
		table.insert(all, e)
	end
	for i, e in all do
		local b =
			Ui.button({ Name = "Emote_" .. i, LayoutOrder = i, TextSize = 26, Text = e, Parent = emoteF })
		b:SetAttribute("Plus", i > #Catalog.Emotes)
		b.Activated:Connect(function()
			if Hud.onEmote then
				Hud.onEmote(e)
			end
		end)
	end

	-- подсказки, баннер
	toastL = Ui.label({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(560, 34),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = C.panel,
		TextSize = 20,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = hud,
	})
	corner(toastL)
	Ui.scaled(toastL, 0.75)
	banner = Ui.scaled(
		Ui.panel({
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(560, 130),
			Visible = false,
			ZIndex = 4,
			Parent = hud,
		}),
		0.6
	)
	Ui.label({
		Name = "Head",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 50),
		Font = Ui.fontBold,
		TextSize = 38,
		ZIndex = 4,
		Text = "",
		Parent = banner,
	})
	Ui.label({
		Name = "Text",
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 60),
		TextSize = 21,
		ZIndex = 4,
		Text = "",
		Parent = banner,
	})

	-- итог этажа
	result = Ui.scaled(
		Ui.panel({
			Name = "Result",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(380, 230),
			Visible = false,
			ZIndex = 6,
			Parent = ui,
		}),
		0.6
	)
	Ui.stroke(result, C.gold, 2)
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 30),
		Font = Ui.fontBold,
		TextSize = 24,
		ZIndex = 6,
		Text = "",
		Parent = result,
	})
	Ui.label({
		Name = "Stars",
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, 50),
		TextSize = 44,
		ZIndex = 6,
		Text = "",
		Parent = result,
	})
	Ui.label({
		Name = "Lines",
		Position = UDim2.fromOffset(20, 94),
		Size = UDim2.new(1, -40, 0, 90),
		TextSize = 19,
		ZIndex = 6,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = result,
	})
	Ui.label({
		Name = "Coins",
		Position = UDim2.new(0, 10, 1, -40),
		Size = UDim2.new(1, -20, 0, 32),
		Font = Ui.fontBold,
		TextSize = 24,
		TextColor3 = C.gold,
		ZIndex = 6,
		Text = "",
		Parent = result,
	})

	-- итоги поездки
	rideWin = Ui.scaled(
		Ui.panel({
			Name = "RideResults",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(520, 440),
			Visible = false,
			ZIndex = 7,
			Parent = ui,
		}),
		0.5
	)
	Ui.stroke(rideWin, C.gold, 2)
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 40),
		Font = Ui.fontBold,
		TextSize = 30,
		ZIndex = 7,
		Text = "",
		Parent = rideWin,
	})
	local body = Make("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 1, -150),
		ZIndex = 7,
		Parent = rideWin,
	})
	Make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	Ui.label({
		Name = "Bonus",
		Position = UDim2.new(0, 10, 1, -88),
		Size = UDim2.new(1, -20, 0, 30),
		Font = Ui.fontBold,
		TextSize = 22,
		TextColor3 = C.gold,
		ZIndex = 7,
		Text = "",
		Parent = rideWin,
	})
	local close = Ui.button({
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(160, 40),
		ZIndex = 7,
		Text = "",
		Parent = rideWin,
	})
	close.Activated:Connect(function()
		rideWin.Visible = false
	end)

	Hud.layout()
	Ui.onViewport(Hud.layout)
	Hud.retext()
	Lang.onChange(Hud.retext)
end

-------------------------------------------------------------------------------
-- Раскладка: широкая / узкая (телефон)
-------------------------------------------------------------------------------
function Hud.layout()
	if not board then
		return
	end
	local narrow = Ui.isNarrow()
	stats.AnchorPoint = Vector2.new(0, 0)
	stats.Position = UDim2.fromOffset(12, 8)
	actions.Position = UDim2.new(1, -12, 1, -12)
	if narrow then
		-- телефон: табло вправо, счёт влево наверх, меню под счётом
		board.AnchorPoint = Vector2.new(1, 0)
		board.Position = UDim2.new(1, -12, 0, 8)
		menu.AnchorPoint = Vector2.new(0, 0)
		local s = stats:FindFirstChildOfClass("UIScale")
		local sc = if s then s.Scale else 1
		menu.Position = UDim2.fromOffset(12, 8 + math.ceil(76 * sc) + 8)
		toastL.Position = UDim2.new(0.62, 0, 0, 92)
	else
		board.AnchorPoint = Vector2.new(0.5, 0)
		board.Position = UDim2.new(0.5, 0, 0, 10)
		menu.AnchorPoint = Vector2.new(1, 0)
		menu.Position = UDim2.new(1, -12, 0, 10)
		toastL.Position = UDim2.new(0.5, 0, 0, 132)
	end
end

-------------------------------------------------------------------------------
-- Тексты
-------------------------------------------------------------------------------
function Hud.retext()
	menu.CollectionButton.Text = "🏢 " .. Lang.t("ui.collection")
	menu.ShopButton.Text = "🛍 " .. Lang.t("ui.shop")
	rideWin.Close.Text = Lang.t("ui.close")
	Hud.refresh()
end

-- Строка табло этажа по публичному состоянию
function Hud.boardText(id: string?, pub): string
	if not id or not pub then
		return ""
	end
	local t = Lang.t
	if pub.t and pub.t < 3 then
		return t("rule." .. id)
	end
	if id == "lava" then
		return t("board.lava", { n = pub.lava or 0 })
	elseif id == "colors" then
		if pub.phase == "count" and pub.color then
			return t("board.colors", { color = "color." .. pub.color })
		end
		return t(if pub.phase == "drop" then "board.colorsDrop" else "board.colorsWait")
	elseif id == "gravity" then
		return t("board.gravity." .. (pub.mode or "normal"))
	elseif id == "ice" then
		return t("board.ice", { need = pub.need or 0 })
	elseif id == "truth" then
		if pub.phase == "think" and pub.q then
			return "«" .. Questions.text(pub.q, Lang.current) .. "»"
		elseif pub.phase == "reveal" then
			return t(if pub.answer then "board.truthTrue" else "board.truthFalse")
		end
		return t("board.truthWait")
	elseif id == "library" then
		return t("board.library." .. (pub.state or "read"))
	elseif id == "chairs" then
		return t("board.chairs." .. (pub.phase or "intro"), { n = pub.chairs or 0 })
	elseif id == "dark" then
		return t("board.dark", { lit = pub.lit or 0, total = pub.total or 5 })
	elseif id == "cake" then
		return t("board.cake", { tiers = pub.tiers or 3, dist = pub.dist or 0 })
	elseif id == "penguins" then
		return t("board.penguins", { caught = pub.caught or 0, need = pub.need or 0 })
	elseif id == "vacuum" then
		return if pub.broken then t("board.vacuumBroken") else t("board.vacuum", { on = pub.on or 0 })
	elseif id == "soapboss" then
		return if pub.popped then t("board.soapPop") else t("board.soapboss", { n = pub.height or 0 })
	elseif id == "basement" then
		return t("board.basement", { n = pub.socks or 0, total = pub.total or 13 })
	elseif id == "lobby" or id == "roof" then
		return ""
	end
	return t("board." .. id)
end

local GARBLE = { "1̶3", "31", "Ǝ1", "?3" }

local function tileText(v): string
	if v.floor == "basement" then
		return GARBLE[math.floor(clock * 3) % #GARBLE + 1]
	end
	local icon = if v.floor then Floors.CatIcon[v.cat] or "🛗" else "🛗"
	if v.phase == "lobby" or v.phase == "idle" then
		return "🛗 L"
	elseif v.phase == "roof" then
		return "🏙 R"
	end
	return icon .. " " .. math.max(v.stop, 1) .. "/" .. v.stops
end

-- Обновить всё по текущему состоянию
function Hud.refresh()
	local info = Hud.info
	local v = info.v
	if not board then
		return
	end
	local left = math.max(0, info.phaseEnd - now())
	if v then
		board.Tile.Text = tileText(v)
		local title, text = "", ""
		local ph = v.phase
		if ph == "lobby" then
			title = Lang.t("phase.lobby", { t = Strings.formatSec(left) })
		elseif ph == "cabin" then
			title = if v.surprise then Lang.t("why." .. v.surprise) else Lang.t("phase.cabin")
			if v.where == "cabin" and info.passes.Vip and v.options then
				text = Lang.t("ui.vip")
			end
		elseif (ph == "doors" or ph == "floor") and v.floor then
			title = Lang.t("floor." .. v.floor)
			text = if ph == "floor" then Hud.boardText(v.floor, info.pub) else Lang.t("rule." .. v.floor)
		elseif ph == "floorEnd" then
			title = Lang.t("phase.floorEnd")
		else
			title = Lang.t("phase." .. ph)
		end
		if v.where == "balcony" and (ph == "floor" or ph == "doors" or ph == "floorEnd") then
			text = Lang.t("ui.balcony")
		end
		board.Title.Text = title
		board.Info.Text = text
		board.Timer.Fill.Size = UDim2.fromScale(math.clamp(left / math.max(info.phaseLen, 0.1), 0, 1), 1)
		board.Timer.Fill.BackgroundColor3 = if left < 4 and ph ~= "lobby" then C.danger else C.gold
		Hud.refreshActions()
		stats.Stars.Text = Lang.t("ui.stars", { n = v.stars or 0 })
	end
	local pr = info.profile
	if pr then
		stats.Coins.Text = Lang.t("ui.coins", { n = pr.coins })
		local n = 0
		for _ in pr.floors or {} do
			n += 1
		end
		stats.Opened.Text = Lang.t("ui.opened", { n = n, total = #Floors.Order })
	end
end

-- Нижняя правая панель: голосование / действие / реакции
function Hud.refreshActions()
	local info = Hud.info
	local v = info.v
	local showVote = v and v.phase == "cabin" and v.where == "cabin" and v.options ~= nil
	voteF.Visible = showVote == true
	if showVote then
		for k = 1, 3 do
			local b = voteF["Option_" .. k] :: TextButton
			local o = v.options[k]
			b.Visible = o ~= nil
			if o then
				b.Text = Floors.CatIcon[o.cat] .. " ?\n" .. Lang.t("cat." .. o.cat)
				b.BackgroundColor3 = Ui.catColor(o.cat):Lerp(C.button, 0.45)
				local cnt = v.votes and v.votes[k] or 0
				b.Count.Text = if cnt > 0 then tostring(cnt) else ""
				local mine = b:FindFirstChild("Mine") :: UIStroke
				mine.Thickness = if v.myVote == k then 4 else 0
				mine.Color = if info.passes.Vip then C.gold else C.text
			end
		end
	end
	-- действие на этаже
	local act1, act2 = nil, nil
	if v and v.phase == "floor" and v.where == "floor" and v.floor then
		if v.floor == "cafe" then
			act1, act2 = "gift", "photo"
		elseif info.pub and info.pub.act then
			act1 = info.pub.act
		end
	end
	actF.Visible = act1 ~= nil
	for i, b in { actF.ActButton, actF.ActButton2 } do
		local a = if i == 1 then act1 else act2
		b.Visible = a ~= nil
		if a then
			b:SetAttribute("Act", a)
			b.Text = Lang.t("act." .. a)
		end
	end
	-- реакции на балконе
	local onBalcony = v and v.where == "balcony"
	emoteF.Visible = onBalcony == true and not actF.Visible and not voteF.Visible
	for _, b in emoteF:GetChildren() do
		if b:IsA("TextButton") then
			b.Visible = not b:GetAttribute("Plus") or info.passes.Emotes == true
		end
	end
end

-------------------------------------------------------------------------------
-- Сообщения сервера
-------------------------------------------------------------------------------
function Hud.setState(msg)
	local info = Hud.info
	local prev = info.v
	info.v = msg.v
	info.phaseEnd = msg.now + msg.v.left
	if not prev or prev.phase ~= msg.v.phase then
		info.phaseLen = math.max(msg.v.left, 0.1)
	end
	if msg.v.phase ~= "floor" and msg.v.phase ~= "doors" then
		info.pub = nil
	end
	Hud.refresh()
end

function Hud.setFloor(pub)
	Hud.info.pub = pub
	local v = Hud.info.v
	if v and v.phase == "floor" and pub.duration then
		Hud.info.phaseEnd = now() + math.max(0, pub.duration - (pub.t or 0))
		Hud.info.phaseLen = pub.duration
	end
	Hud.refresh()
end

function Hud.setProfile(p)
	Hud.info.profile = p
	Hud.info.passes = p.passes or {}
	Hud.refresh()
end

function Hud.toast(text: string, color: Color3?)
	toastL.Text = text
	toastL.TextColor3 = color or C.text
	toastL.Visible = true
	toastUntil = clock + 3.2
end

function Hud.banner(head: string, text: string, secs: number?)
	banner.Head.Text = head
	banner.Text.Text = text
	banner.Visible = true
	bannerUntil = clock + (secs or 3.5)
end

-- Двери открылись: название и правило этажа
function Hud.doors(msg)
	local icon = Floors.CatIcon[msg.cat] or ""
	local head = icon .. " " .. Lang.t("floor." .. msg.id)
	local text = Lang.t("rule." .. msg.id)
	if msg.chimeName then
		text ..= "\n" .. Lang.t("chime.by", { name = msg.chimeName })
	end
	Hud.banner(head, text, 4)
end

function Hud.showReward(msg)
	result.Title.Text = Lang.t("result.title") .. " · " .. Lang.t("floor." .. msg.floor)
	result.Stars.Text = Strings.stars(msg.stars)
	local lines = { Lang.t(if msg.passed then "result.passed" else "result.failed") }
	if msg.top then
		table.insert(lines, Lang.t("result.top"))
	end
	if msg.clean then
		table.insert(lines, Lang.t("result.clean"))
	end
	if msg.first then
		table.insert(lines, Lang.t("result.first"))
	end
	if msg.prize then
		table.insert(lines, Lang.t("result.prize", { item = "item." .. msg.prize }))
	end
	result.Lines.Text = table.concat(lines, "\n")
	result.Coins.Text = Lang.t("result.coins", { n = msg.coins or 0 })
	result.Visible = true
	resultUntil = clock + 4.5
end

local function nameOf(row): string
	if row.bot then
		return Lang.t("ui.bot", { name = Lang.t(row.name) })
	end
	return row.name
end
Hud.nameOf = nameOf

function Hud.showRide(rows, bonus: number?)
	rideWin.Title.Text = "🏙 " .. Lang.t("ride.title")
	local body = rideWin.Body
	for _, c in body:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for i, r in rows do
		if i > 12 then
			break
		end
		Ui.label({
			Name = "Row_" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			TextColor3 = if r.bot then C.dim elseif i == 1 then C.gold else C.text,
			Text = Lang.t(
				"ride.row",
				{ place = i, name = nameOf(r), stars = r.stars, passed = r.passed or 0 }
			),
			Parent = body,
		})
	end
	if bonus then
		rideWin.Bonus.Text = Lang.t("ride.bonus", { n = bonus })
	end
	rideWin.Visible = true
end

function Hud.setRideBonus(n: number)
	rideWin.Bonus.Text = Lang.t("ride.bonus", { n = n })
end

function Hud.update(dt: number)
	clock += dt
	if toastL.Visible and clock > toastUntil then
		toastL.Visible = false
	end
	if banner.Visible and clock > bannerUntil then
		banner.Visible = false
	end
	if result.Visible and clock > resultUntil then
		result.Visible = false
	end
	local v = Hud.info.v
	if v and (v.phase == "lobby" or v.phase == "fall") and rideWin.Visible and v.phase == "lobby" then
		rideWin.Visible = false
	end
	Hud.refresh()
end

function Hud.root(): ScreenGui
	return ui
end

return Hud
