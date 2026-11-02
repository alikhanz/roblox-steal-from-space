# Steal from Space

Roblox-игра (рабочее название «Укради у Космоса»): крадёшь космо-яйца у стражей, убегаешь на джетпаке, выращиваешь пришельцев. Разработчик один, весь код пишет Claude, пользователь тестирует в Studio.

Перед работой прочитай нужное:
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md) — **обязательные правила кода**. Нарушать нельзя; менять — только через запись в журнале решений.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — слои, папки, запуск, данные, сеть.
- [docs/DECISIONS.md](docs/DECISIONS.md) — что уже решено и почему. Не переигрывай решения без обсуждения.
- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) — геймдизайн и этапы.
- [docs/STYLE_TEXT.md](docs/STYLE_TEXT.md), [docs/GLOSSARY.md](docs/GLOSSARY.md) — тексты для игроков.

## Команды

```
lune run install      # после клонирования и после правки wally.toml / rokit.toml
lune run check        # перед КАЖДЫМ коммитом; должен быть зелёным
lune run format       # если check упал на форматировании
lune run test [фильтр]
lune run content      # только проверка строк локализации
lune run net          # после правки net/remotes.zap
rojo serve            # синхронизация в Studio
```

Если `lune` и другие инструменты не находятся в PATH, обнови его в той же команде:
`$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')`

## Как работать

- Качество важнее скорости. Пиши код так, чтобы его можно было поддерживать годами.
- Код, комментарии, коммиты — на английском. Документация и общение — на русском.
- Не торопись: крупные шаги сначала обсуждай с пользователем. Не начинай следующий этап без его слова.
- Новая доменная логика приходит с тестами в `tests/`.
- Любой текст для игрока — через скилл `game-copy`, на двух языках, только термины из глоссария.
- Новая зависимость или изменение правила — запись в `docs/DECISIONS.md`.
- Ветки `<тип>/<кратко>`, коммиты Conventional Commits. Перед `git push` покажи пользователю, что уйдёт.
- Не правь сгенерированное: `Packages/`, `ServerPackages/`, `src/*/Net/Remotes.luau`, `sourcemap.json`, `types/`, `build/`.
- Studio: при подключённом MCP-сервере `Roblox_Studio` можно запускать плейтесты, выполнять Luau и читать Output. Код всё равно правится только в файлах.

## Studio: что важно знать

- **Server Authority** включается в плейсе вручную: Workspace → Properties → `AuthorityMode = Server`. Из скриптов, MCP и плагина Rojo это свойство недоступно.
- **`rojo serve` может упасть**, если файл создаётся и сразу удаляется (например, временный пробный файл). Признак — новые файлы не появляются в Studio. Лечится перезапуском `rojo serve` и повторным Connect в плагине. Временные файлы лучше класть вне `src/`.
- **Код в запущенном плейтесте не обновляется** — после правок перезапускай Play. Перед Play дай Rojo секунду-две на синхронизацию: если запустить сразу после правки, в игру попадёт старый код.
- В Studio всё работает на mock-хранилище ProfileStore (плейс не опубликован) — это ожидаемо.
- Плейтест через MCP: `start_stop_play`, ввод — `user_keyboard_input`, проверки — `execute_luau` в `Server`/`Client`, вывод — `get_console_output`.

## Анимации

- Позы задаются **данными** в коде (`src/shared/Character/FlightPose.luau`: углы суставов R15), из них `FlightAnimation.buildSequence()` собирает `KeyframeSequence`.
- Под Server Authority персонаж игрока проигрывает **только загруженные** анимации, и только запущенные внутри симуляции. Временные анимации Studio (`RegisterKeyframeSequence`) не работают.
- **Загрузка** (делает пользователь, от владельца игры — аккаунта или группы): Explorer → `ServerStorage.JetpackFlight` → правый клик → **Save to Roblox** → тип Animation. Полученный ID — в `JetpackConfig.FLIGHT_ANIMATION_ID` (`rbxassetid://…`). Для правки позы — повторная загрузка с перезаписью того же ассета, ID не меняется.
- **Предпросмотр позы без игры:** в Edit-режиме манекен R15, у которого `AnimationConstraint` заменены на `Motor6D` (поза пишется в `C0`), и снимки через MCP `screen_capture`. `AnimationConstraint` позу без физики не показывает.
- Суставы аватара — `AnimationConstraint`, а не `Motor6D`; `Animate` — модуль, его нельзя отключить. Переопределять суставы скриптом бесполезно: аниматор пишет их последним перед физикой.
- В тестах через MCP переносить персонажа — только `character:PivotTo(...)` (см. CONVENTIONS, «Персонаж»). Фоновые задачи (`task.spawn`) из `execute_luau` завершаются вместе с вызовом: для замеров во время ввода зажми клавишу (`user_keyboard_input` keyDown), замерь в одном вызове, потом отпусти.
- MCP после каждого `execute_luau` сбрасывает камеру. Чтобы снять кадр с нужной точки в игре, держи камеру через `RunService:BindToRenderStep`; в режиме редактирования — `screen_capture` с позицией камеры. `computer-use` `zoom` увеличивает **последний** полный скриншот, а не делает новый.
