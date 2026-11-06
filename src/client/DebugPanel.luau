--[[
	DebugPanel — кнопка DBG слева, только в Studio. Команды те же, что у
	workspace:SetAttribute("DebugCommand", …): floor <id> (перебор ◀▶), next, boss, basement,
	bots <n>, speed <x>, state, auto (автопилот головой бота), монеты, сброс, самотест, язык.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Floors = require(Shared.Floors)

local Ui = require(script.Parent.Ui)
local Lang = require(script.Parent.Lang)

local DebugPanel = {}

function DebugPanel.build()
	if not RunService:IsStudio() then
		return
	end
	local root = Ui.screen()
	local toggle = Ui.button({
		Name = "DebugToggle",
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(56, 30),
		TextSize = 14,
		BackgroundColor3 = Color3.fromRGB(90, 40, 90),
		Text = "DBG",
		Parent = root,
	})
	local panel = Ui.panel({
		Name = "Debug",
		Position = UDim2.new(0, 74, 0.45, -180),
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Ui.Make(
		"UIListLayout",
		{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel }
	)
	Ui.Make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = panel,
	})
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	local n = 0
	local function cmd(text: string, c: string, arg: any?)
		n += 1
		local b = Ui.button({
			Name = "Cmd_" .. c .. tostring(arg or ""),
			LayoutOrder = n,
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 14,
			ZIndex = 20,
			Text = text,
			Parent = panel,
		})
		b.Activated:Connect(function()
			Net.ClientAction:FireServer({ t = "debug", cmd = c, arg = arg })
		end)
		return b
	end
	-- этаж: перебор и «поехали»
	local pick = 1
	n += 1
	local pickB = Ui.button({
		Name = "FloorPick",
		LayoutOrder = n,
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 14,
		ZIndex = 20,
		Text = "",
		Parent = panel,
	})
	local function show()
		local id = Floors.Order[pick]
		pickB.Text = "◀▶ " .. Floors.get(id).icon .. " " .. id
	end
	show()
	pickB.Activated:Connect(function()
		pick = pick % #Floors.Order + 1
		show()
	end)
	n += 1
	local go = Ui.button({
		Name = "FloorGo",
		LayoutOrder = n,
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 14,
		ZIndex = 20,
		Text = "▶ floor",
		Parent = panel,
	})
	go.Activated:Connect(function()
		Net.ClientAction:FireServer({ t = "debug", cmd = "floor", arg = Floors.Order[pick] })
	end)
	cmd("Next phase", "next")
	cmd("Boss now", "boss")
	cmd("Basement now", "basement")
	cmd("Autopilot (bot head)", "auto")
	cmd("Speed ×4", "speed", 4)
	cmd("Speed ×1", "speed", 1)
	cmd("Bots 0", "bots", 0)
	cmd("Bots 3", "bots", 3)
	cmd("Bots 11", "bots", 11)
	cmd("Bots auto", "bots", "auto")
	cmd("State → Output", "state")
	cmd("+1000 coins", "coins", 1000)
	cmd("Reset profile", "reset")
	cmd("Self-test", "selftest")
	n += 1
	local lang = Ui.button({
		Name = "Lang",
		LayoutOrder = n,
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 14,
		ZIndex = 20,
		Text = "RU / EN",
		Parent = panel,
	})
	lang.Activated:Connect(Lang.toggle)
end

return DebugPanel
