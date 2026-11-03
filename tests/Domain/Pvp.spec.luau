--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Pvp = require("../../src/shared/Domain/Pvp")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local RULES: Pvp.Rules = { newbieSeconds = 1200, spawnGraceSeconds = 10, maxSpeedRatio = 10 }

local function side(patch: { [string]: any }?): Pvp.Side
	local base = {
		speed = BigNum.fromNumber(1000),
		playSeconds = 3600,
		isInStation = false,
		spawnedAt = 0,
		shieldUntil = 0,
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

	it("gives a fresh spawn and a shield a moment of peace", function()
		expect(Pvp.refusal(side(), side({ spawnedAt = 95 }), 100, RULES)).toBe("VictimJustSpawned")
		expect(Pvp.refusal(side(), side({ spawnedAt = 90 }), 100, RULES)).toBeNil()
		expect(Pvp.refusal(side(), side({ shieldUntil = 101 }), 100, RULES)).toBe("VictimShielded")
		expect(Pvp.refusal(side(), side({ shieldUntil = 100 }), 100, RULES)).toBeNil()
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
end)
