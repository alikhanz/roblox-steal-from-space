--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Speed = require("../../src/shared/Domain/Speed")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local n = BigNum.fromNumber

local FLIGHT: Speed.FlightTuning = {
	referenceSpeed = 10,
	referenceFlightSpeed = 48,
	flightSpeedPerDecade = 8.2,
	minFlightSpeed = 30,
}

local CHASE: Speed.ChaseTuning = {
	ratioExponent = 0.5,
	minRatio = 0.6,
	maxRatio = 1.5,
}

describe("Speed.flightSpeed", function()
	it("flies at the reference speed with the reference stat", function()
		expect(Speed.flightSpeed(n(10), FLIGHT)).toBeCloseTo(48, 1e-9)
	end)

	it("gains the same amount per tenfold increase", function()
		expect(Speed.flightSpeed(n(100), FLIGHT)).toBeCloseTo(56.2, 1e-9)
		expect(Speed.flightSpeed(n(1e11), FLIGHT)).toBeCloseTo(130, 1e-9)
		expect(Speed.flightSpeed(BigNum.new(1, 400), FLIGHT)).toBeCloseTo(48 + 399 * 8.2, 1e-6)
	end)

	it("never drops below the minimum", function()
		expect(Speed.flightSpeed(n(0.001), FLIGHT)).toBe(30)
		expect(Speed.flightSpeed(BigNum.ZERO, FLIGHT)).toBe(30)
	end)
end)

describe("Speed.eggWeight", function()
	it("multiplies rarity weight by the size factor", function()
		expect(Speed.eggWeight(0.28, 1.4)).toBeCloseTo(0.392, 1e-9)
	end)

	it("caps the weight so an egg never stops the thief", function()
		expect(Speed.eggWeight(1, 1.4)).toBeCloseTo(0.7, 1e-9)
	end)
end)

describe("Speed.carryMultiplier", function()
	it("keeps the rest of the stat", function()
		expect(Speed.carryMultiplier(0.25)).toBeCloseTo(0.75, 1e-9)
		expect(Speed.carryMultiplier(0)).toBe(1)
		expect(Speed.carryMultiplier(1)).toBeCloseTo(0.3, 1e-9)
	end)
end)

describe("Speed.withEgg", function()
	it("scales the stat by the carry multiplier", function()
		expect(BigNum.toNumber(Speed.withEgg(n(100), 0.25))).toBeCloseTo(75, 1e-9)
	end)
end)

describe("Speed.chaseSpeed", function()
	it("flies level with a thief of equal stat", function()
		expect(Speed.chaseSpeed(50, n(100), n(100), CHASE)).toBeCloseTo(50, 1e-9)
	end)

	it("softens the ratio by the exponent", function()
		-- 1.21x the stat, square root: 1.1x the flight speed.
		expect(Speed.chaseSpeed(50, n(121), n(100), CHASE)).toBeCloseTo(55, 1e-9)
	end)

	it("clamps far-apart stats", function()
		expect(Speed.chaseSpeed(50, n(400), n(100), CHASE)).toBeCloseTo(75, 1e-9)
		expect(Speed.chaseSpeed(50, n(25), n(100), CHASE)).toBeCloseTo(30, 1e-9)
	end)

	it("stays finite for huge stats", function()
		expect(Speed.chaseSpeed(50, BigNum.new(1, 400), BigNum.new(1, 399), CHASE)).toBeCloseTo(75, 1e-9)
	end)

	it("treats a thief without a stat as slowest", function()
		expect(Speed.chaseSpeed(50, n(100), BigNum.ZERO, CHASE)).toBeCloseTo(75, 1e-9)
	end)
end)

describe("Speed.recommended", function()
	it("is the stat that flies level with the guardian carrying a typical egg", function()
		local recommended = Speed.recommended(n(100), 0.25)
		expect(BigNum.toNumber(recommended)).toBeCloseTo(100 / 0.75, 1e-9)
		expect(BigNum.toNumber(Speed.withEgg(recommended, 0.25))).toBeCloseTo(100, 1e-9)
	end)
end)

describe("Speed.standing", function()
	-- At maxRatio 1.5 and exponent 0.5 the guardian is at its fastest 2.25 times below its stat.
	local chase: Speed.ChaseTuning = { ratioExponent = 0.5, minRatio = 0.6, maxRatio = 1.5 }

	it("is level at the recommended stat", function()
		expect(Speed.standing(n(1000), n(1000), chase, 1)).toBeCloseTo(0)
	end)

	it("reaches -1 where the guardian flies its fastest, and stays there", function()
		expect(Speed.standing(n(1000 / 2.25), n(1000), chase, 1)).toBeCloseTo(-1)
		expect(Speed.standing(n(1), n(1000), chase, 1)).toBe(-1)
		local halfway = Speed.standing(n(1000 / 1.5), n(1000), chase, 1)
		expect(halfway).toBeCloseTo(-0.5)
	end)

	it("reaches 1 at greenDecades tenfolds above, and stays there", function()
		expect(Speed.standing(n(10000), n(1000), chase, 1)).toBeCloseTo(1)
		expect(Speed.standing(n(1e9), n(1000), chase, 1)).toBe(1)
		expect(Speed.standing(n(3162.3), n(1000), chase, 1)).toBeCloseTo(0.5, 1e-3)
	end)

	it("works on huge stats", function()
		expect(Speed.standing(BigNum.new(1, 40), BigNum.new(1, 40), chase, 1)).toBeCloseTo(0)
	end)
end)

describe("Speed.challenge", function()
	local chase: Speed.ChaseTuning = { ratioExponent = 0.5, minRatio = 0.6, maxRatio = 1.5 }

	it("is Fair from the recommended stat up to weakDecades above", function()
		expect(Speed.challenge(n(1000), n(1000), chase, 1)).toBe("Fair")
		expect(Speed.challenge(n(9000), n(1000), chase, 1)).toBe("Fair")
	end)

	it("is Weak weakDecades tenfolds above and beyond", function()
		expect(Speed.challenge(n(10000), n(1000), chase, 1)).toBe("Weak")
		expect(Speed.challenge(n(1e12), n(1000), chase, 1)).toBe("Weak")
	end)

	it("is Strong just below the recommended stat", function()
		expect(Speed.challenge(n(999), n(1000), chase, 1)).toBe("Strong")
		expect(Speed.challenge(n(1000 / 2.2), n(1000), chase, 1)).toBe("Strong")
	end)

	it("is TooStrong where the guardian flies its fastest against the thief", function()
		expect(Speed.challenge(n(1000 / 2.25), n(1000), chase, 1)).toBe("TooStrong")
		expect(Speed.challenge(n(1), n(1000), chase, 1)).toBe("TooStrong")
		expect(Speed.challenge(n(0), n(1000), chase, 1)).toBe("TooStrong")
	end)

	it("works on huge stats", function()
		expect(Speed.challenge(BigNum.new(1, 40), BigNum.new(1, 40), chase, 1)).toBe("Fair")
		expect(Speed.challenge(BigNum.new(1, 39), BigNum.new(1, 40), chase, 1)).toBe("TooStrong")
	end)
end)
