--!strict
-- Looks up player-facing strings by key and fills in `{placeholders}`.
-- Plural strings pick a form from the `count` argument using the language's plural rules.

local Strings = require("./Strings")

export type Locale = "en" | "ru"
export type Key = keyof<typeof(Strings)>
export type Args = { [string]: string | number }

local Text = {}

Text.DEFAULT_LOCALE = "en" :: Locale

-- Russian: 1, 21, 101 -> one; 2-4, 22-24 -> few; 0, 5-20, 25-30 -> many; fractions -> few.
local function russianForm(count: number): string
	if count % 1 ~= 0 then
		return "few"
	end
	local lastDigit = math.abs(count) % 10
	local lastTwo = math.abs(count) % 100
	if lastDigit == 1 and lastTwo ~= 11 then
		return "one"
	elseif lastDigit >= 2 and lastDigit <= 4 and (lastTwo < 12 or lastTwo > 14) then
		return "few"
	end
	return "many"
end

local function englishForm(count: number): string
	return if count == 1 then "one" else "other"
end

local PLURAL_RULES: { [Locale]: (number) -> string } = {
	ru = russianForm,
	en = englishForm,
}

-- Maps a Roblox locale id ("ru-ru", "en-us", "de-de") to a supported locale.
-- The language a player sees the game in: their Roblox account's locale, which Roblox keeps for
-- in-experience content (Player.LocaleId). Not LocalizationService.RobloxLocaleId: that one is
-- for Roblox's own interface and can differ, which once mixed English windows with a Russian
-- prompt from the server. Everything a player reads goes through this.
function Text.localeOf(player: { read LocaleId: string }): Locale
	-- In Studio the Player Emulator's locale (Test → Player Emulator, CLAUDE.md) reaches only
	-- RobloxLocaleId, not Player.LocaleId (that stays the account's): read it there, so a playtest
	-- can switch the language. `game` is absent in Lune.
	-- Typed loosely: under Lune's types a service is a plain Instance.
	local runService: any = game and game:GetService("RunService")
	if runService and runService:IsStudio() then
		local localization: any = game:GetService("LocalizationService")
		return Text.resolveLocale(localization.RobloxLocaleId)
	end
	return Text.resolveLocale(player.LocaleId)
end

function Text.resolveLocale(localeId: string): Locale
	if string.sub(string.lower(localeId), 1, 2) == "ru" then
		return "ru"
	end
	return Text.DEFAULT_LOCALE
end

function Text.pluralForm(locale: Locale, count: number): string
	return PLURAL_RULES[locale](count)
end

local function interpolate(template: string, key: string, args: Args?): string
	local function replace(name: string): string
		local value = if args then args[name] else nil
		if value == nil then
			error(`Text "{key}" needs argument "{name}"`, 0)
		end
		return tostring(value)
	end
	local result = string.gsub(template, "{(%w+)}", replace)
	return result
end

function Text.get(locale: Locale, key: Key, args: Args?): string
	local entry = (Strings :: any)[key]
	assert(entry ~= nil, `Unknown text key "{key}"`)
	local template = entry[locale] or entry[Text.DEFAULT_LOCALE]

	if type(template) == "table" then
		local count = if args then args.count else nil
		assert(type(count) == "number", `Text "{key}" is plural and needs a numeric "count" argument`)
		template = template[Text.pluralForm(locale, count)]
	end
	return interpolate(template, key, args)
end

return table.freeze(Text)
