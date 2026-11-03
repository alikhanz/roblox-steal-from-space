--!strict
-- Cross-references between configs (CONVENTIONS, economy: checked automatically).

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local BayConfig = require("../../src/shared/Config/BayConfig")
local BigNum = require("../../src/shared/Domain/BigNum")
local EggConfig = require("../../src/shared/Config/EggConfig")
local GuardianConfig = require("../../src/shared/Config/GuardianConfig")
local Loot = require("../../src/shared/Domain/Loot")
local Speed = require("../../src/shared/Domain/Speed")
local SpeedConfig = require("../../src/shared/Config/SpeedConfig")
local Strings = require("../../src/shared/Locale/Strings")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("AlienConfig", function()
	it("has one grade per guardian post with an alien per tier", function()
		expect(#AlienConfig.GRADES).toBe(#GuardianConfig.DEBRIS_BELT_POSTS)
		for _, grade in AlienConfig.GRADES do
			for _, tier in AlienConfig.TIER_ORDER do
				local alien = AlienConfig.ALIENS[grade.aliens[tier]]
				expect(alien).toBeTruthy()
				expect(alien.grade).toBe(grade.index)
				expect(alien.tier).toBe(tier)
			end
		end
	end)

	it("earns more up the tiers and up the grades", function()
		for index, grade in AlienConfig.GRADES do
			local previous: BigNum.BigNum? = nil
			for _, tier in AlienConfig.TIER_ORDER do
				local income = AlienConfig.ALIENS[grade.aliens[tier]].income
				if previous then
					expect(BigNum.lessThan(previous, income)).toBe(true)
				end
				previous = income
			end
			if index > 1 then
				local lower = AlienConfig.ALIENS[AlienConfig.GRADES[index - 1].aliens.Common].income
				local higher = AlienConfig.ALIENS[grade.aliens.Common].income
				expect(BigNum.lessThan(lower, higher)).toBe(true)
			end
		end
	end)

	it("names every tier with an existing string", function()
		for _, tier in AlienConfig.TIER_ORDER do
			expect((Strings :: { [string]: any })[AlienConfig.TIERS[tier].nameKey]).toBeTruthy()
		end
		expect(Loot.chances(AlienConfig.HATCH_ENTRIES).Common > 0.5).toBe(true)
	end)
end)

describe("EggConfig", function()
	it("rolls loot only for rarities and sizes that exist", function()
		for _, entry in EggConfig.DEBRIS_BELT_LOOT do
			expect(EggConfig.RARITIES[entry.id]).toBeTruthy()
		end
		for _, entry in EggConfig.DEBRIS_BELT_SIZE_LOOT do
			expect(EggConfig.SIZES[entry.id]).toBeTruthy()
		end
		expect(EggConfig.SIZES[EggConfig.TYPICAL_SIZE]).toBeTruthy()
	end)

	it("hatches rarer eggs slower and luckier", function()
		local common, uncommon, rare = EggConfig.RARITIES.Common, EggConfig.RARITIES.Uncommon, EggConfig.RARITIES.Rare
		expect(common.hatchSeconds.max < uncommon.hatchSeconds.max).toBe(true)
		expect(uncommon.hatchSeconds.max < rare.hatchSeconds.max).toBe(true)
		expect(rare.hatchSeconds.max <= 5 * 60 * 60).toBe(true)
		expect(common.luck < uncommon.luck and uncommon.luck < rare.luck).toBe(true)
	end)
end)

describe("GuardianConfig", function()
	it("recommends the starting speed over the first guardian", function()
		expect(BigNum.toNumber(GuardianConfig.DEBRIS_BELT_POSTS[1].recommended)).toBeCloseTo(
			BigNum.toNumber(SpeedConfig.STARTING_SPEED),
			1e-9
		)
	end)

	it("grows the recommendation by the growth factor and flies level with it", function()
		local posts = GuardianConfig.DEBRIS_BELT_POSTS
		expect(posts[1].recommended).toEqual(GuardianConfig.FIRST_RECOMMENDED)
		for index = 2, #posts do
			local expected = BigNum.mul(posts[index - 1].recommended, GuardianConfig.RECOMMENDED_GROWTH)
			expect(BigNum.toNumber(posts[index].recommended)).toBeCloseTo(BigNum.toNumber(expected), 1e-9)
		end
		for _, post in posts do
			expect(GuardianConfig.KINDS[post.kind]).toBeTruthy()
			-- A thief at the recommended speed with a typical egg matches the guardian exactly.
			local withEgg = Speed.withEgg(post.recommended, GuardianConfig.TYPICAL_WEIGHT)
			expect(BigNum.toNumber(withEgg)).toBeCloseTo(BigNum.toNumber(post.speed), 1e-9)
		end
	end)
end)

describe("BayConfig", function()
	it("keeps the starting pods within the maximum", function()
		expect(BayConfig.STARTING_PODS <= BayConfig.MAX_PODS).toBe(true)
		expect(BayConfig.CROSSBREED_COUNT <= BayConfig.INVENTORY_SLOTS).toBe(true)
	end)
end)
