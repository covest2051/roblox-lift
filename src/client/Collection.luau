--[[
	Collection — окно «Коллекция этажей»: «Открыто N/19», сетка карточек (иконка, название,
	рекорд звёзд, сколько раз сыграно). Неоткрытые — «???»; Подвал — с намёком.
	Нажал карточку — внизу правило и рекорд.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Floors = require(Shared.Floors)
local Strings = require(Shared.Strings)

local Ui = require(script.Parent.Ui)
local Lang = require(script.Parent.Lang)

local Collection = {}

local C = Ui.colors
local Make = Ui.Make

local win: Frame
local profile = nil
local selected: string? = nil

function Collection.build()
	local root = Ui.screen()
	win = Ui.scaled(
		Ui.panel({
			Name = "Collection",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(700, 470),
			Visible = false,
			ZIndex = 10,
			Parent = root,
		}),
		0.5
	)
	Ui.stroke(win, C.brass, 2)
	Ui.label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -140, 0, 36),
		Font = Ui.fontBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
		Text = "",
		Parent = win,
	})
	Ui.label({
		Name = "Opened",
		Position = UDim2.new(1, -330, 0, 10),
		Size = UDim2.fromOffset(200, 32),
		Font = Ui.fontBold,
		TextSize = 22,
		TextColor3 = C.gold,
		ZIndex = 10,
		Text = "",
		Parent = win,
	})
	local close = Ui.button({
		Name = "Close",
		Position = UDim2.new(1, -118, 0, 8),
		Size = UDim2.fromOffset(106, 34),
		ZIndex = 10,
		Text = "",
		Parent = win,
	})
	close.Activated:Connect(function()
		win.Visible = false
	end)
	local grid = Make("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 330),
		ZIndex = 10,
		Parent = win,
	})
	Make("UIGridLayout", {
		CellSize = UDim2.fromOffset(128, 62),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, id in Floors.Order do
		local b = Ui.button({
			Name = "Card_" .. id,
			LayoutOrder = i,
			TextSize = 15,
			TextWrapped = true,
			ZIndex = 10,
			Text = "",
			Parent = grid,
		})
		b.Activated:Connect(function()
			selected = id
			Collection.refresh()
		end)
	end
	Ui.label({
		Name = "Detail",
		Position = UDim2.new(0, 16, 1, -82),
		Size = UDim2.new(1, -32, 0, 72),
		TextSize = 18,
		TextWrapped = true,
		ZIndex = 10,
		Text = "",
		Parent = win,
	})
	Lang.onChange(Collection.refresh)
	Collection.refresh()
end

function Collection.setProfile(p)
	profile = p
	Collection.refresh()
end

function Collection.refresh()
	if not win then
		return
	end
	win.Title.Text = "🏢 " .. Lang.t("collection.title")
	win.Close.Text = Lang.t("ui.close")
	local floors = profile and profile.floors or {}
	local n = 0
	for _, id in Floors.Order do
		local card = floors[id]
		local def = Floors.get(id)
		local b = win.Grid["Card_" .. id] :: TextButton
		if card then
			n += 1
			b.Text = def.icon .. " " .. Lang.t("floor." .. id) .. "\n" .. Strings.stars(card.best)
			b.BackgroundColor3 = Ui.catColor(def.cat):Lerp(C.button, 0.55)
		else
			b.Text = Floors.CatIcon[def.cat] .. " " .. Lang.t("collection.locked")
			b.BackgroundColor3 = C.panel2
		end
	end
	win.Opened.Text = Lang.t("collection.opened", { n = n, total = #Floors.Order })
	local detail = Lang.t("collection.hint")
	if selected then
		local card = floors[selected]
		if card then
			detail = Lang.t("floor." .. selected)
				.. ": "
				.. Lang.t("rule." .. selected)
				.. "\n"
				.. Lang.t("collection.card", { stars = Strings.stars(card.best), n = card.n })
		elseif selected == "basement" then
			detail = Lang.t("collection.secret")
		else
			detail = Lang.t("cat." .. Floors.get(selected).cat) .. " · " .. Lang.t("collection.locked")
		end
	end
	win.Detail.Text = detail
end

function Collection.toggle()
	win.Visible = not win.Visible
	if win.Visible then
		Collection.refresh()
	end
end

function Collection.window(): Frame
	return win
end

return Collection
