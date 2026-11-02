--!strict

local Lifecycle = require("../../src/shared/Runtime/Lifecycle")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function runNow(callback: () -> ())
	callback()
end

describe("Lifecycle", function()
	it("inits every system before starting any", function()
		local order: { string } = {}
		local function system(name: string): Lifecycle.System
			return {
				name = name,
				init = function()
					table.insert(order, `init {name}`)
				end,
				start = function()
					table.insert(order, `start {name}`)
				end,
			}
		end

		Lifecycle.run({ system("A"), system("B") }, runNow)

		expect(order).toEqual({ "init A", "init B", "start A", "start B" })
	end)

	it("allows systems without init or start", function()
		local started = false
		Lifecycle.run({
			{ name = "Empty" },
			{
				name = "StartOnly",
				start = function()
					started = true
				end,
			},
		}, runNow)

		expect(started).toBe(true)
	end)

	it("rejects an init that yields", function()
		expect(function()
			Lifecycle.run({
				{
					name = "Yielding",
					init = function()
						coroutine.yield()
					end,
				},
			}, runNow)
		end).toThrow("Yielding.init must not yield")
	end)

	it("names the system whose init failed", function()
		expect(function()
			Lifecycle.run({
				{
					name = "Broken",
					init = function()
						error("no config")
					end,
				},
			}, runNow)
		end).toThrow("Broken.init failed")
	end)

	it("rejects duplicate names", function()
		expect(function()
			Lifecycle.run({ { name = "Same" }, { name = "Same" } }, runNow)
		end).toThrow("Duplicate system name: Same")
	end)
end)
