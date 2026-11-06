--[[
	StageView — надписи в мире на языке игрока: таблички деталей с атрибутом Key (вывески,
	«ПРАВДА/ЛОЖЬ», «ВОЛЬЕР»), табло этажа (Key = "board" — текст табло из Hud), имена ботов
	над головой. Раз в полсекунды, без task.delay.
]]

local Workspace = game:GetService("Workspace")

local Lang = require(script.Parent.Lang)
local Hud = require(script.Parent.Hud)

local StageView = {}

local acc = 0

local function localize(container: Instance?)
	if not container then
		return
	end
	for _, d in container:GetDescendants() do
		if d:IsA("TextLabel") then
			local key = d:GetAttribute("Key")
			if type(key) == "string" then
				local text
				if key == "board" then
					local v = Hud.info.v
					text = Hud.boardText(v and v.floor, Hud.info.pub)
				else
					text = Lang.t(key)
				end
				local prefix = d:GetAttribute("Prefix")
				d.Text = (if type(prefix) == "string" then prefix else "") .. text
			end
		end
	end
end

function StageView.refresh()
	localize(Workspace:FindFirstChild("Stage"))
	localize(Workspace:FindFirstChild("Passengers"))
	localize(Workspace:FindFirstChild("Lift"))
end

function StageView.update(dt: number)
	acc += dt
	if acc >= 0.5 then
		acc = 0
		StageView.refresh()
	end
end

return StageView
