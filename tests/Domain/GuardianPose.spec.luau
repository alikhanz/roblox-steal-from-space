--!strict

local roblox = require("@lune/roblox")

local GuardianPose = require("../../src/shared/Domain/GuardianPose")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- @lune/roblox typedefs do not declare datatypes; the global Vector3 type describes it.
local Vector3 = (roblox :: any).Vector3 :: typeof(Vector3)

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

	it("follows a body on a steady course right on it", function()
		-- The body moves +X at 30 studs a second; the model drawn on it keeps on it.
		local velocity = Vector3.new(30, 0, 0)
		local drawn = Vector3.new(0, 0, 0)
		for frame = 1, 60 do
			drawn = GuardianPose.follow(drawn, velocity, velocity * (frame / 60), 1 / 60, 0.25)
		end
		expect((drawn - velocity).Magnitude).toBeCloseTo(0, 1e-6)
	end)

	it("spreads a jump of the body over its time instead of jumping with it", function()
		local still = Vector3.new(0, 0, 0)
		local target = Vector3.new(1, 0, 0)
		-- One frame makes up a small part of the gap ...
		local first = GuardianPose.follow(still, still, target, 1 / 60, 0.25)
		expect(first.X > 0 and first.X < 0.2).toBe(true)
		-- ... and its time most of it, whatever the frame rate.
		local function run(frames: number): number
			local drawn = still
			for _ = 1, frames do
				drawn = GuardianPose.follow(drawn, still, target, 0.25 / frames, 0.25)
			end
			return drawn.X
		end
		expect(run(15)).toBeCloseTo(0.95, 1e-2)
		-- Vector3 holds 32-bit floats.
		expect(run(60)).toBeCloseTo(run(15), 1e-6)
	end)

	it("wears the model from the least distance, a big guardian from farther", function()
		-- A slime 6 studs long: the least distance, past its half length.
		expect(GuardianPose.wearReach(6, 700, 60)).toBe(703)
		-- A whale 24 studs long: 60 of its lengths, so it is no bigger than 1/60 rad there.
		local whale = GuardianPose.wearReach(24, 700, 60)
		expect(whale).toBe(1452)
		expect(24 / (whale - 12)).toBeCloseTo(1 / 60, 1e-12)
	end)

	it("puts the model on within reach and takes it off only past the margin", function()
		expect(GuardianPose.wears(false, 700, 700, 100)).toBe(true)
		expect(GuardianPose.wears(false, 701, 700, 100)).toBe(false)
		-- Worn: kept through the margin, so a camera on the line does not swap it back and forth.
		expect(GuardianPose.wears(true, 750, 700, 100)).toBe(true)
		expect(GuardianPose.wears(true, 800, 700, 100)).toBe(true)
		expect(GuardianPose.wears(true, 801, 700, 100)).toBe(false)
	end)
end)

describe("GuardianPose.labelFade", function()
	it("is clear up to the start and fully faded from the finish on", function()
		expect(GuardianPose.labelFade(10, 300, 900, 0.8)).toBe(0)
		expect(GuardianPose.labelFade(300, 300, 900, 0.8)).toBe(0)
		expect(GuardianPose.labelFade(900, 300, 900, 0.8)).toBeCloseTo(0.8, 1e-9)
		expect(GuardianPose.labelFade(5000, 300, 900, 0.8)).toBeCloseTo(0.8, 1e-9)
	end)

	it("fades evenly between", function()
		expect(GuardianPose.labelFade(600, 300, 900, 0.8)).toBeCloseTo(0.4, 1e-9)
	end)
end)

describe("GuardianPose.labelSize", function()
	it("keeps its size between near and far", function()
		expect(GuardianPose.labelSize(55, 55, 160)).toBe(1)
		expect(GuardianPose.labelSize(100, 55, 160)).toBe(1)
		expect(GuardianPose.labelSize(160, 55, 160)).toBe(1)
	end)

	it("keeps its size on screen nearer than near and farther than far", function()
		expect(GuardianPose.labelSize(11, 55, 160)).toBeCloseTo(0.2, 1e-9)
		expect(GuardianPose.labelSize(480, 55, 160)).toBeCloseTo(3, 1e-9)
	end)
end)

describe("GuardianPose.labelSizeMoved", function()
	it("redraws on a visible change or a return to its own size", function()
		expect(GuardianPose.labelSizeMoved(2, 2.01, 0.02)).toBe(false)
		expect(GuardianPose.labelSizeMoved(2, 2.1, 0.02)).toBe(true)
		expect(GuardianPose.labelSizeMoved(1.01, 1, 0.02)).toBe(true)
		expect(GuardianPose.labelSizeMoved(1, 1, 0.02)).toBe(false)
	end)
end)
