--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local SpeedGoal = require("../../src/shared/Domain/SpeedGoal")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local n = BigNum.fromNumber
local RECOMMENDED = { n(10), n(100), n(1000) }

describe("SpeedGoal.next", function()
	it("is the first guardian the player cannot outrun yet", function()
		local goal = SpeedGoal.next(n(50), RECOMMENDED)
		expect(goal ~= nil).toBe(true)
		if goal then
			expect(goal.post).toBe(2)
			expect(BigNum.equals(goal.target, n(100))).toBe(true)
		end
	end)

	it("counts reaching the recommended stat as within reach", function()
		local goal = SpeedGoal.next(n(100), RECOMMENDED)
		expect(goal and goal.post).toBe(3)
	end)

	it("is nil once every guardian is within reach", function()
		expect(SpeedGoal.next(n(5000), RECOMMENDED)).toBeNil()
	end)

	it("starts at the first guardian for a stat below it", function()
		local goal = SpeedGoal.next(n(3), RECOMMENDED)
		expect(goal and goal.post).toBe(1)
	end)
end)

describe("SpeedGoal.progress", function()
	it("measures the way from the post before to the goal on the log scale", function()
		expect(SpeedGoal.progress(n(10), n(10), n(100))).toBeCloseTo(0)
		expect(SpeedGoal.progress(n(31.6228), n(10), n(100))).toBeCloseTo(0.5, 1e-4)
		expect(SpeedGoal.progress(n(100), n(10), n(100))).toBeCloseTo(1)
	end)

	it("stays within 0..1", function()
		expect(SpeedGoal.progress(n(1), n(10), n(100))).toBe(0)
		expect(SpeedGoal.progress(n(1e6), n(10), n(100))).toBe(1)
	end)

	it("counts from 1 for the first goal", function()
		expect(SpeedGoal.progress(n(3.1623), nil, n(10))).toBeCloseTo(0.5, 1e-4)
	end)
end)
