---
name: game-copy
description: Write or review any player-facing text in Steal from Space (buttons, labels, tooltips, notifications, errors, item and alien descriptions, announcements, purchase prompts, tutorial lines) in Russian and English. Use whenever adding or changing localization strings or any text a player will see.
---

# Game copy for Steal from Space

Player-facing text must read like a person wrote it for kids aged 8–14 playing on a phone mid-chase. Never ship text that sounds like marketing, documentation, or a chatbot.

## Before writing

Read these project files first; they are the source of truth and override anything below:
- `docs/STYLE_TEXT.md` — rules, tone table, length limits, stop-list.
- `docs/GLOSSARY.md` — the only allowed names for game terms, in both languages.

If the `ux-writing` skill is available, apply its patterns (verb-first buttons, "what happened → what to do" errors, tone by emotional state) on top of the project rules. Project rules win on conflict: e.g. we use sentence case in English, but short all-caps shouts are allowed for rare finds.

## Workflow

1. **Context.** Where does the text appear, what is the player doing and feeling (chasing, celebrating, blocked, buying)? Pick the tone from the table in `STYLE_TEXT.md`.
2. **Russian first draft.** Write it the way a kid would say it to a friend. Verb first, "ты", digits for numbers.
3. **English written separately.** Do not translate word for word. Write what an English-speaking kid would say in the same moment.
4. **Terms.** Every game term must match `GLOSSARY.md` exactly (including grammatical gender agreement in Russian). New term → add it to the glossary first and tell the user.
5. **Cut.** Remove every word that does not change the meaning. Check the length limit for the element type.
6. **Read aloud test.** If it sounds like an ad, a manual, or a form — rewrite.
7. **Stop-list.** Scan both languages against the stop-list in `STYLE_TEXT.md`. Also reject: "not just X, it's Y", triples of adjectives, chains of dashes, more than one "!".
8. **Purchases.** Price and reward visible, no fake urgency, a neutral "Not now" option.

## Output format

For each string, give the key, both languages, and character counts:

```
key: hatch.instant.button
ru: Вылупить сейчас (15/16)
en: Hatch now (9/14)
```

When reviewing existing strings, list only the ones that need changes, with a one-line reason each.
