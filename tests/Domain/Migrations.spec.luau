--!strict

local Migrations = require("../../src/shared/Domain/Migrations")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local STEPS: { [number]: Migrations.Step } = {
	[1] = function(data)
		data.gems = 0
	end,
	[2] = function(data)
		data.coins = data.money
		data.money = nil
	end,
}

describe("Migrations.run", function()
	it("does nothing for current data", function()
		local data: { [string]: any } = { schemaVersion = 3 }
		expect(Migrations.run(data, STEPS, 3)).toBe("Ok")
		expect(data).toEqual({ schemaVersion = 3 })
	end)

	it("applies every step in order and records the version", function()
		local data: { [string]: any } = { schemaVersion = 1, money = 50 }
		expect(Migrations.run(data, STEPS, 3)).toBe("Ok")
		expect(data).toEqual({ schemaVersion = 3, gems = 0, coins = 50 })
	end)

	it("refuses data from a newer version", function()
		expect(Migrations.run({ schemaVersion = 4 }, STEPS, 3)).toBe("NewerVersion")
	end)

	it("refuses missing or broken versions", function()
		expect(Migrations.run({}, STEPS, 3)).toBe("InvalidVersion")
		expect(Migrations.run({ schemaVersion = "2" }, STEPS, 3)).toBe("InvalidVersion")
		expect(Migrations.run({ schemaVersion = 1.5 }, STEPS, 3)).toBe("InvalidVersion")
		expect(Migrations.run({ schemaVersion = 0 }, STEPS, 3)).toBe("InvalidVersion")
	end)

	it("reports a gap in the steps", function()
		local status, detail = Migrations.run({ schemaVersion = 1 }, { [1] = STEPS[1] }, 3)
		expect(status).toBe("MissingStep")
		expect(detail).toBe("no migration from v2")
	end)

	it("reports a failing step", function()
		local steps: { [number]: Migrations.Step } = {
			[1] = function()
				error("bad data")
			end,
		}
		local status, detail = Migrations.run({ schemaVersion = 1 }, steps, 2)
		expect(status).toBe("StepFailed")
		expect(string.find(detail :: string, "v1 -> v2", 1, true) ~= nil).toBe(true)
	end)
end)
