--!strict

local NestCycle = require("../../src/shared/Domain/NestCycle")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local RESPAWN = 20

local function away(): NestCycle.State
	return NestCycle.take(NestCycle.inNest()) :: NestCycle.State
end

describe("NestCycle", function()
	it("lets the egg be taken only while it is in the nest", function()
		local taken = NestCycle.take(NestCycle.inNest())
		expect(taken and taken.kind).toBe("Away")
		expect(NestCycle.take(away())).toBe(nil)
	end)

	it("grows nothing while the egg is away, however long", function()
		expect(NestCycle.shouldGrow(away(), 1e9)).toBe(false)
	end)

	it("grows a new egg some time after the old one is delivered", function()
		local regrowing = NestCycle.delivered(away(), 100, RESPAWN)
		expect(regrowing.kind).toBe("Regrowing")
		expect(NestCycle.shouldGrow(regrowing, 119)).toBe(false)
		expect(NestCycle.shouldGrow(regrowing, 120)).toBe(true)
	end)

	it("ignores a delivery when the nest's own egg is not away", function()
		local inNest = NestCycle.inNest()
		expect(NestCycle.delivered(inNest, 100, RESPAWN).kind).toBe("InNest")
		local regrowing = NestCycle.delivered(away(), 100, RESPAWN)
		expect(NestCycle.delivered(regrowing, 500, RESPAWN)).toBe(regrowing)
	end)

	it("takes back an egg that was never delivered", function()
		local returned = NestCycle.returned(away())
		expect(returned and returned.kind).toBe("InNest")
	end)

	it("refuses a returning egg when the nest already holds one", function()
		expect(NestCycle.returned(NestCycle.inNest())).toBe(nil)
	end)

	it("takes back a returning egg while regrowing instead of growing another", function()
		local regrowing = NestCycle.delivered(away(), 100, RESPAWN)
		local returned = NestCycle.returned(regrowing)
		expect(returned and returned.kind).toBe("InNest")
	end)
end)
