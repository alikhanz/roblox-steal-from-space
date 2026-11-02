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

Настройки Workspace задаются в `default.project.json`: `StreamingEnabled = true`, `SignalBehavior = Deferred`.

## Слои

```
Config       данные: зоны, стражи, существа, редкости, цены, тайминги
   ↓
Domain       чистая логика без Roblox API: дроп, мутации, экономика, BigNum,
             вес яйца, тревога, офлайн-прогресс, миграции профиля
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
- **Схема:** `src/shared/Domain/PlayerData.luau` — `SCHEMA_VERSION`, `MIGRATIONS`, `template()`. Деньги хранятся как `BigNum` — его форма совпадает с форматом сохранения.
- В Studio каждое изменение состояния сессии печатается в Output (`[DataService] User …: Active`).
- Чистые серверные модули (например, `SessionManager`) не делают `require` модулей из `ReplicatedStorage`: строковый `require` между `ServerScriptService` и `ReplicatedStorage` в Roblox не работает. Всё нужное им передаётся параметрами — заодно это делает их тестируемыми.

**(план)** Команды (Zap) → лимит частоты → проверка → `DataService.update`; клиент получает снимок данных при входе и дельты после изменений.

## Сеть (план)

- `net/remotes.zap` — единственный контракт. После правки: `lune run net`.
- Поверх Zap — слой команд: лимиты частоты, валидация, очередь команд на игрока, проверка активной сессии.
- Ввод, влияющий на симуляцию (полёт, рывок), идёт через Input Action System, а не через remotes.

## Движение и Server Authority (решается экспериментом)

Server Authority блокирует спидхаки на уровне движка, но требует особого стиля кода: логика в `RunService:BindToSimulation`, только API с меткой Simulation Access, время через `time()`, ввод через Input Action System, удаление объектов вне симуляции.

В начале этапа 1 делаем эксперимент: полёт на джетпаке под Server Authority. По результату фиксируем решение в [DECISIONS.md](DECISIONS.md):
- **работает** → вся симуляция движения пишется по правилам Server Authority;
- **не работает** → клиент владеет своей физикой, сервер проверяет скорость и позицию с запасом на пинг и мягко возвращает нарушителя.

## Стражи (план)

- Без `Humanoid`: модель + `AnimationController`, анимации на клиенте.
- Конечный автомат на сервере: `Sleep → Alert → Chase → Return`. Общий автомат, разное поведение в `Chase` — отдельный модуль на каждого стража.
- Активны только рядом с игроками; тикают с пониженной частотой.

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
| `lune run net` | Перегенерирует сеть после правки `net/remotes.zap` |
| `rojo serve` | Синхронизация файлов в открытую Studio |
