--[[
	Controls — то, что игрок чувствует на этаже:
	  • клавиши: E — действие (Сесть/Нажать/Подарок), 1–3 — голос в кабине;
	  • зеркальный этаж: влево ↔ вправо (обёртка над moveFunction модуля управления);
	  • батуты и пузыри: стоишь на детали с атрибутом Bounce — подбрасывает (своего персонажа
	    двигает клиент, у него сетевое владение);
	  • тёмный этаж: свет гаснет, у каждого персонажа и бота — фонарик (только у себя на экране);
	  • тряска камеры (событие кабины, падение лифта), лёгкий наклон в Подвале, мигание света.
]]

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Make)

local Controls = {}

Controls.onAct = nil :: (() -> ())?
Controls.onVote = nil :: ((number) -> ())?

local player = Players.LocalPlayer
local shake = 0
local flickerT = 0
local clock = 0
local dark = false
local saved = nil :: any
local mirrorOn = false
local controls = nil :: any
local origMove = nil :: any

function Controls.build()
	ContextActionService:BindAction("LiftAct", function(_, state)
		if state == Enum.UserInputState.Begin and Controls.onAct then
			Controls.onAct()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)
	for k = 1, 3 do
		ContextActionService:BindAction("LiftVote" .. k, function(_, state)
			if state == Enum.UserInputState.Begin and Controls.onVote then
				Controls.onVote(k)
			end
			return Enum.ContextActionResult.Pass
		end, false, ({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three })[k])
	end
	-- модуль управления (в Studio/игре есть, на заглушке — нет)
	pcall(function()
		local ps = player:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if pm then
			local mod = (require :: any)(pm)
			controls = mod.GetControls(mod) -- PlayerModule (Lua), не API движка
			origMove = controls.moveFunction
		end
	end)
end

-- Зеркальное управление: влево ↔ вправо относительно камеры
function Controls.setMirror(on: boolean)
	if on == mirrorOn then
		return
	end
	mirrorOn = on
	if not controls or not origMove then
		return
	end
	if on then
		controls.moveFunction = function(plr, dir, relative)
			local cam = Workspace.CurrentCamera
			if cam and dir.Magnitude > 0 then
				local right = cam.CFrame.RightVector
				right = Vector3.new(right.X, 0, right.Z).Unit
				local side = dir:Dot(right)
				dir -= right * side * 2
			end
			return origMove(plr, dir, relative)
		end
	else
		controls.moveFunction = origMove
	end
end

-- Темнота: свет гаснет, фонарики у всех персонажей и ботов
local function flashlights(on: boolean)
	local heads = {}
	for _, p in Players:GetPlayers() do
		local h = p.Character and p.Character:FindFirstChild("Head")
		if h then
			table.insert(heads, h)
		end
	end
	local pass = Workspace:FindFirstChild("Passengers")
	if pass then
		for _, m in pass:GetChildren() do
			local h = m:FindFirstChild("Head")
			if h then
				table.insert(heads, h)
			end
		end
	end
	for _, h in heads do
		local l = h:FindFirstChild("Flashlight")
		if on and not l then
			Make("SpotLight", {
				Name = "Flashlight",
				Face = Enum.NormalId.Front,
				Angle = 50,
				Range = 22,
				Brightness = 4,
				Color = Color3.fromRGB(255, 240, 200),
				Parent = h,
			})
		elseif not on and l then
			l:Destroy()
		end
	end
end

function Controls.setDark(on: boolean)
	if on == dark then
		if on then
			flashlights(true)
		end
		return
	end
	dark = on
	if on then
		saved = {
			b = Lighting.Brightness,
			a = Lighting.Ambient,
			o = Lighting.OutdoorAmbient,
			c = Lighting.ClockTime,
		}
		Lighting.Brightness = 0
		Lighting.Ambient = Color3.fromRGB(8, 8, 14)
		Lighting.OutdoorAmbient = Color3.fromRGB(8, 8, 14)
		Lighting.ClockTime = 0
	elseif saved then
		Lighting.Brightness = saved.b
		Lighting.Ambient = saved.a
		Lighting.OutdoorAmbient = saved.o
		Lighting.ClockTime = saved.c
	end
	flashlights(on)
end

function Controls.shake(secs: number)
	shake = math.max(shake, secs)
end

function Controls.flicker()
	flickerT = 1.2
end

local function bounce()
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ch }
	local hit = Workspace:Raycast(root.CFrame.Position, Vector3.new(0, -3.6, 0), params)
	local part = hit and hit.Instance
	local b = part and part:GetAttribute("Bounce")
	if type(b) == "number" then
		local v = root.AssemblyLinearVelocity
		if v.Y < 5 then
			root.AssemblyLinearVelocity = Vector3.new(v.X, b, v.Z)
		end
	end
end

function Controls.update(dt: number)
	clock += dt
	if Workspace:GetAttribute("FloorId") ~= nil then
		Controls.setMirror(Workspace:GetAttribute("FloorMirror") == true)
		Controls.setDark(Workspace:GetAttribute("FloorDark") == true)
	end
	bounce()
	local cam = Workspace.CurrentCamera
	if cam then
		if shake > 0 then
			shake -= dt
			local a = math.min(1, shake) * 0.35
			cam.CFrame = cam.CFrame * CFrame.new(math.sin(clock * 47) * a, math.sin(clock * 53) * a, 0)
		end
		if Workspace:GetAttribute("FloorFlipped") == true then
			cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.sin(clock * 0.8) * 0.12)
		end
	end
	if flickerT > 0 then
		flickerT -= dt
		Lighting.Brightness = if math.floor(clock * 12) % 2 == 0 then 0.2 else 2
		if flickerT <= 0 then
			Lighting.Brightness = if dark then 0 else 2
		end
	end
end

return Controls
