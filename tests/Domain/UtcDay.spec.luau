--!strict

local Test = require("../../lune/lib/Test")
local UtcDay = require("../../src/shared/Domain/UtcDay")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("UtcDay", function()
	it("counts UTC days from the epoch", function()
		expect(UtcDay.of(0)).toBe(0)
		expect(UtcDay.of(86399)).toBe(0)
		expect(UtcDay.of(86400)).toBe(1)
	end)

	it("counts the seconds left to midnight", function()
		expect(UtcDay.secondsLeft(86400 * 5 + 600)).toBe(86400 - 600)
	end)
end)
