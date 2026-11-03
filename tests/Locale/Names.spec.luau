--!strict

local Names = require("../../src/shared/Locale/Names")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Names.alien", function()
	it("names an alien by its tier and guardian in both languages", function()
		expect(Names.alien("ru", "DebrisBelt1.Rare")).toBe("Редкий · Слизень-сторож")
		expect(Names.alien("en", "DebrisBelt2.Legendary")).toBe("Legendary · Crab Drone")
	end)

	it("returns nil for an unknown alien", function()
		expect(Names.alien("en", "Nope.Common")).toBeNil()
	end)
end)

describe("Names.jetpack", function()
	it("names the listed levels and counts past the last one", function()
		expect(Names.jetpack("en", 0)).toBe("Starter")
		expect(Names.jetpack("ru", 2)).toBe("Комета")
		expect(Names.jetpack("en", 7)).toBe("Antimatter")
		expect(Names.jetpack("en", 9)).toBe("Antimatter +2")
		expect(Names.jetpack("ru", 8)).toBe("Антиматерия +1")
	end)

	it("rejects a broken level", function()
		expect(function()
			Names.jetpack("en", -1)
		end).toThrow("whole number")
	end)
end)

describe("Names.egg", function()
	it("names eggs by rarity", function()
		expect(Names.egg("ru", "Rare")).toBe("Редкое яйцо")
		expect(Names.egg("en", "Common")).toBe("Common egg")
		expect(Names.egg("en", "Mythic")).toBeNil()
	end)
end)
