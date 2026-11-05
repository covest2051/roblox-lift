--[[
	Bots — уровни «головы» бота и бот-пассажиры.
	Одна голова на этаж (def.bot в floors/*) — для тестов, ботов-пассажиров в игре,
	прогонов на заглушке и автоигры в Studio. Уровни отличаются только реакцией
	(как часто бот передумывает), ошибками и неточностью направления:
	  idle    — ничего не делает;
	  random  — «наугад»: цель выбирает наугад (плитку, половину, стул), ходит как человек;
	  novice  — новичок: медленная реакция, частые ошибки;
	  medium  — средний: быстрая реакция, редкие ошибки.
]]

local Shared = script.Parent
local Rng = require(Shared.Rng)

local Bots = {}

Bots.Levels = {
	idle = { think = 1, err = 0, jitter = 0, lookErr = 0, idle = true },
	random = { think = 0.7, err = 0, jitter = 0.2, lookErr = 0.08, random = true },
	novice = { think = 0.7, err = 0.22, jitter = 0.4, lookErr = 0.11 },
	medium = { think = 0.3, err = 0.07, jitter = 0.12, lookErr = 0.04 },
}
Bots.Order = { "idle", "random", "novice", "medium" }

-- Имена бот-пассажиров (ключи Strings)
Bots.Names = {
	"bot.leva",
	"bot.granny",
	"bot.courier",
	"bot.chef",
	"bot.professor",
	"bot.tourist",
	"bot.twins",
	"bot.janitor",
}

-- Внешность бот-пассажира: цвет тела и «примета» (строит сервер)
Bots.Looks = {
	["bot.leva"] = { body = { 90, 120, 200 }, extra = "mustache" },
	["bot.granny"] = { body = { 200, 120, 170 }, extra = "cat" },
	["bot.courier"] = { body = { 255, 170, 40 }, extra = "box" },
	["bot.chef"] = { body = { 240, 240, 240 }, extra = "chefhat" },
	["bot.professor"] = { body = { 120, 90, 60 }, extra = "glasses" },
	["bot.tourist"] = { body = { 60, 190, 160 }, extra = "camera" },
	["bot.twins"] = { body = { 230, 90, 90 }, extra = "balloon" },
	["bot.janitor"] = { body = { 110, 140, 110 }, extra = "mop" },
}

function Bots.mem(level: string, seed: number)
	local L = Bots.Levels[level]
	assert(L, "unknown bot level " .. tostring(level))
	return {
		level = level,
		think = L.think,
		err = L.err,
		jitter = L.jitter,
		lookErr = L.lookErr,
		random = L.random == true,
		idle = L.idle == true,
		rng = Rng.new(seed),
		next = 0,
		intent = {},
		aim = 0,
	}
end

return Bots
