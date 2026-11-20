--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Pvp = require("../../src/shared/Domain/Pvp")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local RULES: Pvp.Rules = { newbieSeconds = 1200, spawnGraceSeconds = 10, maxSpeedRatio = 10 }

local function side(patch: { [string]: any }?): Pvp.Side
	local base = {
		userId = 1,
		speed = BigNum.fromNumber(1000),
		playSeconds = 3600,
		isInStation = false,
		spawnedAt = 0,
	}
	for key, value in patch or {} do
		(base :: any)[key] = value
	end
	return base
end

describe("Pvp.refusal", function()
	it("allows two seasoned players in space", function()
		expect(Pvp.refusal(side(), side(), 100, RULES)).toBeNil()
	end)

	it("keeps the station peaceful", function()
		expect(Pvp.refusal(side({ isInStation = true }), side(), 100, RULES)).toBe("AttackerInStation")
		expect(Pvp.refusal(side(), side({ isInStation = true }), 100, RULES)).toBe("VictimInStation")
	end)

	it("protects newbies both ways", function()
		expect(Pvp.refusal(side({ playSeconds = 100 }), side(), 100, RULES)).toBe("AttackerNewbie")
		expect(Pvp.refusal(side(), side({ playSeconds = 1199 }), 100, RULES)).toBe("VictimNewbie")
		expect(Pvp.refusal(side(), side({ playSeconds = 1200 }), 100, RULES)).toBeNil()
	end)

	it("gives a fresh spawn a moment of peace", function()
		expect(Pvp.refusal(side(), side({ spawnedAt = 95 }), 100, RULES)).toBe("VictimJustSpawned")
		expect(Pvp.refusal(side(), side({ spawnedAt = 90 }), 100, RULES)).toBeNil()
	end)

	it("holds back an attacker ten times faster, even at huge stats", function()
		expect(Pvp.refusal(side({ speed = BigNum.fromNumber(9999) }), side(), 100, RULES)).toBeNil()
		expect(Pvp.refusal(side({ speed = BigNum.fromNumber(10000) }), side(), 100, RULES)).toBe("VictimTooWeak")
		local strong = side({ speed = BigNum.new(5, 11) })
		local weak = side({ speed = BigNum.new(4, 10) })
		expect(Pvp.refusal(strong, weak, 100, RULES)).toBe("VictimTooWeak")
		expect(Pvp.refusal(weak, strong, 100, RULES)).toBeNil()
	end)

	it("lets anyone attack a victim with no speed at all", function()
		expect(Pvp.refusal(side(), side({ speed = BigNum.ZERO }), 100, RULES)).toBeNil()
	end)

	describe("an egg you lost", function()
		local strong = side({ userId = 10, speed = BigNum.new(5, 11) })
		local function thief(lostBy: Pvp.LostBy?, patch: { [string]: any }?): Pvp.Side
			local base: { [string]: any } = { userId = 20, speed = BigNum.fromNumber(1000), eggLostBy = lostBy }
			for key, value in patch or {} do
				base[key] = value
			end
			return side(base)
		end

		it("may be won back from a far weaker thief", function()
			expect(Pvp.refusal(strong, thief(Pvp.addLoser(nil, 10)), 100, RULES)).toBeNil()
		end)

		it("does not open up a weak carrier of someone else's egg", function()
			expect(Pvp.refusal(strong, thief(nil), 100, RULES)).toBe("VictimTooWeak")
			expect(Pvp.refusal(strong, thief(Pvp.addLoser(nil, 30)), 100, RULES)).toBe("VictimTooWeak")
		end)

		it("stays yours after it changed hands again", function()
			-- You lost it, the thief lost it to a third player, who lost it back to the thief.
			local lostBy = Pvp.addLoser(Pvp.addLoser(Pvp.addLoser(nil, 10), 20), 30)
			expect(Pvp.refusal(strong, thief(lostBy), 100, RULES)).toBeNil()
		end)

		it("keeps the newbie, spawn and station protection", function()
			local lostBy = Pvp.addLoser(nil, 10)
			expect(Pvp.refusal(strong, thief(lostBy, { playSeconds = 100 }), 100, RULES)).toBe("VictimNewbie")
			expect(Pvp.refusal(strong, thief(lostBy, { spawnedAt = 95 }), 100, RULES)).toBe("VictimJustSpawned")
			expect(Pvp.refusal(strong, thief(lostBy, { isInStation = true }), 100, RULES)).toBe("VictimInStation")
		end)
	end)
end)

describe("Pvp.addLoser", function()
	it("adds to a new set and leaves the old one as it was", function()
		local first = Pvp.addLoser(nil, 10)
		local second = Pvp.addLoser(first, 20)
		expect(Pvp.lostIt(first, 10)).toBe(true)
		expect(Pvp.lostIt(first, 20)).toBe(false)
		expect(Pvp.lostIt(second, 10)).toBe(true)
		expect(Pvp.lostIt(second, 20)).toBe(true)
	end)

	it("knows nobody when the egg was never lost", function()
		expect(Pvp.lostIt(nil, 10)).toBe(false)
	end)
end)

describe("Pvp.creatureRefusal", function()
	it("lets anyone in space attack a creature, newbies included", function()
		expect(Pvp.creatureRefusal(side({ playSeconds = 0 }))).toBeNil()
		expect(Pvp.creatureRefusal(side({ speed = BigNum.fromNumber(1) }))).toBeNil()
	end)

	it("keeps the station a safe zone", function()
		expect(Pvp.creatureRefusal(side({ isInStation = true }))).toBe("AttackerInStation")
	end)
end)
