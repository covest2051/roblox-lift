# Новый этаж за одну сессию (еженедельное обновление)

Этаж — один модуль `src/shared/floors/<id>.luau` с одинаковым интерфейсом. Сервер, клиент, подбор, коллекция, тесты и картинка подхватывают его сами — нужно только вписать id в два места и добавить тексты.

## Шаги (≈ 1–2 часа)
1. **Идея в одну строку**: категория (🔥 выживание · 🏁 гонка · 🧠 смекалка · 🤝 вместе · 😌 спокойный), что делают игроки, когда «прошёл», по чему место. Насилия нет: «выбыл» = улетел на балкон.
2. **Скопируй шаблон** ниже в `src/shared/floors/<id>.luau`.
3. **Впиши id** в `Floors.Order` (`src/shared/Floors.luau`) — перед боссами. Редкий этаж — поле `rare = 0.045` (сюрприз-остановка).
4. **Тексты** в `src/shared/Strings.luau`, RU и EN: `floor.<id>` (название), `rule.<id>` (правило одной фразой), `board.<id>` (строка табло) или свой разбор в `Hud.boardText`, если табло показывает числа из `inst.pub`. Новая причина выбывания — `out.<reason>`.
5. **Голова бота** (`def.bot`) — сразу вместе с правилами. Уровни отличаются только реакцией и ошибками (`Bots.Levels`); «наугад» (`mem.random`) выбирает цель наугад, но ходит как человек. Используй `Kit.choose(mem, лучший, все)` — ошибки и «наугад» получаются сами.
6. **Подбери числа** локальным скриптом (ниже): порядок «ничего < наугад < новичок < средний», для 🔥 — 4 средних проходят 50–85%, никто не выбывает в первые 3 с, длительность ≤ 60 с, работает при 1 и 12.
7. `./scripts/check.sh` целиком → коммит. Числа из строки `floor <id> …` — в таблицу README.
8. **Studio**: DBG → «◀▶ этаж» → твой → «▶ floor», пройди руками; пункт в `docs/PLAYTEST.md`.

## Шаблон
```lua
--[[
	🔥 Название. Что происходит. Когда «прошёл». Место — по чему.
]]

local Kit = require(script.Parent.Parent.FloorKit)
local Config = require(script.Parent.Parent.Config)

local def = {
	id = "myfloor",
	cat = "fire", -- fire | race | brain | coop | calm | boss | secret
	icon = "🧪",
	duration = 45, -- 30–60
	minPlayers = 1,
	-- rare = 0.045,   -- редкий: только сюрприз-остановкой
	-- ranked = false, -- без топ-3 (все равны)
	-- respawn = true, -- гонка: упал — на чекпоинт (падение считается), не на балкон
	-- freeze = true,  -- гонка: первые 3 с все стоят («на старт»)
}

local P = { Speed = 10 } -- все числа этажа — здесь
def.P = P

function def.build(inst)
	local rng = inst.rng -- только он: детерминизм для тестов
	inst.bounds = { -30, 30, 2, 64 } -- края для тел ботов (стены)
	-- inst.gravity = 196.2; inst.speedMul = 0.5; inst.dark = true; inst.mirror = true
	Kit.solid(inst, { name = "Floor", x = 0, y = -0.5, z = 33, sx = 60, sy = 1, sz = 62, color = { 200, 200, 210 } })
	Kit.part(inst, { name = "Deco", shape = "Ball", x = 0, y = 4, z = 40, sx = 4, color = { 255, 120, 90 }, mat = "Neon", collide = false })
	Kit.spawnRow(inst, 6, 0, 20) -- все у двери лифта
	Kit.pub(inst, { score = 0 }) -- то, что увидит клиент (табло)
end

function def.step(inst, dt)
	local t = inst.t -- секунды от начала этажа (сервер — GetServerTimeNow, не task.delay)
	if t < 3 then
		return -- первые 3 с — название и правило, опасностей нет
	end
	for _, p in inst.list do
		if not p.out and false --[[ условие ]] then
			Kit.out(inst, p, "fall") -- улетел на балкон (причина → out.<reason>)
		end
	end
	-- Kit.set(inst, "Deco", { x = ..., color = ... }) — двигать/красить детали
end

-- намерение игрока (кнопка действия): всегда проверять расстояние и время
function def.input(inst, p, a)
	if a.t ~= "press" or not Kit.near(p, 0, 40, Config.Floor.ActRange) then
		return false, "far"
	end
	p.contrib += 1
	return true, nil
end

-- def.done(inst) → true — закончить раньше; def.passed(inst, p); def.score(inst, p)

function def.bot(view, mem)
	local me = view.me
	-- view.pub, view.list, view.parts + то, что положил def.view (только видимое игроку)
	return Kit.go(0, 40, 1, { stop = 2 }) -- { tx, tz, speed, jump, jumpNear, edgeJump, act, track }
end

function def.view(inst, _p, v)
	v.inst = inst -- или только нужные поля
end

return def
```

## Скрипт подбора (`tests/_tune.luau`, локальный, не в репозитории)
```lua
-- lune run tests/_tune.luau <floor> [runs]
local process = require("@lune/process")
local Loader = require("./lib/Loader")
local FloorSim = require("./lib/FloorSim").make(Loader.shared)
local id, runs = process.args[1], tonumber(process.args[2]) or 100
local levels = { "idle", "random", "novice", "medium" }
local sum, pass = {}, {}
for s = 1, runs do
	local _, _, info = FloorSim.run(id, { levels = levels, seed = s })
	for i, lv in levels do
		sum[lv] = (sum[lv] or 0) + info.metric[i]
		pass[lv] = (pass[lv] or 0) + (info.byId[i].passed and 1 or 0)
	end
end
for _, lv in levels do
	print(string.format("%-7s metric %.2f pass %3.0f%%", lv, sum[lv] / runs, pass[lv] / runs * 100))
end
```
Для разбора одного бота — `onStep = function(inst, mems) … end` в `FloorSim.run`, печатай позицию, опору (`p.on.name`) и намерение (`mems[i].intent`).

## Подводные камни (нашли на прошлых этажах)
- Тело бота знает только опору сверху: стены — это `inst.bounds`; деталь без `solid` — декор.
- Прыжок бота: `edgeJump` (у края) или `jumpNear` (рядом с целью); досягаемость — `Kit.reach(dh, g)` и `Kit.gap(cur, me, s)`.
- Бот «передумывает» раз в `mem.think` с: в прыжке сохраняй прежнее намерение (`return mem.intent`), иначе он повернёт назад.
- Цель, которая двигается (пингвин, пузырь) — `track = function(p) return x, z end` — уточняется каждый шаг.
- Люди в игре двигаются физикой Roblox: правила — по позиции (сервер присылает ноги), а не по скорости из ввода. Батуты людей подбрасывает клиент по атрибуту `Bounce`.
- Ответ, который нельзя знать заранее (правда/ложь), не клади в `inst.pub` до раскрытия — тест анти-чита проверит.
