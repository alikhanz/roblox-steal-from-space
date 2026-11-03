--!strict

local Duration = require("../../src/shared/Locale/Duration")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Duration.describe", function()
	it("rounds up to whole seconds and minutes", function()
		expect(Duration.describe("en", 0.2)).toBe("1 second")
		expect(Duration.describe("en", 41)).toBe("41 seconds")
		expect(Duration.describe("en", 61)).toBe("2 minutes")
		expect(Duration.describe("ru", 60 * 5)).toBe("5 минут")
		expect(Duration.describe("ru", 60 * 21)).toBe("21 минута")
	end)

	it("keeps a decimal for a few hours and drops it for many", function()
		expect(Duration.describe("en", 3600 * 1.42)).toBe("1.5 hours")
		expect(Duration.describe("ru", 3600 * 1.42)).toBe("1.5 часа")
		expect(Duration.describe("en", 3600 * 12.2)).toBe("13 hours")
	end)

	it("never goes negative", function()
		expect(Duration.describe("en", -5)).toBe("0 seconds")
	end)
end)
