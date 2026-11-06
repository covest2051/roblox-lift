--[[
	Rewards — множитель монет: ×2 Монеты и VIP (+10%). Звёзды за этаж считает Floors.results,
	монеты за этаж (звёзды × 5 × множитель) и бонус за поездку — Ride.
]]

local Shared = script.Parent
local Config = require(Shared.Config)

local Rewards = {}

function Rewards.multiplier(double: boolean, vip: boolean): number
	local R = Config.Rewards
	local m = 1
	if double then
		m *= R.DoubleCoins
	end
	if vip then
		m *= 1 + R.VipBonus
	end
	return m
end

function Rewards.apply(base: number, mult: number): number
	return math.floor(base * mult + 1e-9)
end

return Rewards
