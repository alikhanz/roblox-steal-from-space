--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Oxygen = require("../../src/shared/Domain/Oxygen")
local Speed = require("../../src/shared/Domain/Speed")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: Oxygen.Tuning = { drainPerSecond = 2, refillPerSecond = 10 }

describe("Oxygen", function()
	it("drains in space", function()
		expect(Oxygen.step(50, 100, true, 1, TUNING)).toBe(48)
	end)

	it("refills under the dome", function()
		expect(Oxygen.step(50, 100, false, 1, TUNING)).toBe(60)
	end)

	it("stays within the tank", function()
		expect(Oxygen.step(1, 100, true, 5, TUNING)).toBe(0)
		expect(Oxygen.step(99, 100, false, 5, TUNING)).toBe(100)
	end)

	it("a hit takes its share of a full tank", function()
		expect(Oxygen.afterHit(100, 180, 0.1)).toBeCloseTo(82)
		expect(Oxygen.afterHit(180, 180, 0)).toBe(180)
	end)

	it("a hit on a nearly empty tank empties it", function()
		expect(Oxygen.afterHit(10, 180, 0.1)).toBe(0)
		expect(Oxygen.isEmpty(Oxygen.afterHit(18, 180, 0.1))).toBe(true)
	end)

	describe("catchShare", function()
		local SHARES: Oxygen.CatchShares = { weak = 0.05, fair = 0.1, strong = 0.35, tooStrong = 0.9 }
		local CHASE: Speed.ChaseTuning = { ratioExponent = 0.5, minRatio = 0.6, maxRatio = 1.5 }

		-- The share a thief with `stat` loses to a hunter recommending 1000.
		local function share(stat: number): number
			local recommended = BigNum.fromNumber(1000)
			local thief = BigNum.fromNumber(stat)
			return Oxygen.catchShare(
				Speed.challenge(thief, recommended, CHASE, 1),
				Speed.standing(thief, recommended, CHASE, 1),
				SHARES
			)
		end

		it("takes the tier's end at its edges", function()
			expect(share(10000)).toBeCloseTo(0.05)
			expect(share(1e12)).toBe(0.05)
			expect(share(1000)).toBeCloseTo(0.1)
			expect(share(1000 / 2.25)).toBe(0.9)
			expect(share(1)).toBe(0.9)
			expect(share(0)).toBe(0.9)
		end)

		it("grows smoothly inside Fair, from weak to fair", function()
			-- Half a tenfold ahead: halfway between the ends.
			expect(share(3162.3)).toBeCloseTo(0.075, 1e-4)
			expect(share(9999) > 0.05 and share(9999) < 0.051).toBe(true)
			expect(share(1001) < 0.1 and share(1001) > 0.099).toBe(true)
		end)

		it("grows smoothly inside Strong, from fair to strong, then jumps to the skull", function()
			expect(share(999) > 0.1 and share(999) < 0.101).toBe(true)
			-- Halfway to the skull on the log scale (1.5 of the 2.25 ratio).
			expect(share(1000 / 1.5)).toBeCloseTo(0.225, 1e-6)
			expect(share(1000 / 2.2) > 0.34 and share(1000 / 2.2) < 0.35).toBe(true)
		end)

		it("never takes less from a weaker thief", function()
			local last = 0
			for decades = 2, -2, -0.05 do
				local value = share(1000 * 10 ^ decades)
				expect(value >= last).toBe(true)
				last = value
			end
		end)

		it("agrees with the pill: each tier costs at most its end", function()
			for decades = 2, -2, -0.05 do
				local stat = BigNum.fromNumber(1000 * 10 ^ decades)
				local challenge = Speed.challenge(stat, BigNum.fromNumber(1000), CHASE, 1)
				local most = if challenge == "Weak"
					then SHARES.weak
					elseif challenge == "Fair" then SHARES.fair
					elseif challenge == "Strong" then SHARES.strong
					else SHARES.tooStrong
				expect(share(1000 * 10 ^ decades) <= most + 1e-9).toBe(true)
			end
		end)

		it("a catch past the skull leaves a tenth of a full tank at most", function()
			expect(Oxygen.afterHit(180, 180, share(1))).toBeCloseTo(18)
			expect(Oxygen.isEmpty(Oxygen.afterHit(100, 180, share(1)))).toBe(true)
		end)
	end)

	it("reports an empty tank", function()
		expect(Oxygen.isEmpty(0)).toBe(true)
		expect(Oxygen.isEmpty(0.01)).toBe(false)
	end)

	it("reports the fill fraction", function()
		expect(Oxygen.fraction(25, 100)).toBe(0.25)
		expect(Oxygen.fraction(150, 100)).toBe(1)
		expect(Oxygen.fraction(10, 0)).toBe(0)
	end)
end)
