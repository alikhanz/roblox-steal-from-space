--!strict

local Names = require("../../src/shared/Locale/Names")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Names.alien", function()
	it("names an alien by its tier and kind in both languages", function()
		expect(Names.alien("ru", "DebrisBelt1.slimeWarden.Rare")).toBe("Редкий · Слизень-сторож")
		expect(Names.alien("en", "DebrisBelt2.crabDrone.Legendary")).toBe("Legendary · Crab Drone")
		expect(Names.alien("en", "DebrisBelt2.droneRay.Legendary")).toBe("Legendary · Drone Ray")
		expect(Names.alien("en", "IceRings1.iceWorm.Common")).toBe("Common · Ice Worm")
		expect(Names.alien("ru", "EventHorizon6.galaxySlime.Epic")).toBe(
			"Эпический · Галактический слизень"
		)
	end)

	it("returns nil for an unknown alien", function()
		expect(Names.alien("en", "Nope.Common")).toBeNil()
		expect({ Names.alienParts("en", "Nope.Common") }).toEqual({})
	end)

	it("gives the halves apart and names a grade's guardian", function()
		expect({ Names.alienParts("ru", "DebrisBelt2.blimpWhale.Epic") }).toEqual({
			"Эпический",
			"Кит-дирижабль",
		})
		expect(Names.guardian("en", 24)).toBe("Space Whale")
		expect(Names.guardian("en", 99)).toBeNil()
	end)

	it("puts the variant in front of a meteor alien's tier", function()
		expect(Names.alien("ru", "DebrisBelt1.slimeWarden.Rare.Meteor")).toBe(
			"Метеоритный · Редкий · Слизень-сторож"
		)
		expect(Names.alien("en", "DebrisBelt1.patrolRay.Rare.Meteor")).toBe("Meteor · Rare · Patrol Ray")
	end)
end)

describe("Names.jetpack", function()
	it("names a level by its jetpack and mark", function()
		expect(Names.jetpack("en", 0)).toBe("Starter")
		expect(Names.jetpack("en", 1)).toBe("Spark I")
		expect(Names.jetpack("en", 2)).toBe("Spark II")
		expect(Names.jetpack("ru", 3)).toBe("Комета I")
		expect(Names.jetpack("ru", 12)).toBe("Квазар II")
		expect(Names.jetpack("en", 14)).toBe("Antimatter II")
		expect(Names.jetpack("ru", 19)).toBe("Червоточина I")
	end)

	it("gives the top jetpack no mark, and a saved level past it the top's name", function()
		expect(Names.jetpack("en", 21)).toBe("Infinity")
		expect(Names.jetpack("ru", 30)).toBe("Бесконечность")
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

	it("puts the variant in front of a meteor egg's name", function()
		expect(Names.egg("ru", "Rare", "Meteor")).toBe("Метеоритное · Редкое яйцо")
		expect(Names.egg("en", "Rare", "Meteor")).toBe("Meteor · Rare egg")
		expect(Names.egg("en", "Rare", "Normal")).toBe("Rare egg")
	end)
end)
