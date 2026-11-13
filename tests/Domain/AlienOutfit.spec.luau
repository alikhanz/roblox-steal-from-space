--!strict

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local AlienOutfit = require("../../src/shared/Domain/AlienOutfit")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- A legendary alien of the first guardian, and a common one.
local LEGENDARY = AlienConfig.GRADES[1].aliens.Legendary
local COMMON = AlienConfig.GRADES[1].aliens.Common

describe("AlienOutfit.sequence", function()
	it("gives whole numbers in the range, the same for one seed", function()
		local first, second = AlienOutfit.sequence(7), AlienOutfit.sequence(7)
		for _ = 1, 200 do
			local value = first(3, 9)
			expect(value >= 3 and value <= 9 and value % 1 == 0).toBe(true)
			expect(second(3, 9)).toBe(value)
		end
	end)
end)

describe("AlienOutfit.draw", function()
	it("draws from its tier's pools: nothing on a common's back, a crown on a legendary", function()
		local nextInteger = AlienOutfit.sequence(3)
		for _ = 1, 60 do
			local common = AlienOutfit.draw(1, nextInteger)
			expect(common.aura).toBe(nil)
			expect(common.back).toBe(nil)
			local rare = AlienOutfit.draw(3, nextInteger)
			expect(rare.back == "jetpack" or rare.back == "angelSmall" or rare.back == "butterflySmall").toBe(true)
			local legendary = AlienOutfit.draw(5, nextInteger)
			expect(legendary.head).toBe("crown")
			expect(legendary.back ~= nil and AlienOutfit.isPiece("back", legendary.back :: string)).toBe(true)
		end
	end)

	it("varies from pet to pet", function()
		local nextInteger = AlienOutfit.sequence(11)
		local seen: { [string]: boolean } = {}
		local count = 0
		for _ = 1, 40 do
			local key = AlienOutfit.key(AlienOutfit.draw(4, nextInteger))
			if not seen[key] then
				seen[key] = true
				count += 1
			end
		end
		-- 45 sets an epic can draw; forty pets show many of them.
		expect(count >= 20).toBe(true)
	end)
end)

describe("AlienOutfit.forAlien", function()
	it("draws by the alien's tier, and nothing for an id the game doesn't know", function()
		local legendary = AlienOutfit.forAlien(LEGENDARY, AlienOutfit.sequence(1)) :: AlienOutfit.Picks
		expect(legendary.head).toBe("crown")
		local common = AlienOutfit.forAlien(COMMON, AlienOutfit.sequence(1)) :: AlienOutfit.Picks
		expect(common.back).toBe(nil)
		expect(AlienOutfit.forAlien("NoSuchAlien", AlienOutfit.sequence(1))).toBe(nil)
	end)
end)

describe("AlienOutfit.repair", function()
	it("keeps the pieces the game has, even ones its tier's pools don't offer", function()
		-- Horns are no legendary's head piece any more (a crown is), but they stay: a pool only
		-- changes what new aliens draw (decision 121).
		local outfit: AlienOutfit.Picks = { head = "horns", aura = "star", back = "fairy" }
		expect(AlienOutfit.repair(outfit, LEGENDARY, AlienOutfit.sequence(1))).toBe(false)
		expect(outfit.head).toBe("horns")
		expect(outfit.aura).toBe("star")
		expect(outfit.back).toBe("fairy")
	end)

	it("draws a piece taken out of the game anew from its slot's pool", function()
		local outfit: AlienOutfit.Picks = { head = "crown", aura = "removedAura", back = "fairy" }
		expect(AlienOutfit.repair(outfit, LEGENDARY, AlienOutfit.sequence(5))).toBe(true)
		expect(AlienOutfit.isPiece("aura", outfit.aura :: string)).toBe(true)
		expect(outfit.head).toBe("crown")
		expect(outfit.back).toBe("fairy")
	end)

	it("empties a slot its tier has no pool for", function()
		local outfit: AlienOutfit.Picks = { back = "removedWings" }
		expect(AlienOutfit.repair(outfit, COMMON, AlienOutfit.sequence(5))).toBe(true)
		expect(outfit.back).toBe(nil)
	end)
end)

describe("AlienOutfit.first", function()
	it("takes the first piece of each pool", function()
		local picks = AlienOutfit.first(4)
		expect(picks.head).toBe("horns")
		expect(picks.aura).toBe("halo")
		expect(picks.back).toBe("butterfly")
	end)
end)

describe("AlienOutfit.fromKey", function()
	it("gives back the outfit its key names, empty slots too", function()
		for _, picks: AlienOutfit.Picks in
			{
				{ head = "crown", aura = "star", back = "fairy" },
				{ head = "horns" },
				{ aura = "halo", back = "jetpack" },
				{},
			}
		do
			local back = AlienOutfit.fromKey(AlienOutfit.key(picks))
			expect(back.head).toBe(picks.head)
			expect(back.aura).toBe(picks.aura)
			expect(back.back).toBe(picks.back)
		end
	end)

	it("reads anything else as no outfit", function()
		local none = AlienOutfit.fromKey("not a key")
		expect(none.head).toBe(nil)
		expect(none.aura).toBe(nil)
		expect(none.back).toBe(nil)
	end)
end)
