# Локальная сессия Claude Code + Studio MCP

Подготовка Studio MCP — как в `roblox/docs/LOCAL_SESSION.md` (Assistant → Manage MCP Servers → Enable Studio as MCP server, Quick connect → Claude Code). Сначала пройди [`PLAYTEST.md`](PLAYTEST.md) руками — это не тратит лимиты. Найденное (текст Output, описание) дешевле присылать в облачную сессию.

## Промпт для старта (скопируй целиком)

```
Проект — Roblox-игра «Лифт-сюрприз», Rojo-проект в этом репозитории.
Studio открыта и синхронизирована через `rojo serve`, Studio MCP подключён.

Правила экономии:
- Не читай весь репозиторий: структура — в README.md, механики — в docs/DESIGN.md,
  как устроен этаж — docs/NEW_FLOOR.md.
- Правь ТОЛЬКО src/**, Rojo синхронизирует сам. Не правь скрипты в Studio напрямую.
- screen_capture — только если я прошу или баг без картинки не понять.
- После каждой правки логики: `lune run tests/run.luau` (этажи — `lune run tests/run.luau floor`).

Задача:
1. start_stop_play (Play), подожди ~8 с, get_console_output.
2. Найди строки [SELFTEST] и красные ошибки, пришли короткую сводку.
3. Исправляй ошибки по одной: правка → стоп/Play → Output.
4. Состояние лифта — командой-атрибутом (datamodel Server; require из Command Bar даёт
   отдельную копию модулей):
     workspace:SetAttribute("DebugCommand", "state")
   В Output: `[Debug] ride 1 phase=lobby stop=0/10 …`.
5. Пройди этажи командами (по одной, после каждой — get_console_output):
     workspace:SetAttribute("DebugCommand", "floor lava")   -- следующий этаж — лава
     workspace:SetAttribute("DebugCommand", "next")         -- следующая фаза
     workspace:SetAttribute("DebugCommand", "auto")         -- автопилот головой бота
     workspace:SetAttribute("DebugCommand", "speed 4")
     workspace:SetAttribute("DebugCommand", "boss")
     workspace:SetAttribute("DebugCommand", "basement")
     workspace:SetAttribute("DebugCommand", "bots 6")
   На 2–3 этажах сделай screen_capture: видно ли табло сверху, кнопки справа снизу,
   этаж из деталей, ботов-пассажиров с именами?
6. Коммить исправления с понятными сообщениями.
```

## Типичные проблемы, видимые только в движке
| Симптом | Где править |
|---|---|
| Персонаж появляется не в кабине / проваливается | `LiftService.placeHuman` (ноги = корень − (½ корня + HipHeight)), `feetOffset` |
| Этаж «в другом месте», детали повёрнуты | `World.placement` (Disc — цилиндр, повёрнутый на 90° по Z; наклон — `slope`) |
| Платформы/шары двигаются рывками | детали двигает сервер шагом 1/15 с (`Config.Ride.Step`); можно добавить сглаживание на клиенте |
| Батуты не подбрасывают | клиент: `Controls.bounce` (луч вниз 3.6, атрибут `Bounce`) |
| Лёд не скользит | `World.makePart` → `CustomPhysicalProperties` при `ice` |
| Зеркало не работает | `Controls.setMirror` (обёртка `moveFunction` из PlayerModule) |
| Темнота не наступает / фонарика нет | `Controls.setDark`, атрибут `FloorDark` (сервер выключает его в кабине) |
| Выбывший не летит на балкон | `LiftService.step` → `flying` (корень Anchored на время полёта) |
| Боты-пассажиры стоят не там | `World.moveBot` (ноги — деталь `Feet`, PrimaryPart) |
| Табло этажа пустое | клиент `Hud.boardText` по `inst.pub` этажа |
| Наложение HUD на телефоне | `Hud.layout` (узкая раскладка); тест — конец `tests/engine/client_sim.luau` |

## Звуки
Своих звуков нет (условие проекта): мелодия лифта и звонки — `Fx` (ноты «пинга»), эффекты — встроенные `rbxasset://sounds/*`. Если позже захочется настоящих — только свои или Roblox-автора, в `Config.Sounds`.
