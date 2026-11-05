--!strict

local LoginGift = require("../../src/shared/Domain/LoginGift")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local LENGTH = 7
local TODAY = 20000

local function state(lastDay: number, streak: number): LoginGift.State
	return { lastDay = lastDay, streak = streak }
end

describe("LoginGift.status", function()
	it("offers day 1 to a new player who has delivered, not as a reset", function()
		expect(LoginGift.status(LoginGift.empty(), TODAY, LENGTH, true)).toEqual({
			available = true,
			day = 1,
			reset = false,
			locked = false,
		})
	end)

	it("keeps the first gift locked until the first delivery", function()
		expect(LoginGift.status(LoginGift.empty(), TODAY, LENGTH, false)).toEqual({
			available = false,
			day = 1,
			reset = false,
			locked = true,
		})
	end)

	it("moves on the day after", function()
		expect(LoginGift.status(state(TODAY - 1, 3), TODAY, LENGTH, true)).toEqual({
			available = true,
			day = 4,
			reset = false,
			locked = false,
		})
	end)

	it("starts a new round after the last day", function()
		expect(LoginGift.status(state(TODAY - 1, 7), TODAY, LENGTH, true).day).toBe(1)
	end)

	it("starts over after a missed day", function()
		expect(LoginGift.status(state(TODAY - 2, 5), TODAY, LENGTH, true)).toEqual({
			available = true,
			day = 1,
			reset = true,
			locked = false,
		})
	end)

	it("has nothing more once today's gift is taken", function()
		expect(LoginGift.status(state(TODAY, 4), TODAY, LENGTH, true)).toEqual({
			available = false,
			day = 4,
			reset = false,
			locked = false,
		})
	end)

	it("starts over when the clock went back", function()
		expect(LoginGift.status(state(TODAY + 3, 2), TODAY, LENGTH, true).day).toBe(1)
	end)
end)

describe("LoginGift.claim", function()
	it("takes today's gift once", function()
		local gift = state(TODAY - 1, 2)
		expect(LoginGift.claim(gift, TODAY, LENGTH, true)).toBe(3)
		expect(gift).toEqual(state(TODAY, 3))
		expect(LoginGift.claim(gift, TODAY, LENGTH, true)).toBeNil()
		expect(gift).toEqual(state(TODAY, 3))
	end)

	it("gives nothing before the first delivery", function()
		local gift = LoginGift.empty()
		expect(LoginGift.claim(gift, TODAY, LENGTH, false)).toBeNil()
		expect(gift).toEqual(LoginGift.empty())
	end)

	it("walks a whole streak and round again", function()
		local gift = LoginGift.empty()
		local days = {}
		for offset = 0, 8 do
			table.insert(days, LoginGift.claim(gift, TODAY + offset, LENGTH, true))
		end
		expect(days).toEqual({ 1, 2, 3, 4, 5, 6, 7, 1, 2 })
	end)

	it("starts at day 1 after a gap", function()
		local gift = state(TODAY - 3, 6)
		expect(LoginGift.claim(gift, TODAY, LENGTH, true)).toBe(1)
	end)
end)
