--!strict

local LaunchMetrics = require("../../src/shared/Domain/LaunchMetrics")
local MetricsConfig = require("../../src/shared/Config/MetricsConfig")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local FROM, TO = MetricsConfig.WALL_FROM_POST, MetricsConfig.WALL_TO_POST
local HOUR = 60 * 60

describe("LaunchMetrics ranges", function()
	it("puts a time in the range below its limit, the last one open", function()
		local ranges = MetricsConfig.SESSION_RANGES
		expect(LaunchMetrics.rangeOf(0, ranges)).toBe("0-1 min")
		expect(LaunchMetrics.rangeOf(59.9, ranges)).toBe("0-1 min")
		expect(LaunchMetrics.rangeOf(60, ranges)).toBe("1-3 min")
		expect(LaunchMetrics.rangeOf(179, ranges)).toBe("1-3 min")
		expect(LaunchMetrics.rangeOf(180, ranges)).toBe("3-10 min")
		expect(LaunchMetrics.rangeOf(10 * HOUR, ranges)).toBe("2 h+")
	end)

	it("splits sessions at three minutes, the stop signal of decision 126", function()
		local under = LaunchMetrics.rangeOf(3 * 60 - 1, MetricsConfig.SESSION_RANGES)
		local over = LaunchMetrics.rangeOf(3 * 60, MetricsConfig.SESSION_RANGES)
		expect(under).never.toBe(over)
	end)

	it("keeps every range list rising and open at the end", function()
		for _, ranges in
			{ MetricsConfig.SESSION_RANGES, MetricsConfig.WALL_REAL_RANGES, MetricsConfig.WALL_PLAY_RANGES }
		do
			for index = 2, #ranges do
				expect(ranges[index].limit > ranges[index - 1].limit).toBe(true)
			end
			expect(ranges[#ranges].limit).toBe(math.huge)
		end
	end)
end)

describe("LaunchMetrics session fields", function()
	it("names the best post, the goal and the length of a first session", function()
		local fields = LaunchMetrics.sessionFields(0, 1, true, 100)
		expect(fields).toEqual({ "Best - 0", "Goal - 1", "First - 1-3 min" })
	end)

	it("marks a later session and a player with every guardian in reach", function()
		local fields = LaunchMetrics.sessionFields(24, nil, false, 2 * HOUR + 1)
		expect(fields).toEqual({ "Best - 24", "Goal - None", "Return - 2 h+" })
	end)

	it("keeps each field within Roblox's three", function()
		expect(#LaunchMetrics.sessionFields(5, 7, false, 0) <= 3).toBe(true)
		expect(#LaunchMetrics.wallFields({ realSeconds = 0, playSeconds = 0 }) <= 3).toBe(true)
	end)
end)

describe("LaunchMetrics day-1 wall", function()
	it("starts on the first delivery from its first post and reports on its last", function()
		local wall = LaunchMetrics.emptyWall()
		expect(LaunchMetrics.passWall(wall, FROM - 1, FROM, 1000, 5000)).toBeNil()
		expect(wall).toEqual({ startedAt = 1000, startedPlaySeconds = 5000 })
		local crossing = LaunchMetrics.passWall(wall, FROM, TO, 1000 + 20 * HOUR, 5000 + 1800)
		expect(crossing).toEqual({ realSeconds = 20 * HOUR, playSeconds = 1800 })
	end)

	it("survives a rejoin: the start lives in the profile record", function()
		local wall = LaunchMetrics.emptyWall()
		LaunchMetrics.passWall(wall, 3, FROM, 500, 4000)
		-- A later session finds the same record (saved and loaded).
		local loaded = { startedAt = wall.startedAt, startedPlaySeconds = wall.startedPlaySeconds }
		local crossing = LaunchMetrics.passWall(loaded, FROM, TO + 2, 500 + 30 * HOUR, 4000 + 2 * HOUR)
		expect(crossing).toEqual({ realSeconds = 30 * HOUR, playSeconds = 2 * HOUR })
	end)

	it("takes no time when one egg passes the whole wall", function()
		local wall = LaunchMetrics.emptyWall()
		local crossing = LaunchMetrics.passWall(wall, FROM - 2, TO + 1, 700, 3000)
		expect(crossing).toEqual({ realSeconds = 0, playSeconds = 0 })
	end)

	it("does not restart once started, and reports nothing before or past the wall", function()
		local wall = { startedAt = 100, startedPlaySeconds = 10 }
		expect(LaunchMetrics.passWall(wall, 1, 2, 200, 20)).toBeNil()
		expect(LaunchMetrics.passWall(wall, TO, TO + 1, 300, 30)).toBeNil()
		expect(wall).toEqual({ startedAt = 100, startedPlaySeconds = 10 })
	end)

	it("reports nothing for a wall started before it was measured", function()
		local wall = LaunchMetrics.emptyWall()
		expect(LaunchMetrics.passWall(wall, FROM, TO, 900, 9000)).toBeNil()
		expect(wall.startedAt).toBe(0)
	end)

	it("sorts the wall's times into labelled ranges", function()
		local fields = LaunchMetrics.wallFields({ realSeconds = 20 * HOUR, playSeconds = 45 * 60 })
		expect(fields).toEqual({ "Real - 4-24 h", "Play - 30-60 min" })
	end)
end)
