--!strict

local Scheduler = require("../../src/shared/Runtime/Scheduler")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Scheduler", function()
	it("runs a job once its interval has passed, with the elapsed time", function()
		local scheduler = Scheduler.new()
		local runs: { number } = {}
		scheduler.every(0.1, function(deltaTime)
			table.insert(runs, deltaTime)
		end)
		scheduler.step(0.06)
		expect(#runs).toBe(0)
		scheduler.step(0.06)
		expect(#runs).toBe(1)
		expect(runs[1]).toBeCloseTo(0.12, 1e-9)
	end)

	it("runs jobs at their own rates", function()
		local scheduler = Scheduler.new()
		local fast, slow = 0, 0
		scheduler.every(0, function()
			fast += 1
		end)
		scheduler.every(1, function()
			slow += 1
		end)
		for _ = 1, 10 do
			scheduler.step(0.25)
		end
		expect(fast).toBe(10)
		expect(slow).toBe(2)
	end)

	it("does not catch up after a long frame", function()
		local scheduler = Scheduler.new()
		local runs = 0
		scheduler.every(0.1, function()
			runs += 1
		end)
		scheduler.step(1)
		expect(runs).toBe(1)
	end)

	it("stops a cancelled job", function()
		local scheduler = Scheduler.new()
		local runs = 0
		local cancel = scheduler.every(0, function()
			runs += 1
		end)
		scheduler.step(0.1)
		cancel()
		scheduler.step(0.1)
		expect(runs).toBe(1)
	end)

	it("rejects a negative interval", function()
		local scheduler = Scheduler.new()
		expect(function()
			scheduler.every(-1, function() end)
		end).toThrow()
	end)
end)
