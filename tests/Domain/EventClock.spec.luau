--!strict

local EventClock = require("../../src/shared/Domain/EventClock")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local SCHEDULE: EventClock.Schedule = { gapMin = 300, gapMax = 300, warningSeconds = 10, activeSeconds = 15 }

local function fixed(): number
	return 0.5
end

describe("EventClock", function()
	it("stays quiet for the gap less the warning", function()
		expect(EventClock.idle(1000, SCHEDULE, fixed)).toEqual({ phase = "Idle", endsAt = 1290 })
	end)

	it("goes quiet, warning, active and round again", function()
		local clock = EventClock.idle(0, SCHEDULE, fixed)
		local entered
		clock, entered = EventClock.step(clock, 289, SCHEDULE, fixed)
		expect(entered).toEqual({})
		clock, entered = EventClock.step(clock, 290, SCHEDULE, fixed)
		expect(entered).toEqual({ "Warning" })
		expect(clock.endsAt).toBe(300)
		clock, entered = EventClock.step(clock, 300, SCHEDULE, fixed)
		expect(entered).toEqual({ "Active" })
		expect(clock.endsAt).toBe(315)
		clock, entered = EventClock.step(clock, 315, SCHEDULE, fixed)
		expect(entered).toEqual({ "Idle" })
		-- The next one starts a full gap after this one ended.
		expect(clock.endsAt).toBe(315 + 290)
	end)

	it("goes through every phase a long pause skipped", function()
		local clock = EventClock.idle(0, SCHEDULE, fixed)
		local _, entered = EventClock.step(clock, 320, SCHEDULE, fixed)
		expect(entered).toEqual({ "Warning", "Active", "Idle" })
	end)

	it("picks the gap between its bounds", function()
		local wide: EventClock.Schedule = { gapMin = 100, gapMax = 200, warningSeconds = 0, activeSeconds = 5 }
		expect(EventClock.idle(0, wide, function()
			return 0
		end).endsAt).toBe(100)
		expect(EventClock.idle(0, wide, function()
			return 1
		end).endsAt).toBe(200)
	end)

	it("starts an event at once when asked", function()
		expect(EventClock.activate(50, SCHEDULE)).toEqual({ phase = "Active", endsAt = 65 })
	end)
end)
