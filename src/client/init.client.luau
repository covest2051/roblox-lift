--[[
	Клиент (каркас: интерфейс появится на этапе 5).
]]

local Workspace = game:GetService("Workspace")

while not Workspace:GetAttribute("WorldReady") do
	task.wait(0.2)
end
