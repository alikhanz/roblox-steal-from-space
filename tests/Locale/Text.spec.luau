--!strict

local Test = require("../../lune/lib/Test")
local Text = require("../../src/shared/Locale/Text")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Text.resolveLocale", function()
	it("maps Russian locale ids to ru", function()
		expect(Text.resolveLocale("ru-ru")).toBe("ru")
		expect(Text.resolveLocale("RU")).toBe("ru")
	end)

	it("falls back to English for anything else", function()
		expect(Text.resolveLocale("en-us")).toBe("en")
		expect(Text.resolveLocale("de-de")).toBe("en")
		expect(Text.resolveLocale("")).toBe("en")
	end)
end)

describe("Text.pluralForm", function()
	it("follows Russian plural rules", function()
		local expected: { [number]: string } = {
			[0] = "many",
			[1] = "one",
			[2] = "few",
			[4] = "few",
			[5] = "many",
			[11] = "many",
			[12] = "many",
			[14] = "many",
			[21] = "one",
			[22] = "few",
			[25] = "many",
			[101] = "one",
			[111] = "many",
		}
		for count, form in expected do
			expect(Text.pluralForm("ru", count)).toBe(form)
		end
		expect(Text.pluralForm("ru", 1.5)).toBe("few")
	end)

	it("follows English plural rules", function()
		expect(Text.pluralForm("en", 1)).toBe("one")
		expect(Text.pluralForm("en", 0)).toBe("other")
		expect(Text.pluralForm("en", 2)).toBe("other")
	end)
end)

describe("Text.get", function()
	it("returns the string for the requested locale", function()
		expect(Text.get("ru", "data.newerVersion.message")).toBe(
			"Вышло обновление игры. Зайди снова, чтобы играть дальше."
		)
		expect(Text.get("en", "data.newerVersion.message")).toBe("The game just got an update. Rejoin to keep playing.")
	end)

	it("rejects unknown keys", function()
		expect(function()
			Text.get("en", "missing.key.button" :: any)
		end).toThrow("Unknown text key")
	end)
end)
