--[[
	Shop — магазин: вкладки «Облик» (шапки, аксессуары, след, выход из лифта, поза на балконе,
	звонок: купить за монеты или напрямую за Robux, надеть), «Капсула» (точный шанс каждого
	предмета, сумма 100%; в регионах с ограничением — кнопки нет), «Пропуска» (×2 Монеты, VIP,
	Эмоции+, монеты, «Подвал сейчас!»). Промпты открывает только сервер.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Ui)
local Lang = require(script.Parent.Lang)

local Shop = {}

local C = Ui.colors
local Make = Ui.Make

local win: Frame
local body: ScrollingFrame
local reward: Frame
local tab = "items"
local profile = nil

local function send(p)
	Net.ClientAction:FireServer(p)
end

local function clear()
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local order = 0
local function row(name: string, height: number)
	order += 1
	local f = Make("Frame", {
		Name = name,
		LayoutOrder = order,
		BackgroundColor3 = C.panel2,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, height),
		ZIndex = 11,
		Parent = body,
	})
	Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = f })
	return f
end

local function header(text: string)
	order += 1
	Ui.label({
		Name = "H" .. order,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 28),
		Font = Ui.fontBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Text = text,
		Parent = body,
	})
end

local function btn(parent, text: string, color: Color3?, onClick)
	local b = Ui.button({
		Name = "Button",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(130, 34),
		TextSize = 16,
		BackgroundColor3 = color or C.button,
		ZIndex = 11,
		Text = text,
		Parent = parent,
	})
	b.Activated:Connect(onClick)
	return b
end

local function owned(id: string): boolean
	return profile ~= nil and table.find(profile.owned or {}, id) ~= nil
end

local function itemsTab()
	local passes = profile and profile.passes or {}
	for _, kind in Catalog.Kinds do
		header(Lang.t("shop.kind." .. kind))
		for _, it in Catalog.Items do
			if it.kind == kind then
				local f = row(it.id, 44)
				Ui.label({
					Name = "Name",
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -160, 1, 0),
					TextSize = 17,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 11,
					TextColor3 = Ui.rarityColor(it.rarity),
					Text = Lang.t("item." .. it.id) .. " · " .. Lang.t("rarity." .. it.rarity),
					Parent = f,
				})
				local worn = profile and profile.equipped and profile.equipped[kind] == it.id
				if worn then
					btn(f, Lang.t("shop.equipped"), C.panel, function() end)
				elseif owned(it.id) or (it.rarity == "Vip" and passes.Vip) then
					btn(f, Lang.t("shop.equip"), C.button, function()
						send({ t = "equip", id = it.id })
					end)
				elseif it.rarity == "Vip" then
					btn(f, Lang.t("shop.vipOnly"), C.gold, function()
						send({ t = "pass", key = "Vip" })
					end)
				elseif it.rarity == "Secret" then
					btn(f, Lang.t("shop.secret"), C.panel, function() end)
				else
					btn(f, Lang.t("shop.buyCoins", { n = Catalog.price(it.id) }), C.button, function()
						send({ t = "buyCoins", id = it.id })
					end)
					local key = "Direct" .. it.rarity
					if Config.Products[key] then
						local d = btn(
							f,
							Lang.t("shop.buyRobux", { n = Config.Products[key].robux }),
							C.robux,
							function()
								send({ t = "product", key = key, item = it.id })
							end
						)
						d.Name = "Direct"
						d.Position = UDim2.new(1, -146, 0.5, 0)
						d.Size = UDim2.fromOffset(100, 34)
					end
				end
			end
		end
	end
end

local function chestTab()
	header("🎁 " .. Lang.t("shop.chestTitle"))
	local d = row("Desc", 60)
	Ui.label({
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextSize = 16,
		ZIndex = 11,
		Text = Lang.t("shop.chestDesc"),
		Parent = d,
	})
	if profile and profile.chestAllowed then
		local open = row("OpenChest", 50)
		btn(open, Lang.t("shop.chestOpen", { n = Config.Products.Chest.robux }), C.robux, function()
			send({ t = "product", key = "Chest" })
		end).Size =
			UDim2.fromOffset(220, 40)
	else
		local no = row("ChestNo", 70)
		Ui.label({
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			TextSize = 16,
			ZIndex = 11,
			TextColor3 = C.warn,
			Text = Lang.t("shop.chestNo"),
			Parent = no,
		})
	end
	for _, o in Catalog.odds() do
		local f = row("Odds_" .. o.id, 28)
		Ui.label({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -100, 1, 0),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
			TextColor3 = Ui.rarityColor(o.rarity),
			Text = Lang.t("item." .. o.id) .. " · " .. Lang.t("rarity." .. o.rarity),
			Parent = f,
		})
		Ui.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.fromOffset(80, 28),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 11,
			Text = Catalog.formatBp(o.bp),
			Parent = f,
		})
	end
end

local PASS_TEXT = {
	Emotes = { "shop.passEmotes", "shop.passEmotesDesc" },
	DoubleCoins = { "shop.passDouble", "shop.passDoubleDesc" },
	Vip = { "shop.passVip", "shop.passVipDesc" },
}

local function passesTab()
	local passes = profile and profile.passes or {}
	local avail = profile and profile.available or {}
	for _, key in Config.PassOrder do
		local f = row(key, 64)
		local tx = PASS_TEXT[key]
		Ui.label({
			Position = UDim2.fromOffset(10, 2),
			Size = UDim2.new(1, -160, 0, 26),
			Font = Ui.fontBold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
			Text = Lang.t(tx[1]),
			Parent = f,
		})
		Ui.label({
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(1, -160, 0, 34),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
			TextColor3 = C.dim,
			Text = Lang.t(tx[2]),
			Parent = f,
		})
		if passes[key] then
			btn(f, Lang.t("shop.owned"), C.panel, function() end)
		else
			btn(
				f,
				if avail[key] == false
					then Lang.t("shop.soonShort")
					else Lang.t("shop.buyRobux", { n = Config.Passes[key].robux }),
				C.robux,
				function()
					send({ t = "pass", key = key })
				end
			)
		end
	end
	for _, key in { "Coins500", "Coins3000", "Basement" } do
		local f = row(key, if key == "Basement" then 64 else 44)
		local title = if key == "Coins500"
			then "shop.coins500"
			elseif key == "Coins3000" then "shop.coins3000"
			else "shop.basement"
		Ui.label({
			Position = UDim2.fromOffset(10, 2),
			Size = UDim2.new(1, -160, 0, 26),
			Font = Ui.fontBold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
			Text = (if key == "Basement" then "🕳 " else "🪙 ") .. Lang.t(title),
			Parent = f,
		})
		if key == "Basement" then
			Ui.label({
				Position = UDim2.fromOffset(10, 28),
				Size = UDim2.new(1, -160, 0, 34),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 11,
				TextColor3 = C.dim,
				Text = Lang.t("shop.basementDesc"),
				Parent = f,
			})
		end
		local ok = key ~= "Basement" or (profile and profile.basementOk ~= false)
		btn(
			f,
			if avail[key] == false
				then Lang.t("shop.soonShort")
				else Lang.t("shop.buyRobux", { n = Config.Products[key].robux }),
			if ok then C.robux else C.panel,
			function()
				send({ t = "product", key = key })
			end
		)
	end
	header(Lang.t("shop.fair"))
end

function Shop.refresh()
	if not win then
		return
	end
	win.Title.Text = "🛍 " .. Lang.t("ui.shop")
	win.Close.Text = Lang.t("ui.close")
	win.Tab_items.Text = Lang.t("shop.tabItems")
	win.Tab_chest.Text = Lang.t("shop.tabChest")
	win.Tab_passes.Text = Lang.t("shop.tabPasses")
	for _, t in { "items", "chest", "passes" } do
		(win["Tab_" .. t] :: TextButton).BackgroundColor3 = if t == tab then C.brass else C.button
	end
	win.Coins.Text = Lang.t("ui.coins", { n = profile and profile.coins or 0 })
	clear()
	order = 0
	if tab == "items" then
		itemsTab()
	elseif tab == "chest" then
		chestTab()
	else
		passesTab()
	end
end

function Shop.build()
	local root = Ui.screen()
	win = Ui.scaled(
		Ui.panel({
			Name = "Shop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(720, 480),
			Visible = false,
			ZIndex = 11,
			Parent = root,
		}),
		0.5
	)
	Ui.stroke(win, C.brass, 2)
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.fromOffset(200, 36),
		Font = Ui.fontBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Text = "",
		Parent = win,
	})
	Ui.label({
		Name = "Coins",
		Position = UDim2.new(1, -260, 0, 10),
		Size = UDim2.fromOffset(130, 32),
		Font = Ui.fontBold,
		TextSize = 20,
		TextColor3 = C.gold,
		ZIndex = 11,
		Text = "",
		Parent = win,
	})
	local close = Ui.button({
		Name = "Close",
		Position = UDim2.new(1, -118, 0, 8),
		Size = UDim2.fromOffset(106, 34),
		ZIndex = 11,
		Text = "",
		Parent = win,
	})
	close.Activated:Connect(function()
		win.Visible = false
	end)
	for i, t in { "items", "chest", "passes" } do
		local b = Ui.button({
			Name = "Tab_" .. t,
			Position = UDim2.fromOffset(16 + (i - 1) * 150, 50),
			Size = UDim2.fromOffset(142, 34),
			ZIndex = 11,
			Text = "",
			Parent = win,
		})
		b.Activated:Connect(function()
			tab = t
			Shop.refresh()
		end)
	end
	body = Make("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 92),
		Size = UDim2.new(1, -32, 1, -104),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		ZIndex = 11,
		Parent = win,
	})
	Make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	-- что выпало
	reward = Ui.scaled(
		Ui.panel({
			Name = "Reward",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(340, 170),
			Visible = false,
			ZIndex = 12,
			Parent = root,
		}),
		0.5
	)
	Ui.stroke(reward, C.gold, 2)
	Ui.label({
		Name = "Head",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 30),
		TextSize = 20,
		ZIndex = 12,
		Text = "",
		Parent = reward,
	})
	Ui.label({
		Name = "Item",
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, 50),
		Font = Ui.fontBold,
		TextSize = 28,
		ZIndex = 12,
		Text = "",
		Parent = reward,
	})
	local ok = Ui.button({
		Name = "Ok",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(120, 36),
		ZIndex = 12,
		Text = "OK",
		Parent = reward,
	})
	ok.Activated:Connect(function()
		reward.Visible = false
	end)
	Lang.onChange(Shop.refresh)
	Shop.refresh()
end

function Shop.setProfile(p)
	profile = p
	if win and win.Visible then
		Shop.refresh()
	end
end

function Shop.toggle()
	win.Visible = not win.Visible
	if win.Visible then
		Shop.refresh()
	end
end

function Shop.showReward(id: string, head: string, refund: number?)
	reward.Head.Text = head
	local it = Catalog.get(id)
	reward.Item.Text = Lang.t("item." .. id)
	reward.Item.TextColor3 = Ui.rarityColor(it and it.rarity or "Common")
	if refund then
		reward.Head.Text = head .. " " .. Lang.t("shop.chestDupGot", { n = refund })
	end
	reward.Visible = true
end

function Shop.window(): Frame
	return win
end

return Shop
