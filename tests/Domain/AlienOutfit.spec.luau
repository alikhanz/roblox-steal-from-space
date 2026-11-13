--!strict

local AlienOutfit = require("../../src/shared/Domain/AlienOutfit")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("AlienOutfit.hash", function()
	it("matches the Blender side (assets/blender/lowpoly/lowpoly_dress.py, fnv1a)", function()
		expect(AlienOutfit.hash("1")).toBe(1428125071)
		expect(AlienOutfit.hash("12345:7")).toBe(89114941)
		expect(AlienOutfit.hash("11826206709:42")).toBe(1030879421)
	end)
end)

describe("AlienOutfit.roll", function()
	it("rolls what the Blender side rolls", function()
		local picks = AlienOutfit.roll(11826206709, 42, 4)
		expect(picks.head).toBe("feelers")
		expect(picks.aura).toBe("rings")
		expect(picks.back).toBe("sail")
		local legendary = AlienOutfit.roll(1, 1, 5)
		expect(legendary.head).toBe("crown")
		expect(legendary.aura).toBe("star")
		expect(legendary.back).toBe("butterfly")
	end)

	it("is the same every time for one owner and uid", function()
		for tier = 1, AlienOutfit.TIERS do
			expect(AlienOutfit.key(AlienOutfit.roll(77, 5, tier))).toBe(AlienOutfit.key(AlienOutfit.roll(77, 5, tier)))
		end
	end)

	it("gives a common no back and no aura, and wings only from epic", function()
		for uid = 1, 50 do
			local common = AlienOutfit.roll(9, uid, 1)
			expect(common.aura).toBe(nil)
			expect(common.back).toBe(nil)
			local rare = AlienOutfit.roll(9, uid, 3)
			expect(rare.back == "jetpack" or rare.back == "angelSmall" or rare.back == "butterflySmall").toBe(true)
			expect(AlienOutfit.roll(9, uid, 5).head).toBe("crown")
		end
	end)

	it("varies from pet to pet", function()
		local seen: { [string]: boolean } = {}
		local count = 0
		for uid = 1, 40 do
			local key = AlienOutfit.key(AlienOutfit.roll(123456, uid, 4))
			if not seen[key] then
				seen[key] = true
				count += 1
			end
		end
		-- 45 sets an epic can roll; forty pets show many of them.
		expect(count >= 20).toBe(true)
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
