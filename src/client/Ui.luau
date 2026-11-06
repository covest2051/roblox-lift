--[[
	Ui — общие стили и маленькие фабрики элементов интерфейса.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Make)
local Config = require(Shared.Config)

local Ui = {}

Ui.Make = Make
Ui.font = Enum.Font.BuilderSans
Ui.fontBold = Enum.Font.BuilderSansBold

Ui.colors = {
	text = Color3.fromRGB(240, 246, 255),
	dim = Color3.fromRGB(160, 176, 200),
	panel = Color3.fromRGB(16, 34, 40),
	panel2 = Color3.fromRGB(28, 58, 64),
	button = Color3.fromRGB(40, 92, 98),
	brass = Color3.fromRGB(205, 160, 70),
	gold = Color3.fromRGB(255, 205, 70),
	good = Color3.fromRGB(100, 240, 150),
	danger = Color3.fromRGB(255, 70, 80),
	warn = Color3.fromRGB(255, 170, 40),
	robux = Color3.fromRGB(40, 170, 90),
	sky = Color3.fromRGB(120, 200, 255),
	fire = Color3.fromRGB(255, 110, 70),
	race = Color3.fromRGB(90, 190, 255),
	brain = Color3.fromRGB(200, 130, 255),
	coop = Color3.fromRGB(110, 225, 130),
	calm = Color3.fromRGB(255, 205, 120),
	boss = Color3.fromRGB(255, 205, 70),
	secret = Color3.fromRGB(150, 150, 170),
}

function Ui.rarityColor(rarity: string): Color3
	local r = Config.Rarity[rarity]
	if r then
		return Color3.fromRGB(r.color[1], r.color[2], r.color[3])
	end
	if rarity == "Vip" then
		return Ui.colors.gold
	end
	return Ui.colors.dim
end

local screen: ScreenGui? = nil

function Ui.screen(): ScreenGui
	if screen then
		return screen
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = Make("ScreenGui", {
		Name = "LiftUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	return screen :: ScreenGui
end

-- Масштаб под экран (макет 1280×720). UIScale вешается на панели, не на весь экран.
-- HUD не сжимается меньше 0.75 (кнопки и текст на телефоне), большие окна вписываются в экран.
local scales: { { s: UIScale, min: number } } = {}
local baseScale = 1
local viewport = Vector2.new(1280, 720)
local vpListeners: { () -> () } = {}

local function scaleFor(min: number): number
	return math.clamp(baseScale, min, 1.25)
end

local function computeScale()
	local ok, vp = pcall(function()
		return workspace.CurrentCamera.ViewportSize
	end)
	if ok and vp and vp.X > 0 then
		baseScale = math.min(vp.X / 1280, vp.Y / 720)
		viewport = vp
	end
	for _, e in scales do
		e.s.Scale = scaleFor(e.min)
	end
	for _, fn in vpListeners do
		task.spawn(fn)
	end
end

function Ui.scaled<T>(obj: T, min: number?): T
	local m = min or 0.55
	local s = Make("UIScale", { Scale = scaleFor(m), Parent = obj })
	table.insert(scales, { s = s, min = m })
	return obj
end

function Ui.viewport(): Vector2
	return viewport
end

function Ui.onViewport(fn: () -> ())
	table.insert(vpListeners, fn)
end

function Ui.watchViewport()
	computeScale()
	pcall(function()
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(computeScale)
	end)
end

function Ui.catColor(cat: string?): Color3
	return (Ui.colors :: any)[cat or ""] or Ui.colors.dim
end

function Ui.scale(): number
	return baseScale
end

function Ui.isSmall(): boolean
	return baseScale < 0.8
end

-- Узкий экран (телефон в альбомной ориентации): своя раскладка HUD
function Ui.isNarrow(): boolean
	return viewport.X < 1000
end

function Ui.label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = Ui.font,
		TextColor3 = Ui.colors.text,
		TextStrokeTransparency = 0.7,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextSize = 18,
		TextWrapped = true,
		RichText = true,
	}
	for k, v in props do
		p[k] = v
	end
	return Make("TextLabel", p)
end

function Ui.panel(props)
	local p = {
		BackgroundColor3 = Ui.colors.panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}
	for k, v in props do
		p[k] = v
	end
	local f = Make("Frame", p)
	Make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = f })
	return f
end

function Ui.button(props)
	local p = {
		BackgroundColor3 = Ui.colors.button,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Ui.fontBold,
		TextColor3 = Ui.colors.text,
		TextSize = 18,
		AutoButtonColor = true,
	}
	for k, v in props do
		p[k] = v
	end
	local b = Make("TextButton", p)
	Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
	return b
end

function Ui.stroke(obj: Instance, color: Color3, thickness: number?)
	return Make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = obj,
	})
end

return Ui
