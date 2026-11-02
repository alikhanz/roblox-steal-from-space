--!strict
-- Machine-checkable part of docs/STYLE_TEXT.md. Keep both in sync.

local TextRules = {}

TextRules.LOCALES = { "ru", "en" }

TextRules.PLURAL_FORMS = {
	ru = { "one", "few", "many" },
	en = { "one", "other" },
}

-- Maximum visible characters per element kind (the last segment of a key).
TextRules.LENGTH_LIMITS = {
	button = { ru = 16, en = 14 },
	title = { ru = 24, en = 22 },
	toast = { ru = 40, en = 36 },
	hint = { ru = 90, en = 80 },
	announce = { ru = 70, en = 64 },
	message = { ru = 160, en = 150 },
}

-- A placeholder is counted as this many characters (a typical short number or name).
TextRules.PLACEHOLDER_WIDTH = 3

-- Lowercase substrings that mark marketing filler or bureaucratic tone.
TextRules.STOP_LIST = {
	ru = {
		"погрузи",
		"окунись",
		"добро пожаловать в мир",
		"уникальн",
		"незабываем",
		"захватывающ",
		"невероятн",
		"эпичн",
		"откройте для себя",
		"насладитесь",
		"испытайте",
		"данный",
		"является",
		"осуществ",
		"в рамках",
		"произвести",
		"в целях",
		"не просто",
		"!!",
	},
	en = {
		"embark",
		"unleash",
		"dive into",
		"delve",
		"elevate",
		"seamless",
		"journey",
		"realm",
		"get ready to",
		"experience the thrill",
		"the ultimate",
		"like never before",
		"not just",
		"!!",
	},
}

return TextRules
