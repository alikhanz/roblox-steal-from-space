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
