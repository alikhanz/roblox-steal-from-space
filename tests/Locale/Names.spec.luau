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

describe("Names.egg", function()
	it("names eggs by rarity", function()
		expect(Names.egg("ru", "Rare")).toBe("Редкое яйцо")
		expect(Names.egg("en", "Common")).toBe("Common egg")
		expect(Names.egg("en", "Mythic")).toBeNil()
	end)
end)
