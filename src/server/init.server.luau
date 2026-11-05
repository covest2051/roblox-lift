--[[
	Точка входа сервера (каркас: мир и логика появятся на этапах 2–4).
]]

local Workspace = game:GetService("Workspace")

Workspace:SetAttribute("WorldReady", true)
print("[World] ready")
