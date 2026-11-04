# Архитектура

Описывает целевую архитектуру. Разделы с пометкой **(план)** ещё не реализованы.

## Расположение в проекте и в DataModel

| Папка | В Roblox | Что внутри |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Config, Domain, общие типы. Видно клиенту: ничего секретного |
| `src/server` | `ServerScriptService.Server` | Сервисы, точка входа сервера, серверная часть Zap |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Контроллеры, UI (Vide), точка входа клиента, клиентская часть Zap |
| `Packages` | `ReplicatedStorage.Packages` | Общие пакеты Wally (Vide) |
| `ServerPackages` | `ServerStorage.ServerPackages` | Серверные пакеты Wally (ProfileStore) |
| `net/remotes.zap` | — | Контракт сети; генерирует `src/*/Net/Remotes.luau` |
| `assets` **(план)** | `ReplicatedStorage.Assets` | Модели `.rbxm` |
| `lune` | — | Скрипты задач: install, check, test, format, net |
| `tests` | — | Тесты доменной логики для Lune |

Настройки Workspace задаются в `default.project.json`: `StreamingEnabled = true` (выключить нельзя: Server Authority держит его включённым), `StreamingMinRadius = 1024`, `StreamingTargetRadius = 2048` (радиус больше карты, чтобы мир из тысячи частей приходил целиком, а не кусками; решение 032), `SignalBehavior = Deferred`, `AuthorityMode = Server`, `FallenPartsDestroyHeight = -5000`. Свойства Workspace плагин Rojo в открытый плейс не записывает — в новом плейсе их один раз выставляют вручную (Workspace → Properties): `AuthorityMode = Server` (связанные свойства, в том числе `StreamingEnabled`, включаются сами и больше не выключаются), `StreamingMinRadius = 1024`, `StreamingTargetRadius = 2048`.

## Слои

```
Config       данные: зоны, стражи, существа, редкости, цены, тайминги.
             Числа — чистый Luau (читаются в Lune: тесты, калькулятор);
             внешний вид с Color3/Vector3/Enum — отдельно, в *Looks
   ↓
Domain       чистая логика без Roblox API: BigNum, вес яйца, мозг стража, вылупление,
             скрещивание, отсек, офлайн-прогресс, миграции профиля
   ↓
Services     сервер: связывает Domain с Roblox (данные, физика, мир, сеть)
Controllers  клиент: ввод (Input Action System), камера, UI, эффекты
   ↓
Net          сгенерированный Zap + наш слой команд и репликации
```

Зависимости идут только вниз по схеме. `Domain` не импортирует ничего из Roblox, поэтому тестируется в Lune.

## Запуск

Один `Script` на сервере (`src/server/Main.server.luau`) и один `LocalScript` на клиенте (`src/client/Main.client.luau`). Фреймворков вроде Knit нет: точка входа создаёт сервисы, явно передаёт им зависимости и отдаёт список в `Lifecycle.run` (`src/shared/Runtime/Lifecycle.luau`).

Сервис — таблица `{ name, init?, start?, ...API }`, создаётся функцией `new(...)`. Две фазы:
1. **`init`** — у всех сервисов по порядку. Связать зависимости, создать объекты. Синхронно: `Lifecycle` падает с ошибкой, если `init` ждёт.
2. **`start`** — у всех сервисов, каждый в своём потоке. Подключить события и начать работу.

Игроки обрабатываются через `PlayerEvents.observe` (`src/server/Runtime`): обработчик одинаково вызывается для уже подключённых и для новых игроков.

## Данные игрока

```
DataService (связь с Roblox: игроки, сообщения при ошибке)
  └─ SessionManager (чистый Luau: жизненный цикл сессии, тестируется в Lune)
       ├─ ProfilePort ── ProfileStoreAdapter ── ProfileStore
       └─ loadData ───── PlayerData.load (миграции, дополнение полей, проверка — на копии)
```

- **Жизненный цикл:** `Loading → Active → Closing → Closed`, а также `Failed` (не загрузилось, данные новее сервера, данные повреждены) `Closed (SessionLost)` (профиль открыли на другом сервере) и `Closed (ServerShutdown)` (сервер выключается, ProfileStore сам сохраняет и закрывает сессии; игрока никуда не отправляем — сообщение покажет Roblox).
- **Только `Active` принимает изменения:** `DataService.update(player, mutator)`. Мутатор не должен ждать — `SessionManager` падает с ошибкой, если он уступит поток. Сначала все проверки, потом запись.
- **Загрузка на копии.** `PlayerData.load` мигрирует, дополняет и проверяет копию. Оригинал в `Profile.Data` не трогается, пока всё не прошло; при неудаче профиль закрывается с исходными данными.
- **Не загрузилось — не играем.** Игрок получает сообщение на своём языке (`data.*.message`) и выходит.
- **Схема:** `src/shared/Domain/PlayerData.luau` — `SCHEMA_VERSION`, `MIGRATIONS`, `template(defaults)`. Деньги и ⚡ хранятся как `BigNum` — его форма совпадает с форматом сохранения. Стартовые значения из конфигов (`Defaults`: ⚡ новичка, число капсул) передаёт `DataService`: домен конфигов не читает.
- **Прокачка в профиле** (v3): `trained` (очки с тренажёра), `trainerLevel`, `jetpackLevel`. Показываемая ⚡ = `Upgrades.speed(trained, jetpackLevel)`; её публикует `SpeedService`. Миграция v2 → v3 переносит старое `speed` в `trained`.
- **Игровое время** (v4): `playSeconds` копит `OfflineService` раз в секунду вместе с меткой `lastSeenAt`; по нему работает защита новичков (`Domain/Pvp`).
- **Отсек в профиле** (v2): `pods` (капсулы, в каждой пришелец или пусто), `inventory`, `floor` (вылупившиеся без места), `incubator` (яйца с unix-временем вылупления), `nextUid` (счётчик адресов пришельцев и яиц), `lastSeenAt` (метка для офлайн-дохода и офлайн-тренировки). Операции над отсеком — чистые функции `Domain/Bay`, вызываются внутри `DataService.update`.
- В Studio каждое изменение состояния сессии печатается в Output (`[DataService] User …: Active`).
- Чистые серверные модули (например, `SessionManager`) не делают `require` модулей из `ReplicatedStorage`: строковый `require` между `ServerScriptService` и `ReplicatedStorage` в Roblox не работает. Всё нужное им передаётся параметрами — заодно это делает их тестируемыми.

## Сеть

- `net/remotes.zap` — единственный контракт. После правки: `lune run net`. Строки — `string.utf8`; `BigNum` на проводе — та же пара мантисса/порядок, что в сохранении.
- **Данные игрока на клиент** (`NetService` → `ProfileState` на клиенте): `ProfileSnapshot` при активации профиля и по запросу `RequestSnapshot` (клиент просит, когда его контроллеры готовы), затем дельты по разделам: `CoinsChanged` (раз в секунду, когда доход не нулевой), `BayChanged` (отсек целиком после перестройки — он маленький, а разделение на «добавлен X» не стоило бы своей сложности), `OfflineReward`, `Hatched`, `Crossbred`, `UpgradesChanged`, `Trained`, `NoticeSent`; вместе с отсеком всегда уходят и монеты (почти каждое изменение отсека их меняет, а тик дохода шлёт их только пока что-то зарабатывает). Клиент держит копию в источниках Vide и не пишет в неё.
- **Команды** (`AutoPlace`, `MoveToPod`, `MoveToInventory`, `Crossbreed`, `Sell`, `BuyPod`, `UpgradeJetpack`): `NetService.guarded` — лимит частоты на игрока (`Domain/RateLimit`, `NetConfig`) → активный профиль → `EconomyService`, который проверяет смысл запроса на живом профиле, применяет одно изменение через `DataService.update` и перестраивает отсек. Отказ уходит клиенту как `NoticeSent` с причиной.
- Ввод, влияющий на симуляцию (полёт, захват), идёт через Input Action System, а не через remotes.

## Движение и Server Authority

Включено: `Workspace.AuthorityMode = Server` (решение 019). Сервер считает движение, клиент его предсказывает и откатывается при расхождении. Подделка позиции или скорости на клиенте откатывается движком.

```
Клиент                                   Сервер
AimController ─ направление камеры ─┐
стандартное управление (MoveDirection)├─> InputActions под Player ─> SpaceSimulation
Space/Ctrl, кнопки ▲▼ на телефоне ───┘                              (тот же модуль)
SpaceSimulation (предсказание) ─> атрибуты персонажа ─> HUD (Vide)
```

- **`SpaceSimulation`** (`src/shared/Simulation`) привязан через `RunService:BindToSimulation` на сервере и на клиенте. Над платформой (в пределах её радиуса, под куполом) — обычная ходьба; в остальном пространстве — полёт. Так при подлёте джетпак работает, пока игрок не окажется над полом, а при сходе с края включается сразу за ободом на `LinearVelocity` + `AlignOrientation` туда, куда смотрит камера; кислород убывает в космосе и восстанавливается под куполом.
- **Математика** — в `Domain/Flight`, `Domain/Oxygen`, `Domain/Zones`, покрыта тестами.
- **Ввод** (`src/shared/Input/FlightInputs`): контекст `FlightContext` под каждым `Player` (создаёт сервер). `Ascend`/`Descend` — клавиши и кнопки на телефоне (`UIButton`-привязки создаёт клиент локально), `Aim` — `Scriptable`-привязка, её каждый кадр заполняет `AimController`. Сервер не доверяет `Aim`: `Flight.sanitizeAim`.
- **Объекты создаются вне симуляции:** `SpaceService` выдаёт контекст ввода игроку и ограничители персонажу, убивает при пустом баллоне (в `PostSimulation`).
- **Состояние симуляции — в атрибутах персонажа:** `InSpace`, `Oxygen`. HUD читает их на клиенте — значения предсказанные, поэтому без задержки.

Правила кода в симуляции — в [CONVENTIONS.md](CONVENTIONS.md), раздел 5.

## Мир

`WorldService` строит мир при старте сервера, всё из кода: платформа станции со светящимся ободом, купол-пузырь на платформе и ступенчатый корпус под ней, точка появления, поле астероидов по зерну (`WorldConfig.SEED`, одинаковое на всех серверах), освещение космоса. Позже детали заменятся моделями из `assets/`.

**Отсеки.** `BayService` даёт каждому игроку отсек на кольце платформы (`BayLooks`, `BayModel`), когда его профиль активен, и освобождает при выходе. Содержимое — капсулы, пришельцы, яйца в инкубаторе, пришельцы на полу — строится из профиля и **перестраивается целиком** после каждого изменения (`refresh`): данных мало, зато мир не может разойтись с профилем. Клиент (`BayViewController`) вешает таблички по тегам `Bay`, `Alien`, `IncubatorEgg`; таймер яйца считает по `workspace:GetServerTimeNow()` против атрибута `HatchAt`.

Раз в секунду (общий планировщик) отсек делает один `DataService.update`: вылупляет готовые яйца (`Bay.takeHatched` → `Hatch.pick` по удаче яйца → `Bay.addHatched`) и начисляет доход капсул за прошедшее время. Метку `lastSeenAt` раз в секунду двигает `OfflineService`; он же при активации профиля одним обновлением платит за время отсутствия: доход капсул (потолок 4 ч) и тренировку (50 %, потолок 8 ч), затем шлёт `OfflineReward` для экрана «С возвращением!». Доставка: `CarryService` на платформе отдаёт яйцо в `BayService.addEgg` с грейдом гнезда (`NestService.getGrade`: гнёзда ранжированы по расстоянию, `Domain/Posts`); стражи берут пост оттуда же. Подбор пришельца с пола — `ProximityPrompt` только для хозяина; сервер проверяет владельца, дистанцию и место в инвентаре.

**Тренажёр.** У каждого отсека сбоку, на полу станции у капсул, очерчена зона (`BayConfig.TRAINER_PAD` в координатах отсека, часть `Trainer` в модели отсека). `TrainingService` раз в секунду проверяет, стоит ли хозяин на своей площадке (`Domain/Trainer.isOnPad` в системе координат отсека, не в полёте), и одним `update` прибавляет `trained` на `Upgrades.trainerRate(level) × dt`; затем `SpeedService.publish` обновляет атрибуты ⚡, а событие `Trained` даёт клиенту всплывающую цифру (`TrainingViewController`). Улучшение тренажёра — кнопка на табличке над зоной (видна только хозяину) → команда `UpgradeTrainer` через калитку → `EconomyService.upgradeTrainer`. Капсулы покупаются так же: табличка между рядами капсул с числом, ценой и кнопкой (`BuyPod`). Уровень тренажёра и число капсул лежат в атрибутах модели отсека (`TrainerLevel`, `PodCount`) — по ним `BayViewController` рисует таблички; цену считает сам из конфигов. Подсказки «E» (подобрать пришельца, открыть магазин) — `ProximityPrompt` со `Style = Custom`, которые `PromptViewController` рисует тем же `GrabPrompt`, что и захват яйца.

**Джетпаки.** Один магазин на станции (`ShopModel`, `ShopLooks`, тег `Shop`): подсказка на прилавке открывает окно на клиенте (`ShopController` слушает `ProximityPromptService.PromptTriggered`), тексты подсказки и вывески клиент ставит сам на своём языке. Окно (`ShopWindow`) строится из копии профиля: уровни 0…n со статусами пройден / твой / купить / позже; покупка — команда `UpgradeJetpack` через калитку → `EconomyService.upgradeJetpack`. `JetpackService` держит уровень в атрибуте игрока `JetpackLevel` (по нему `JetpackEffectsController` у всех клиентов масштабирует огонь) и перекрашивает модель джетпака (`JetpackModel.applyLooks`, цвета по уровням в `JetpackLooks`); новый персонаж получает джетпак сразу своего уровня (`SpaceService` ← `getJetpackLooks`). Имена уровней — `Names.jetpack` по `UpgradeConfig.JETPACK_NAME_KEYS`.

**PvP.** Все способности — действия в `InputContext` полёта (удар ЛКМ/R2, гарпун F/Y, бомба G/B, щит R/L2, кнопки на телефоне): под Server Authority сервер видит нажатие и прицел сам. `PvpService` раз в 1/15 с ловит нажатия, проверяет перезарядку и купол, а для атак — цель и `Domain/Pvp.refusal` (купол, новички по игровому времени `playSeconds`, 10 с после респауна, щит, правило 10× по ⚡). Удар живёт в симуляции, а не в `PvpService`: `SpaceSimulation` по нажатию запускает выпад (`Abilities.stepStrike`, атрибуты персонажа `StrikeLunge`, `StrikeCooldown`, `StrikeAim` — предсказываются, так что у атакующего выпад без задержки) и проигрывает анимацию удара. `PvpService` каждый кадр после симуляции (`PostSimulation`) смотрит на идущие выпады: первая цель в радиусе касания перед атакующим (`Domain/Abilities.nearestInCone`) получает `Character/Knockback.apply` — те же атрибуты, что удар стража (`HitVelocity`, `HitAxis`, плюс `HitBy` — кто ударил) — и `CarryService.dropEgg`, в точке касания вспышка (`PvpEffects.strikeImpact`); выпад кончился без касания — промах. С яйцом в руках симуляция выпад не запускает. Перезарядку удара клиент читает прямо с персонажа. Анимация удара — данные `Character/StrikePose`, собираются `Character/PoseAnimation` (как полёт), загружаются вручную, ID — `PvpConfig.STRIKE_ANIMATION_ID`. Гарпун: ближайший носитель в узком конусе, яйцо летит к стрелку. Бомба: летит по прицелу, взрывается у цели или через секунду, бьёт всех в радиусе. Щит пишет на персонаж `ShieldUntil` в серверном времени: правила и клиенты читают его. Эффекты в грейбоксе делает сервер (`World/PvpEffects`). Отказ — тост через `NetService.notify`, результат — событие `AbilityResult` (с него клиент считает перезарядку в `AbilityState` для чипов HUD); `PvpService.getUsage` считает использования для решения о магазине способностей. Защита новичка видна всем: атрибут игрока `NewbieSecondsLeft`. Для одиночных проверок — бот `SpawnDummyThief`, зарегистрированный через `PvpService.addDummy`.

## Стражи (план)

- Без `Humanoid`: модель + `AnimationController`, анимации на клиенте.
- У гнезда одно яйцо в мире: `NestService` ведёт его цикл по `Domain/NestCycle` (в гнезде → унесено → растёт новое). Новое растёт только после `CarryService` → `NestService.eggDelivered`; невостребованное или брошенное яйцо возвращается через `returnEgg`.
- Конечный автомат на сервере (`GuardianBrain`): `Sleep → Chase → Return`; просыпается, когда яйцо гнезда унесли, с задержкой; с пути домой разворачивается, если яйцо взяли снова. «Дом» стража — над его яйцом: в гнезде или там, где оно выпало (`CarryService.findLooseEggs`; яйцо внутри границы станции не считается — туда стражу нельзя). Поводка и лимита времени нет: погоня кончается, только когда вор пропал или оказался внутри границы станции (сфера `StationConfig.BORDER_RADIUS` вокруг центра купола) либо в зоне станции. Сами стражи держатся за границей с запасом `GuardianConfig.BORDER_MARGIN` (`Bounds.keepOutside`). Границу в мире рисует `WorldService`: бледная сфера и кольцо из неоновых сегментов. Поведение у всех одинаковое, стражи отличаются видом и скоростью (`GuardianConfig`).
- Скорость полёта стража в погоне — по отношению ⚡ стража и вора (см. GAME_DESIGN, «Погоня»).
- Активны только рядом с игроками; тикают с пониженной частотой.

## Аналитика

`MetricsService` — единственное место, которое знает `AnalyticsService` Roblox. Остальные службы только сообщают факты своими сигналами (`CarryService.grabbed/reachedStation/delivered/lost`, `BayService.incomePaid`, `EconomyService.coinsTraded/crossbred`, `TrainingService.trained`, `OfflineService.settled`, `SpaceService.suffocated`, `PvpService.abilityUsed`), а `Main` передаёт их в `MetricsService`.

- **Воронка новичка** — `LogOnboardingFunnelStepEvent`, шаги из `Domain/Onboarding`; каждый шаг один раз на аккаунт, пройденные — битовой маской в профиле (`onboardingSteps`, схема v5).
- **Прогресс** — `LogProgressionCompleteEvent` по пути `Guardians` при первой доставке от поста дальше прежнего (`bestPost` в профиле).
- **Экономика** — `LogEconomyEvent`, валюты `Coins` и `Speed`; источники: доход пришельцев, продажа, офлайн, тренажёр (дальше — задания и подарки через `MetricsService.earned`); траты: капсула, тренажёр, джетпак.
- **Кража** — `LogFunnelStepEvent` воронки `Theft`, сессия на каждое взятое яйцо: взял → долетел до границы станции → доставил.
- **Свои события** — `LogCustomEvent`: `EggLost` (причина, зона), `GuardianCatch` (пост), `OxygenDeath` (зона), `Ability` (способность, итог), `Crossbreed` (ступень, зона).

Частые факты (доход каждую секунду, выплаты тренажёра, способности) суммируются по игроку и уходят раз в 5 минут и при выходе — так запросов меньше лимита Roblox (120 + 20 × онлайн в минуту). В полях нет имён игроков: число сочетаний значений ограничено. В Studio события не отправляются (Roblox их не принимает) — печатаются в Output с префиксом `[Metrics]`, сумма копится 30 секунд.

## UI (клиент)

- Компоненты на Vide в `src/client/UI`: без ключей локализации и без сетевых вызовов — тексты приходят готовыми, действия — колбэками. Контроллеры (`HudController`, `BayWindowController`) собирают тексты через `Text.get`, читают `ProfileState` и отправляют команды через `Remotes`.
- `Theme` — палитра и шрифт; `Layout` — `UIPadding`/`UISizeConstraint`/`UIStroke`, которых нет в типах Vide; `Button`, `StatBadge`, `WorldLabel`, `AlienCard`, `Toasts` — переиспользуемые детали.
- Маяк станции (`StationBeaconController`, компонент `StationBeacon`) — экранная метка, а не BillboardGui: каждый кадр точка над куполом проецируется камерой, `Domain/ScreenMarker` (чистый, с тестом) решает, стоять метке над куполом или у края экрана со стрелкой. Так метка видна с любого расстояния и не зависит от стриминга станции.
- Имена пришельцев и яиц собирает `Locale/Names` (чистый модуль с тестом): пришелец — «ступень · страж», пока у пришельцев нет своих имён.

## Локализация

- Все строки — в `src/shared/Locale/Strings.luau`, по ключу `область.имя.тип`, сразу на русском и английском. Множественное число — формы по `{count}`.
- Код берёт текст только через `Text.get(locale, key, args)`. Тип ключа выводится из таблицы строк, поэтому опечатка в ключе — ошибка проверки типов.
- Язык игрока: `Text.resolveLocale(player.LocaleId)` на сервере, `LocalizationService.RobloxLocaleId` на клиенте. Всё, что не русский, — английский.
- Свой модуль вместо `LocalizationTable`: строки проверяются в Lune (`lune run content`), формы множественного числа и подстановки работают одинаково везде.

## Команды

| Команда | Что делает |
|---|---|
| `lune run install` | Пакеты Wally, определения типов Roblox, код Zap, sourcemap, фикс типов пакетов |
| `lune run check` | Формат → линтер → типы игры → типы инструментов и тестов → контент → тесты → сборка |
| `lune run content` | Проверка строк локализации |
| `lune run format` | Форматирует весь код StyLua |
| `lune run test [фильтр]` | Тесты Lune |
| `lune run balance [дней]` | Калькулятор баланса: время до каждого стража по конфигам |
| `lune run net` | Перегенерирует сеть после правки `net/remotes.zap` |
| `rojo serve` | Синхронизация файлов в открытую Studio |
