--!strict

local GuardianPose = require("../../src/shared/Domain/GuardianPose")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("GuardianPose", function()
	it("scales a model to its kind's length times its post's scale", function()
		-- A whale model 4 studs long in a 24-stud box, at a calf's 0.6.
		expect(GuardianPose.fitScale(4, 24, 0.6)).toBeCloseTo(3.6, 1e-9)
		expect(GuardianPose.fitScale(12, 12, 1)).toBe(1)
	end)

	it("refuses a model with no size", function()
		expect(function()
			GuardianPose.fitScale(0, 6, 1)
		end).toThrow()
	end)

	it("eases the pace most of the way within its time, whatever the frame rate", function()
		local function run(frames: number): number
			local value = 0
			for _ = 1, frames do
				value = GuardianPose.ease(value, 1, 0.6 / frames, 0.6)
			end
			return value
		end
		expect(run(10)).toBeCloseTo(0.95, 1e-2)
		expect(run(60)).toBeCloseTo(run(10), 1e-9)
		-- Never past the target.
		expect(GuardianPose.ease(0, 1, 10, 0.6) <= 1).toBe(true)
		expect(GuardianPose.ease(0.3, 1, 0.1, 0)).toBe(1)
	end)

	it("lunges out quickly and back slower, the jaw snapping open and shut", function()
		expect(select(1, GuardianPose.strike(-0.1, 0.35))).toBe(0)
		expect(select(1, GuardianPose.strike(0.35, 0.35))).toBe(0)
		local furthest = GuardianPose.strike(0.3 * 0.35, 0.35)
		expect(furthest).toBeCloseTo(1, 1e-9)
		local early = GuardianPose.strike(0.05, 0.35)
		local late = GuardianPose.strike(0.35 - 0.05, 0.35)
		-- Out in a third of the time the way back takes.
		expect(early > late).toBe(true)
		local _, jawMiddle = GuardianPose.strike(0.175, 0.35)
		local _, jawEnd = GuardianPose.strike(0.349, 0.35)
		expect(jawMiddle).toBeCloseTo(1, 1e-9)
		expect(jawEnd < 0.05).toBe(true)
	end)
end)
