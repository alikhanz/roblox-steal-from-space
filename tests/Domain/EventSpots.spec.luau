--!strict

local EventSpots = require("../../src/shared/Domain/EventSpots")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("EventSpots.nearestPerZone", function()
	it("keeps the nearest spot of each zone, nearest first", function()
		local spots: { EventSpots.Spot<string> } = {
			{ zone = "IceRings", distance = 900, item = "ice far" },
			{ zone = "DebrisBelt", distance = 300, item = "debris" },
			{ zone = "IceRings", distance = 700, item = "ice near" },
			{ zone = "EventHorizon", distance = 2500, item = "horizon" },
		}
		local nearest = EventSpots.nearestPerZone(spots)
		expect(#nearest).toBe(3)
		expect(nearest[1].item).toBe("debris")
		expect(nearest[2].item).toBe("ice near")
		expect(nearest[3].item).toBe("horizon")
	end)

	it("puts a far zone first for a player out there", function()
		local nearest = EventSpots.nearestPerZone({
			{ zone = "DebrisBelt", distance = 1800, item = 1 },
			{ zone = "RedNebula", distance = 120, item = 2 },
		})
		expect(nearest[1].item).toBe(2)
	end)

	it("has nothing to mark without spots", function()
		expect(#EventSpots.nearestPerZone({})).toBe(0)
	end)
end)
