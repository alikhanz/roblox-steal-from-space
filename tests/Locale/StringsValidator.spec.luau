--!strict

local StringsValidator = require("../../lune/lib/StringsValidator")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function problemsFor(strings: { [string]: any }): string
	return table.concat(StringsValidator.validate(strings), "\n")
end

describe("StringsValidator", function()
	it("accepts a valid table", function()
		expect(StringsValidator.validate({
			["egg.steal.button"] = { ru = "Укради яйцо", en = "Steal egg" },
			["egg.count.toast"] = {
				ru = { one = "{count} яйцо", few = "{count} яйца", many = "{count} яиц" },
				en = { one = "{count} egg", other = "{count} eggs" },
			},
		})).toEqual({})
	end)

	it("rejects malformed keys and unknown kinds", function()
		local problems = problemsFor({
			["Egg steal"] = { ru = "а", en = "a" },
			["egg.steal.banner"] = { ru = "а", en = "a" },
		})
		expect(string.find(problems, "key must look like", 1, true) ~= nil).toBe(true)
		expect(string.find(problems, 'unknown kind "banner"', 1, true) ~= nil).toBe(true)
	end)

	it("requires both locales", function()
		expect(problemsFor({ ["egg.steal.button"] = { ru = "Укради яйцо" } })).toBe(
			'egg.steal.button: missing "en" text'
		)
	end)

	it("enforces length limits per kind", function()
		expect(problemsFor({
			["egg.steal.button"] = { ru = "Укради это прекрасное яйцо", en = "Steal egg" },
		})).toBe("egg.steal.button [ru]: 26 characters, limit is 16")
	end)

	it("catches stop-list phrases in Russian regardless of case", function()
		expect(problemsFor({
			["egg.intro.hint"] = { ru = "Погрузись в космос", en = "Fly into space" },
		})).toBe('egg.intro.hint [ru]: stop-list phrase "погрузи"')
	end)

	it("requires matching placeholders across locales", function()
		expect(problemsFor({
			["egg.found.toast"] = { ru = "{name} нашёл яйцо", en = "Egg found" },
		})).toBe("egg.found.toast [en]: placeholders {} differ from {name}")
	end)

	it("requires complete plural forms", function()
		expect(problemsFor({
			["egg.count.toast"] = {
				ru = { one = "{count} яйцо", many = "{count} яиц" },
				en = { one = "{count} egg", other = "{count} eggs" },
			},
		})).toBe('egg.count.toast: "ru" plural needs form "few"')
	end)

	it("requires plural and plain locales to agree", function()
		expect(problemsFor({
			["egg.count.toast"] = {
				ru = "{count} яиц",
				en = { one = "{count} egg", other = "{count} eggs" },
			},
		})).toBe("egg.count.toast: all locales must be plural or none")
	end)
end)
