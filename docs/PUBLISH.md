# Публикация и монетизация «Лифта-сюрприза»

Общий путь «код → Studio → публикация → открыть для всех» тот же, что в `roblox/docs/PUBLISH.md` (аккаунт старше 2 дней, проверка возраста, анкета Maturity & Compliance, Manage Audience). Здесь — только то, что отличается.

> Меню Creator Hub часто переименовывают — ищи по смыслу. Официально: [Passes](https://create.roblox.com/docs/production/monetization/game-passes), [Developer products](https://create.roblox.com/docs/production/monetization/developer-products), [Badges](https://create.roblox.com/docs/production/publishing/badges), [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService).

## 1. Первая публикация (приватно)
1. `rojo build -o game.rbxl`, открой в Studio, **File → Publish to Roblox** → новая игра.
2. Creator Hub → игра → **Places** → стартовое место → **Server size: 12** (все едут в одном лифте; при 12 этажи всё ещё проходятся — проверено тестами).
3. Studio: **Game Settings → Security → Enable Studio Access to API Services** (иначе профиль не сохраняется — WARN самотеста).
4. **Game Settings → Avatar**: R15. **World**: прыжок JumpPower 50 (так в `default.project.json`).

## 2. Товары и бейджи: создать и вписать ID
### Геймпассы
| Ключ `Config.Passes` | Название | Цена | Иконка |
|---|---|---|---|
| `Emotes` | Emotes+ / Эмоции+ | 79 R$ | шесть смайликов вокруг кнопки лифта |
| `DoubleCoins` | ×2 Coins / ×2 Монеты | 149 R$ | две монеты в кабине |
| `Vip` | VIP | 249 R$ | золотая кнопка лифта со звездой |

### Developer Products
| Ключ `Config.Products` | Название | Цена |
|---|---|---|
| `Coins500` | 500 coins | 25 R$ |
| `Coins3000` | 3000 coins | 99 R$ |
| `Basement` | Basement now! / Подвал сейчас! | 29 R$ |
| `Chest` | Style Capsule / Капсула облика | 35 R$ |
| `DirectRare` / `DirectEpic` / `DirectLegendary` | Rare / Epic / Legendary item | 49 / 99 / 199 R$ |

### Бейджи (Creator Hub → Badges)
| Ключ `Config.Badges` | Название | Когда |
|---|---|---|
| `Roof` | Reached the roof / Доехал до крыши | доехал до крыши |
| `Basement` | Found the basement / Нашёл подвал | первый раз сыграл Подвал |

Вписать ID — `src/shared/Config.luau` (`Passes`, `Products`, `Badges`). Пока ID = 0: в Studio покупки эмулируются, в живой игре — «скоро»; бейджи не выдаются. Самотест перечисляет всё, что без ID.

## 3. Почему это не «плати, чтобы победить»
Ни одна покупка не меняет исход этажа: правила, боты и время одинаковые. Платное — облик (видят все), реакции, монеты, VIP (голос ×2 при выборе **категории** этажа, а не победа) и «Подвал сейчас!» — **для всего сервера**, с объявлением, раз за поездку. Нет «вернуться на этаж за робуксы»: выбывшие ждут следующей остановки.

**«Подвал сейчас!»** — сервер сам проверяет, можно ли (не было в этой поездке, есть ещё обычная остановка); если нельзя — промпт не открывается. Пока в кабине открыт промпт, отсчёт кабины продлевается **один раз за поездку** (12 с). Если за время оплаты Подвал вызвал кто-то другой — покупатель получает 300 монет. Проверь в живом клиенте: открыть промпт в кабине, подождать, оплатить — следующий этаж Подвал, у всех баннер.

## 4. Капсула и правила о случайных наградах
Уже в коде: шанс каждого предмета на экране до покупки (Common 60 / Rare 28 / Epic 10 / Legendary 2, сумма ровно 100%); дубликат → монеты; `PolicyService:GetPolicyInfoForPlayerAsync` — при `ArePaidRandomItemsRestricted` **или ошибке** капсула скрыта и сервер отказывается открыть промпт; любой предмет можно купить напрямую. В анкете **Maturity & Compliance** отметь платные случайные предметы; насилия нет (балкон, конфетти) — ожидается Minimal.

## 5. Robux и Беларусь
DevEx недоступен, Robux копятся. Тратить на рекламу (Ads Manager) в первые недели. Ролик 10 с без слов: «кабина, три кнопки «🔥 ? 🧠 ? 🤝 ?» → двери → лава поднимается, игрок прыгает → кто-то кувырком улетает на мягкий балкон → табло «1̶3»». Для съёмки: DBG → этаж, автопилот, скорость.

## 6. Страница игры
**Название:** `Surprise Lift: Floor Party` (EN), `Лифт-сюрприз: вечеринка этажей` (RU — через Localization).

**Описание (EN):**
> Everyone on the server rides one lift. Every stop the doors open on a surprise: the floor is lava, melting tiles, giant bowling balls, true or false, a strict librarian, musical chairs, a dark floor with switches, a runaway-penguin zoo… Vote for the next floor's category, survive, earn stars and climb to the roof — then the lift falls back down and the party starts again. Bosses on floors 5 and 10. Somewhere there is a secret Basement 13. Out? You fly onto the soft balcony and cheer until the next stop. 1–12 players, bot passengers fill the cabin. No violence.

**Описание (RU):**
> Весь сервер едет в одном лифте. На каждой остановке двери открываются на сюрприз: пол — лава, тающая плитка, гигантский боулинг, правда или ложь, строгая библиотекарша, музыкальные стулья, тёмный этаж с рубильниками, сбежавшие пингвины… Голосуй за категорию следующего этажа, выживай, собирай звёзды и доберись до крыши — а потом лифт падает обратно, и всё сначала. Боссы на 5-м и 10-м. Где-то есть секретный Подвал 13. Выбыл? Улетаешь на мягкий балкон и болеешь до следующей остановки. 1–12 игроков, пустые места занимают боты-пассажиры. Без насилия.

**Жанр:** Party & Casual. **Иконка 512×512:** бирюзовая кабина с открытыми дверями, из которых выглядывает лава и пингвин, над дверью табло «1̶3». **Скриншоты:** голосование «🔥 ? 🧠 ? 🤝 ?»; полёт на балкон; лава; тёмный этаж с фонариками; крыша с итогами; коллекция 19 этажей.

## 7. Перед открытием для всех
- [ ] Все ID вписаны, самотест без FAIL и без WARN о товарах.
- [ ] Каждая покупка проверена в живом клиенте тестовым аккаунтом: Robux списываются, товар один раз.
- [ ] Перезаход: монеты, звёзды, коллекция, облик на месте; бейдж «Доехал до крыши» выдаётся.
- [ ] Server size = 12, прогнана поездка на 6+ игроков. Проверено на телефоне.
