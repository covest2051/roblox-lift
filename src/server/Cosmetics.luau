--[[
	Cosmetics — облик, который видят все:
	  • шапка и аксессуар — детали из примитивов, приваренные к голове (Catalog.parts);
	  • след — Trail между двумя Attachment на корне персонажа;
	  • атрибуты игрока Hat, Acc, Trail, Exit, Pose, Chime — клиент берёт оттуда эффект выхода
	    из лифта и звонок; позу на балконе ставит сервер (Cosmetics.pose);
	  • табличка ★ VIP над головой.
	По умолчанию — сразу, не дожидаясь профиля (DataStore может грузиться 10 с).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Make = require(Shared.Make)
local Profile = require(Shared.Profile)

local Data = require(script.Parent.DataService)
local Monetization = require(script.Parent.Monetization)

local Cosmetics = {}

local ATTR = { hat = "Hat", acc = "Acc", trail = "Trail", exit = "Exit", pose = "Pose", chime = "Chime" }
Cosmetics.Attr = ATTR

local MAT = {
	Foil = Enum.Material.Foil,
	Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass,
	Fabric = Enum.Material.Fabric,
}

function Cosmetics.effective(player: Player, kind: string): string
	local d = Data.get(player)
	if not d then
		return Catalog.Default[kind]
	end
	return Profile.effective(d, kind, Monetization.hasPass(player, "Vip"))
end

-- Детали облика (шапка/аксессуар) на голову: anchored — для манекенов в Кафе
function Cosmetics.attach(head: BasePart, id: string, folderName: string, anchored: boolean?)
	local old = head.Parent and head.Parent:FindFirstChild(folderName)
	if old then
		old:Destroy()
	end
	local it = Catalog.get(id)
	if not it or not it.parts or #it.parts == 0 then
		return
	end
	local folder = Make("Model", { Name = folderName })
	for i, p in it.parts do
		local c = p.color
		local part = Make("Part", {
			Name = folderName .. i,
			Shape = if p.shape == "Ball"
				then Enum.PartType.Ball
				elseif p.shape == "Cylinder" then Enum.PartType.Cylinder
				else Enum.PartType.Block,
			Size = Vector3.new(p.size[1], p.size[2], p.size[3]),
			Color = Color3.fromRGB(c[1], c[2], c[3]),
			Material = MAT[p.mat or ""] or Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			Anchored = anchored == true,
			Parent = folder,
		})
		-- цилиндр Roblox лежит вдоль X: «шляпный» цилиндр ставим вертикально
		local rot = if p.shape == "Cylinder" and not p.ry
			then CFrame.Angles(0, 0, math.rad(90))
			else CFrame.Angles(0, math.rad(p.ry or 0), 0)
		part.CFrame = head.CFrame * CFrame.new(p.at[1], p.at[2], p.at[3]) * rot
		if not anchored then
			Make("WeldConstraint", { Part0 = head, Part1 = part, Parent = part })
		end
	end
	folder.Parent = head.Parent
end

-- След: Trail между двумя точками на корне персонажа
local function trail(root: BasePart, id: string)
	local old = root:FindFirstChild("LiftTrail")
	if old then
		old:Destroy()
	end
	for _, n in { "TrailA", "TrailB" } do
		local a = root:FindFirstChild(n)
		if a then
			a:Destroy()
		end
	end
	local it = Catalog.get(id)
	if not it or not it.colors then
		return
	end
	local a0 = Make("Attachment", { Name = "TrailA", Position = Vector3.new(0, 0.8, 0.4), Parent = root })
	local a1 = Make("Attachment", { Name = "TrailB", Position = Vector3.new(0, -0.8, 0.4), Parent = root })
	local keys = {}
	for i, c in it.colors do
		table.insert(
			keys,
			ColorSequenceKeypoint.new((i - 1) / math.max(1, #it.colors - 1), Color3.fromRGB(c[1], c[2], c[3]))
		)
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
	end
	Make("Trail", {
		Name = "LiftTrail",
		Attachment0 = a0,
		Attachment1 = a1,
		Lifetime = 0.6,
		Color = ColorSequence.new(keys),
		Transparency = NumberSequence.new(0.2, 1),
		LightEmission = 0.4,
		Parent = root,
	})
end

-- Табличка VIP и облик на персонаже
function Cosmetics.dress(player: Player)
	local ch = player.Character
	local head = ch and ch:FindFirstChild("Head") :: BasePart?
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return
	end
	Cosmetics.attach(head, Cosmetics.effective(player, "hat"), "LiftHat")
	Cosmetics.attach(head, Cosmetics.effective(player, "acc"), "LiftAcc")
	trail(root, Cosmetics.effective(player, "trail"))
	local vip = Monetization.hasPass(player, "Vip")
	local tag = head:FindFirstChild("VipTag")
	if vip and not tag then
		local gui = Make("BillboardGui", {
			Name = "VipTag",
			Size = UDim2.fromOffset(60, 22),
			StudsOffset = Vector3.new(0, 3.6, 0),
			MaxDistance = 80,
			Parent = head,
		})
		Make("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "★ VIP",
			TextColor3 = Color3.fromRGB(255, 205, 70),
			TextStrokeTransparency = 0.4,
			Font = Enum.Font.BuilderSansBold,
			TextScaled = true,
			Parent = gui,
		})
	elseif tag and not vip then
		tag:Destroy()
	end
end

-- Поза на балконе (on = false — снять). Позы — разворот тела, без чужих анимаций
function Cosmetics.pose(player: Player, on: boolean)
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return
	end
	if not on then
		hum.Sit = false
		hum.PlatformStand = false
		return
	end
	local it = Catalog.get(Cosmetics.effective(player, "pose"))
	local pose = it and it.pose or "sit"
	if pose == "sit" then
		hum.Sit = true
	elseif pose == "lie" then
		hum.PlatformStand = true
		ch:PivotTo(root.CFrame * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, -1.5, 0))
	elseif pose == "upside" then
		hum.PlatformStand = true
		ch:PivotTo(root.CFrame * CFrame.Angles(0, 0, math.rad(180)))
	end
end

local listeners: { (Player) -> () } = {}
function Cosmetics.onChange(fn: (Player) -> ())
	table.insert(listeners, fn)
end

function Cosmetics.refresh(player: Player)
	for kind, attr in ATTR do
		player:SetAttribute(attr, Cosmetics.effective(player, kind))
	end
	Cosmetics.dress(player)
	for _, fn in listeners do
		task.spawn(fn, player)
	end
end

function Cosmetics.start()
	Data.onLoaded(function(player)
		Cosmetics.refresh(player)
	end)
	Monetization.onPass(function(player, key)
		if key == "Vip" then
			Cosmetics.refresh(player)
		end
	end)
	local function added(player: Player)
		for kind, attr in ATTR do
			player:SetAttribute(attr, Catalog.Default[kind])
		end
		player.CharacterAdded:Connect(function()
			task.defer(Cosmetics.dress, player)
		end)
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
end

return Cosmetics
