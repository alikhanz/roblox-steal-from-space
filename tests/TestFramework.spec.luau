--!strict
-- Guards the test framework itself: if these fail, no other spec result can be trusted.

local Test = require("../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Test framework", function()
	it("compares primitives with toBe", function()
		expect(1 + 1).toBe(2)
		expect("a").never.toBe("b")
	end)

	it("compares tables structurally with toEqual", function()
		expect({ a = 1, b = { 2, 3 } }).toEqual({ a = 1, b = { 2, 3 } })
		expect({ a = 1 }).never.toEqual({ a = 1, b = 2 })
	end)

	it("compares floats with a tolerance", function()
		expect(0.1 + 0.2).toBeCloseTo(0.3)
		expect(1.5).never.toBeCloseTo(1.6, 0.01)
	end)

	it("detects thrown errors", function()
		expect(function()
			error("boom")
		end).toThrow("boom")
		expect(function() end).never.toThrow()
	end)

	it("reports a failed expectation as an error", function()
		expect(function()
			expect(1).toBe(2)
		end).toThrow("Expected: 1 to be 2")
	end)
end)
