--!strict

local Activity = require("../../src/shared/Domain/Activity")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TUNING: Activity.Tuning = { MOVE_STUDS = 10, IDLE_SECONDS = 180 }

describe("Activity", function()
	it("counts a player who just joined as active", function()
		local state = Activity.new(100)
		expect(Activity.isActive(state, 100, TUNING)).toBe(true)
		expect(Activity.idleSeconds(state, 150)).toBe(50)
	end)

	it("goes away after the idle time with nothing done", function()
		local state = Activity.new(0)
		expect(Activity.isActive(state, 179, TUNING)).toBe(true)
		expect(Activity.isActive(state, 180, TUNING)).toBe(false)
	end)

	it("comes back on a command", function()
		local state = Activity.new(0)
		Activity.touch(state, 500)
		expect(Activity.isActive(state, 600, TUNING)).toBe(true)
	end)

	it("counts going somewhere, not fidgeting around one spot", function()
		local state = Activity.new(0)
		Activity.observe(state, 10, 0, 0, 0, TUNING)
		-- A jump in place and a small step: still at the anchor.
		Activity.observe(state, 200, 0, 7, 0, TUNING)
		Activity.observe(state, 210, 5, 0, 5, TUNING)
		expect(Activity.isActive(state, 210, TUNING)).toBe(false)
		-- A few steps away.
		Activity.observe(state, 220, 12, 0, 0, TUNING)
		expect(Activity.isActive(state, 220, TUNING)).toBe(true)
		expect(Activity.idleSeconds(state, 230)).toBe(10)
	end)

	it("measures from where the player last moved to", function()
		local state = Activity.new(0)
		Activity.observe(state, 0, 0, 0, 0, TUNING)
		Activity.observe(state, 50, 12, 0, 0, TUNING)
		-- 6 studs from the new anchor, 18 from the old one: not a move.
		Activity.observe(state, 100, 18, 0, 0, TUNING)
		expect(Activity.idleSeconds(state, 100)).toBe(50)
	end)

	it("does not count a respawn somewhere else as moving", function()
		local state = Activity.new(0)
		Activity.observe(state, 0, 0, 0, 0, TUNING)
		Activity.forgetAnchor(state)
		Activity.observe(state, 300, 2000, 0, 0, TUNING)
		expect(Activity.isActive(state, 300, TUNING)).toBe(false)
	end)
end)
