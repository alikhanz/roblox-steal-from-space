# Steal from Space

Roblox-игра: крадёшь космо-яйца у стражей, убегаешь на джетпаке, выращиваешь пришельцев.

## Что нужно

- [Roblox Studio](https://create.roblox.com)
- [Rokit](https://github.com/rojo-rbx/rokit) — ставит все остальные инструменты по `rokit.toml`
- Git, VS Code с расширениями из `.vscode/extensions.json`
- Плагин Rojo в Studio: `rojo plugin install`

## Первый запуск

```
rokit install
lune setup
lune run install
lune run check
```

Затем `rojo serve`, в Studio — вкладка Plugins → Rojo → Connect.

## Команды

| Команда | Что делает |
|---|---|
| `lune run install` | Пакеты, определения типов Roblox, сетевой код, sourcemap |
| `lune run check` | Формат, линтер, типы, тесты, сборка. Запускать перед каждым коммитом |
| `lune run format` | Отформатировать код |
| `lune run test [фильтр]` | Тесты |
| `lune run net` | Перегенерировать сеть после правки `net/remotes.zap` |
| `lune run balance [дней]` | Калькулятор баланса: темп игры по конфигам |
| `rojo serve` | Синхронизация в Studio |

## Документация

- [Правила разработки](docs/CONVENTIONS.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Журнал решений](docs/DECISIONS.md)
- [Геймдизайн](docs/GAME_DESIGN.md)
- [Тексты](docs/STYLE_TEXT.md) и [глоссарий](docs/GLOSSARY.md)
