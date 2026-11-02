--!strict
-- Validates the localization table against docs/STYLE_TEXT.md rules (via TextRules).
-- Returns a list of human-readable problems; an empty list means the table is valid.

local TextRules = require("./TextRules")

local StringsValidator = {}

local KEY_PATTERN = "^[a-z][%w]*%.[%w%.]*[%w]$"

local CYRILLIC_UPPER_FIRST = 0x0410
local CYRILLIC_UPPER_LAST = 0x042F
local CYRILLIC_CASE_OFFSET = 0x20
local CYRILLIC_UPPER_YO = 0x0401
local CYRILLIC_LOWER_YO = 0x0451

-- string.lower only handles ASCII; this also lowercases Russian letters.
local function lowerUtf8(text: string): string
	local codepoints = {}
	for _, codepoint in utf8.codes(text) do
		if codepoint >= CYRILLIC_UPPER_FIRST and codepoint <= CYRILLIC_UPPER_LAST then
			codepoint += CYRILLIC_CASE_OFFSET
		elseif codepoint == CYRILLIC_UPPER_YO then
			codepoint = CYRILLIC_LOWER_YO
		end
		table.insert(codepoints, utf8.char(codepoint))
	end
	return string.lower(table.concat(codepoints))
end

local function placeholders(text: string): { [string]: boolean }
	local found = {}
	for name in string.gmatch(text, "{(%w+)}") do
		found[name] = true
	end
	return found
end

local function visibleLength(text: string): number
	local withoutPlaceholders, count = string.gsub(text, "{%w+}", "")
	return (utf8.len(withoutPlaceholders) or #withoutPlaceholders) + count * TextRules.PLACEHOLDER_WIDTH
end

local function sortedNames(set: { [string]: boolean }): string
	local names = {}
	for name in set do
		table.insert(names, name)
	end
	table.sort(names)
	return table.concat(names, ", ")
end

-- Collects (form label, text) pairs for one locale value, reporting shape problems.
local function collectForms(
	key: string,
	locale: string,
	value: unknown,
	problems: { string }
): { { label: string, text: string } }
	if type(value) == "string" then
		return { { label = locale, text = value } }
	end
	if type(value) ~= "table" then
		table.insert(problems, `{key}: missing "{locale}" text`)
		return {}
	end

	local forms = {}
	local expected = (TextRules.PLURAL_FORMS :: any)[locale] :: { string }
	for _, form in expected do
		local text = (value :: any)[form]
		if type(text) ~= "string" then
			table.insert(problems, `{key}: "{locale}" plural needs form "{form}"`)
		else
			table.insert(forms, { label = `{locale}.{form}`, text = text })
		end
	end
	for form in value :: any do
		if not table.find(expected, form) then
			table.insert(problems, `{key}: "{locale}" has unknown plural form "{form}"`)
		end
	end
	return forms
end

function StringsValidator.validate(strings: { [string]: any }): { string }
	local problems: { string } = {}

	local keys = {}
	for key in strings do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in keys do
		local entry = strings[key]
		if not string.match(key, KEY_PATTERN) then
			table.insert(problems, `{key}: key must look like "area.name.kind"`)
			continue
		end
		local kind = string.match(key, "%.(%w+)$") :: string
		local limits = (TextRules.LENGTH_LIMITS :: any)[kind]
		if not limits then
			table.insert(problems, `{key}: unknown kind "{kind}"`)
			continue
		end
		if type(entry) ~= "table" then
			table.insert(problems, `{key}: entry must be a table of locales`)
			continue
		end

		local pluralLocales = 0
		for _, locale in TextRules.LOCALES do
			if type(entry[locale]) == "table" then
				pluralLocales += 1
			end
		end
		local isPluralEntry = pluralLocales > 0
		if isPluralEntry and pluralLocales < #TextRules.LOCALES then
			table.insert(problems, `{key}: all locales must be plural or none`)
		end

		local referencePlaceholders: string? = nil
		for _, locale in TextRules.LOCALES do
			local value = entry[locale]

			for _, form in collectForms(key, locale, value, problems) do
				local length = visibleLength(form.text)
				local limit = limits[locale]
				if length > limit then
					table.insert(problems, `{key} [{form.label}]: {length} characters, limit is {limit}`)
				end

				local lowered = lowerUtf8(form.text)
				for _, phrase in (TextRules.STOP_LIST :: any)[locale] :: { string } do
					if string.find(lowered, phrase, 1, true) then
						table.insert(problems, `{key} [{form.label}]: stop-list phrase "{phrase}"`)
					end
				end

				-- Plural forms may leave out {count} (e.g. "one egg"); every other placeholder must match.
				local names = placeholders(form.text)
				if isPluralEntry then
					names.count = nil
				end
				local signature = sortedNames(names)
				if referencePlaceholders == nil then
					referencePlaceholders = signature
				elseif signature ~= referencePlaceholders then
					table.insert(
						problems,
						`{key} [{form.label}]: placeholders \{{signature}\} differ from \{{referencePlaceholders}\}`
					)
				end
			end
		end

		for locale in entry do
			if not table.find(TextRules.LOCALES, locale) then
				table.insert(problems, `{key}: unsupported locale "{locale}"`)
			end
		end
	end

	return problems
end

return StringsValidator
