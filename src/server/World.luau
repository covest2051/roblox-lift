--[[
	World — всё в мире из примитивов:
	  • кабина лифта (стоит на месте: бирюзовые стены, латунная панель с 3 кнопками голосования
	    и золотой VIP-кнопкой, табло-«глаз» над дверью, поручни, раздвижные двери);
	  • мягкий балкон зрителей с подушками;
	  • сцена перед дверью — лобби, этаж или крыша — строится из описаний деталей модуля
	    этажа (FloorKit) и меняется по inst.changes;
	  • боты-пассажиры — смешные человечки из шаров.
	Координаты сцены (порог двери = 0, +Z — от двери) → мир: World.Origin + (x, y, z).
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Make = require(Shared.Make)
local Bots = require(Shared.Bots)

local World = {}

World.Origin = Vector3.new(0, 60, 0)

local root: Model? = nil
local stage: Model? = nil
local stageParts: { [string]: BasePart } = {}
local doors: { BasePart } = {}
local display: TextLabel? = nil
local panel: { { part: BasePart, label: TextLabel } } = {}
local botModels: { [any]: Model } = {}

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

function World.toWorld(x: number, y: number, z: number): Vector3
	return World.Origin + Vector3.new(x, y, z)
end

function World.toStage(v: Vector3): (number, number, number)
	local d = v - World.Origin
	return d.X, d.Y, d.Z
end

local function block(props)
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	return Make("Part", props)
end

-------------------------------------------------------------------------------
-- Свет
-------------------------------------------------------------------------------
function World.lighting()
	local L = game:GetService("Lighting")
	L.ClockTime = 14
	Make("Atmosphere", { Density = 0.25, Color = Color3.fromRGB(200, 220, 255), Parent = L })
end

-------------------------------------------------------------------------------
-- Кабина и балкон
-------------------------------------------------------------------------------
local TEAL = Color3.fromRGB(60, 170, 165)
local BRASS = Color3.fromRGB(205, 160, 70)

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, size: number?): TextLabel
	local gui = Make("SurfaceGui", {
		Name = "Gui",
		Face = face,
		CanvasSize = Vector2.new(400, 200),
		LightInfluence = 0,
		Parent = part,
	})
	return Make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		TextScaled = size == nil,
		TextSize = size or 40,
		Font = Enum.Font.BuilderSansBold,
		Parent = gui,
	})
end

function World.build()
	root = Make("Model", { Name = "Lift" })
	local r = root :: Model
	local function P(name, x, y, z, sx, sy, sz, color, mat, extra)
		local props = {
			Name = name,
			Size = Vector3.new(sx, sy, sz),
			CFrame = CFrame.new(World.toWorld(x, y, z)),
			Color = color,
			Material = mat or Enum.Material.SmoothPlastic,
			Parent = r,
		}
		for k, v in extra or {} do
			props[k] = v
		end
		return block(props)
	end
	-- кабина: пол y = 0, x ∈ [-10, 10], z ∈ [-16, 0]
	P("CabinFloor", 0, -0.5, -8, 22, 1, 17, Color3.fromRGB(80, 60, 50), Enum.Material.WoodPlanks)
	P("CabinCeiling", 0, 12.5, -8, 22, 1, 17, Color3.fromRGB(230, 230, 220))
	P("CabinLeft", -10.5, 6, -8, 1, 12, 17, TEAL)
	P("CabinRight", 10.5, 6, -8, 1, 12, 17, TEAL)
	P("CabinBack", 0, 6, -16.5, 22, 12, 1, TEAL)
	P("FrontLeft", -8, 6, 0.5, 5, 12, 1, TEAL)
	P("FrontRight", 8, 6, 0.5, 5, 12, 1, TEAL)
	P("FrontTop", 0, 10.75, 0.5, 11, 3.5, 1, TEAL)
	for i, x in { -9.8, 9.8 } do
		P("Rail" .. i, x, 3.5, -8, 0.4, 0.4, 14, BRASS, Enum.Material.Metal)
	end
	P("RailBack", 0, 3.5, -15.8, 18, 0.4, 0.4, BRASS, Enum.Material.Metal)
	local lamp = P(
		"Lamp",
		0,
		12,
		-8,
		6,
		0.2,
		6,
		Color3.fromRGB(255, 250, 230),
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	Make(
		"PointLight",
		{ Name = "Light", Brightness = 1.6, Range = 26, Color = Color3.fromRGB(255, 240, 220), Parent = lamp }
	)
	-- двери
	doors = {
		P("DoorL", -2.75, 4.5, 0.3, 5.5, 9, 0.4, BRASS, Enum.Material.Metal),
		P("DoorR", 2.75, 4.5, 0.3, 5.5, 9, 0.4, BRASS, Enum.Material.Metal),
	}
	-- табло-«глаз» над дверью (внутри кабины)
	local disp =
		P("Display", 0, 10.6, -0.2, 6, 2.2, 0.3, Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic)
	display = surfaceText(disp, Enum.NormalId.Front, "1")
	-- то же табло снаружи, над дверью со стороны этажа
	local dispOut =
		P("DisplayOut", 0, 10.6, 1.1, 6, 2.2, 0.3, Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic)
	surfaceText(dispOut, Enum.NormalId.Back, "▲")
	-- панель голосования справа от двери: 3 кнопки + золотая VIP
	P("Panel", 7.5, 5, -0.8, 3.4, 6, 0.4, BRASS, Enum.Material.Metal)
	panel = {}
	for k = 1, Config.Picker.Options do
		local b = P(
			"VoteButton" .. k,
			7.5,
			7 - (k - 1) * 1.5,
			-1.05,
			2.6,
			1.2,
			0.2,
			Color3.fromRGB(250, 245, 230),
			Enum.Material.SmoothPlastic
		)
		table.insert(panel, { part = b, label = surfaceText(b, Enum.NormalId.Front, "?") })
	end
	local vip =
		P("VipButton", 7.5, 2.6, -1.05, 1.4, 1.4, 0.2, Color3.fromRGB(255, 205, 60), Enum.Material.Foil)
	surfaceText(vip, Enum.NormalId.Front, "★")
	-- рамка двери снаружи (видна с этажа)
	P(
		"Portal",
		0,
		6,
		1.3,
		13,
		13,
		0.6,
		Color3.fromRGB(70, 60, 80),
		Enum.Material.Metal,
		{ CanCollide = false, Transparency = 0.6 }
	)
	-- балкон зрителей
	local B = Config.Stage.Balcony
	P("Balcony", B.x, B.y - 0.5, B.z, B.w, 1, B.d, Color3.fromRGB(240, 170, 200), Enum.Material.Fabric)
	P(
		"BalconyRail",
		B.x,
		B.y + 1.5,
		B.z - B.d / 2,
		B.w,
		3,
		0.4,
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic,
		{ Transparency = 0.5 }
	)
	P(
		"BalconyBack",
		B.x,
		B.y + 3,
		B.z + B.d / 2,
		B.w,
		6,
		0.6,
		Color3.fromRGB(120, 70, 140),
		Enum.Material.Fabric
	)
	for i = 1, 8 do
		local x = B.x - B.w / 2 + i * B.w / 9
		Make("Part", {
			Name = "Cushion" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(World.toWorld(x, B.y + 0.6, B.z + B.d / 2 - 1.5)),
			Color = Color3.fromRGB(255, 200, 120 + (i % 3) * 40),
			Material = Enum.Material.Fabric,
			Anchored = true,
			Parent = r,
		})
	end
	surfaceText(
		P("BalconySign", B.x, B.y + 6.5, B.z + B.d / 2 - 0.4, 14, 2.4, 0.3, Color3.fromRGB(60, 30, 70)),
		Enum.NormalId.Front,
		"balcony.sign"
	)
	r.Parent = Workspace
end

-------------------------------------------------------------------------------
-- Двери, табло, панель
-------------------------------------------------------------------------------
local doorsOpen = nil
function World.setDoors(open: boolean)
	if doorsOpen == open then
		return
	end
	doorsOpen = open
	for i, d in doors do
		local side = if i == 1 then -1 else 1
		local x = side * (if open then 7.6 else 2.75)
		local goal = { CFrame = CFrame.new(World.toWorld(x, 4.5, 0.3)) }
		TweenService:Create(d, TweenInfo.new(0.9, Enum.EasingStyle.Quad), goal):Play()
		d.CanCollide = not open
	end
end

function World.setDisplay(text: string)
	if display then
		display.Text = text
	end
	local out = root and root:FindFirstChild("DisplayOut")
	local l = out and out:FindFirstChild("Gui") and out.Gui:FindFirstChild("Label")
	if l then
		(l :: TextLabel).Text = text
	end
end

-- Панель: категории (иконки) и счёт голосов; nil — кнопки погасли
function World.setPanel(icons: { string }?, sums: { number }?)
	for k, b in panel do
		local icon = icons and icons[k]
		b.label.Text = if icon
			then icon .. " ?" .. (if sums and sums[k] and sums[k] > 0 then "  " .. sums[k] else "")
			else "·"
		b.part.Color = if icon then Color3.fromRGB(250, 245, 230) else Color3.fromRGB(120, 115, 110)
	end
end

-------------------------------------------------------------------------------
-- Сцена из описаний деталей
-------------------------------------------------------------------------------
local SHAPE = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Disc = Enum.PartType.Cylinder,
	Cylinder = Enum.PartType.Cylinder,
}

local function placement(s): (CFrame, Vector3)
	local pos = World.toWorld(s.x, s.y, s.z)
	local ry = math.rad(s.ry or 0)
	if s.shape == "Disc" then
		return CFrame.new(pos) * CFrame.Angles(0, ry, math.rad(90)), Vector3.new(s.sy, s.sx, s.sx)
	elseif s.shape == "Ball" then
		return CFrame.new(pos), Vector3.new(s.sx, s.sx, s.sx)
	elseif s.slope then
		local rise = s.slope[2] - s.slope[1]
		local ang = math.atan2(rise, s.sz)
		local len = math.sqrt(s.sz * s.sz + rise * rise)
		local cy = (s.slope[1] + s.slope[2]) / 2 - s.sy / 2
		return CFrame.new(World.toWorld(s.x, cy, s.z)) * CFrame.Angles(-ang, 0, 0),
			Vector3.new(s.sx, s.sy, len)
	end
	return CFrame.new(pos) * CFrame.Angles(0, ry, 0), Vector3.new(s.sx, s.sy, s.sz)
end

local function refresh(part: BasePart, s)
	local cf, size = placement(s)
	part.Size = size
	part.CFrame = cf
	if s.color then
		part.Color = rgb(s.color)
	end
	part.Transparency = s.alpha or 0
	part.CanCollide = s.collide ~= false
	if s.mat then
		local ok, m = pcall(function()
			return (Enum.Material :: any)[s.mat]
		end)
		if ok and m then
			part.Material = m
		end
	end
	local light = part:FindFirstChild("Light") :: PointLight?
	if s.light and s.light > 0 then
		if not light then
			light = Make("PointLight", { Name = "Light", Parent = part })
		end
		local l = light :: PointLight
		l.Range = s.light
		l.Brightness = 2
		l.Color = part.Color
		l.Enabled = true
	elseif light then
		light.Enabled = false
	end
end

local function makePart(s): BasePart
	local part
	if s.shape == "Wedge" then
		part = Make("WedgePart", { Name = s.name, Anchored = true })
	else
		part = Make("Part", { Name = s.name, Anchored = true, Shape = SHAPE[s.shape] or Enum.PartType.Block })
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanQuery = s.collide ~= false
	part.CanTouch = false
	refresh(part, s)
	if s.bounce then
		part:SetAttribute("Bounce", s.bounce) -- клиент подбрасывает своего персонажа
	end
	if s.ice then
		part.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.02, 0.1, 100, 1)
	end
	if s.label then
		local l = surfaceText(part, Enum.NormalId.Back, s.label)
		l:SetAttribute("Key", s.label) -- клиент переводит
		local l2 = surfaceText(part, Enum.NormalId.Front, s.label)
		l2.Parent.Name = "GuiFront"
		l2:SetAttribute("Key", s.label)
	end
	return part
end

-- Построить сцену (лобби/этаж/крыша) заново из inst
function World.buildStage(inst)
	if stage then
		stage:Destroy()
	end
	stageParts = {}
	local m = Make("Model", { Name = "Stage" })
	m:SetAttribute("Floor", inst.id)
	for _, name in inst.order do
		local p = makePart(inst.parts[name])
		p.Parent = m
		stageParts[name] = p
	end
	m.Parent = Workspace
	stage = m
	return m
end

function World.stagePart(name: string): BasePart?
	return stageParts[name]
end

function World.applyChanges(inst, changes)
	for _, ch in changes do
		local part = stageParts[ch.name]
		local s = inst.parts[ch.name]
		if part and s then
			refresh(part, s)
		end
	end
end

-------------------------------------------------------------------------------
-- Боты-пассажиры
-------------------------------------------------------------------------------
function World.addBot(id, nameKey: string)
	World.removeBot(id)
	local look = Bots.Looks[nameKey] or { body = { 200, 200, 200 } }
	local m = Make("Model", { Name = "Bot_" .. tostring(id) })
	m:SetAttribute("BotName", nameKey)
	local feet = Make("Part", {
		Name = "Feet",
		Size = Vector3.new(1, 0.2, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Anchored = true,
		Parent = m,
	})
	local function ball(name, d, y, color, extra)
		local props = {
			Name = name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			CFrame = CFrame.new(0, y, 0),
			Color = rgb(color),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Parent = m,
		}
		for k, v in extra or {} do
			props[k] = v
		end
		return Make("Part", props)
	end
	ball("Body", 3, 1.7, look.body)
	local head = ball("Head", 2.2, 3.9, { 255, 220, 190 })
	ball("EyeL", 0.45, 4.1, { 30, 30, 40 }, { CFrame = CFrame.new(-0.45, 4.1, -0.95) })
	ball("EyeR", 0.45, 4.1, { 30, 30, 40 }, { CFrame = CFrame.new(0.45, 4.1, -0.95) })
	local extra = look.extra
	if extra == "chefhat" then
		ball("Hat", 1.8, 5.3, { 250, 250, 250 })
	elseif extra == "mustache" then
		Make("Part", {
			Name = "Mustache",
			Size = Vector3.new(1.2, 0.25, 0.3),
			CFrame = CFrame.new(0, 3.6, -1.05),
			Color = Color3.fromRGB(60, 40, 30),
			Anchored = true,
			CanCollide = false,
			Parent = m,
		})
	elseif extra == "cat" then
		ball("Cat", 1.3, 5.3, { 250, 170, 60 })
	elseif extra == "balloon" then
		ball("Balloon", 1.6, 7, { 255, 80, 120 })
	elseif extra == "glasses" then
		Make("Part", {
			Name = "Glasses",
			Size = Vector3.new(1.4, 0.3, 0.2),
			CFrame = CFrame.new(0, 4.1, -1.15),
			Color = Color3.fromRGB(30, 30, 30),
			Anchored = true,
			CanCollide = false,
			Parent = m,
		})
	elseif extra == "box" then
		Make("Part", {
			Name = "Box",
			Size = Vector3.new(1.6, 1.2, 1.2),
			CFrame = CFrame.new(0, 1.8, -1.6),
			Color = Color3.fromRGB(190, 140, 90),
			Anchored = true,
			CanCollide = false,
			Parent = m,
		})
	end
	m.PrimaryPart = feet
	local gui = Make("BillboardGui", {
		Name = "Tag",
		Size = UDim2.fromOffset(150, 28),
		StudsOffset = Vector3.new(0, 2.4, 0),
		MaxDistance = 90,
		Parent = head,
	})
	local l = Make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "🤖 " .. nameKey,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 0.3,
		Font = Enum.Font.BuilderSansBold,
		TextScaled = true,
		Parent = gui,
	})
	l:SetAttribute("Key", nameKey)
	l:SetAttribute("Prefix", "🤖 ")
	local folder = Workspace:FindFirstChild("Passengers")
		or Make("Folder", { Name = "Passengers", Parent = Workspace })
	m.Parent = folder
	botModels[id] = m
	return m
end

function World.removeBot(id)
	local m = botModels[id]
	if m then
		m:Destroy()
		botModels[id] = nil
	end
end

function World.bot(id): Model?
	return botModels[id]
end

-- Поставить бота: ноги в точку сцены, лицом по направлению движения
function World.moveBot(id, x: number, y: number, z: number, yaw: number?)
	local m = botModels[id]
	if m then
		m:PivotTo(CFrame.new(World.toWorld(x, y, z)) * CFrame.Angles(0, yaw or 0, 0))
	end
end

return World
