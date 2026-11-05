--!strict

local EggConfig = require("../../src/shared/Config/EggConfig")
local SerpentConfig = require("../../src/shared/Config/SerpentConfig")
local StarEgg = require("../../src/shared/Domain/StarEgg")
local Test = require("../../lune/lib/Test")
local ZoneConfig = require("../../src/shared/Config/ZoneConfig")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("StarEgg", function()
	it("raises a commoner rarity to the floor and keeps a rarer one", function()
		expect(StarEgg.atLeast("Common", "Rare")).toBe("Rare")
		expect(StarEgg.atLeast("Uncommon", "Rare")).toBe("Rare")
		expect(StarEgg.atLeast("Rare", "Rare")).toBe("Rare")
		expect(StarEgg.atLeast("Legendary", "Rare")).toBe("Legendary")
	end)

	it("takes the grade of its zone's middle guardian", function()
		expect(StarEgg.grade("IceRings")).toBe(ZoneConfig.postIndex("IceRings", SerpentConfig.POWER_POST))
		expect(StarEgg.grade("EventHorizon")).toBe(ZoneConfig.postIndex("EventHorizon", SerpentConfig.POWER_POST))
	end)

	it("is rare or better, of its zone's sizes, with the serpent's luck", function()
		local minRank = table.find(EggConfig.RARITY_ORDER, SerpentConfig.STAR_EGG_MIN_RARITY) :: number
		for _, zone in ZoneConfig.ZONE_ORDER do
			for roll = 0, 0.99, 0.01 do
				local egg = StarEgg.roll(zone, roll, roll)
				expect((table.find(EggConfig.RARITY_ORDER, egg.rarity) :: number) >= minRank).toBe(true)
				expect(EggConfig.SIZES[egg.size] ~= nil).toBe(true)
				expect(egg.grade).toBe(StarEgg.grade(zone))
				expect(egg.luck).toBe(SerpentConfig.STAR_EGG_LUCK)
			end
		end
	end)

	it("still rolls its zone's rarer eggs", function()
		-- The top of the roll is the rarest entry of the zone's loot.
		expect(StarEgg.roll("EventHorizon", 0.999, 0).rarity).toBe("Legendary")
	end)
end)
