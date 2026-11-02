--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local PlayerData = require("../../src/shared/Domain/PlayerData")
local Tables = require("../../src/shared/Runtime/Tables")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function savedTemplate(): { [string]: any }
	-- What a fresh profile looks like after a DataStore round trip: plain, unfrozen tables.
	return Tables.deepCopy(PlayerData.template()) :: any
end

describe("PlayerData.load", function()
	it("loads a fresh profile", function()
		local outcome = PlayerData.load(savedTemplate())
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.schemaVersion).toBe(PlayerData.SCHEMA_VERSION)
			expect(outcome.data.coins).toBe(BigNum.ZERO)
		end
	end)

	it("restores saved coins as an immutable BigNum", function()
		local saved = savedTemplate()
		saved.coins = { mantissa = 1500, exponent = 0 }
		local outcome = PlayerData.load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.coins.mantissa).toBe(1500)
			expect(table.isfrozen(outcome.data.coins :: any)).toBe(true)
		end
	end)

	it("fills fields that older saves do not have", function()
		local saved = savedTemplate()
		saved.coins = nil
		local outcome = PlayerData.load(saved)
		expect(outcome.ok).toBe(true)
		if outcome.ok then
			expect(outcome.data.coins).toBe(BigNum.ZERO)
		end
	end)

	it("never modifies the saved table", function()
		local saved = savedTemplate()
		saved.coins = { mantissa = 42, exponent = 0 }
		local snapshot = Tables.deepCopy(saved)
		PlayerData.load(saved)
		expect(saved).toEqual(snapshot)
	end)

	it("refuses data from a newer version without touching it", function()
		local saved = savedTemplate()
		saved.schemaVersion = PlayerData.SCHEMA_VERSION + 1
		saved.futureField = "keep me"
		local snapshot = Tables.deepCopy(saved)

		local outcome = PlayerData.load(saved)
		expect(outcome.ok).toBe(false)
		if not outcome.ok then
			expect(outcome.reason).toBe("NewerVersion")
		end
		expect(saved).toEqual(snapshot)
	end)

	it("treats broken data as corrupted", function()
		local brokenCoins = savedTemplate()
		brokenCoins.coins = { mantissa = "lots", exponent = 0 }
		local noVersion = savedTemplate()
		noVersion.schemaVersion = nil

		for _, saved in { brokenCoins, noVersion, "not a table" :: any } do
			local outcome = PlayerData.load(saved)
			expect(outcome.ok).toBe(false)
			if not outcome.ok then
				expect(outcome.reason).toBe("Corrupted")
			end
		end
	end)
end)
