--!strict

local EggHomes = require("../../src/shared/Domain/EggHomes")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

-- Nests that write down what they were told.
local function recordingNests(): (EggHomes.Nests, { string })
	local log: { string } = {}
	local nests: EggHomes.Nests = {
		grade = function(id: string): number?
			return if id == "Nest1" then 4 else nil
		end,
		returnEgg = function(id, rarity, size, variant)
			table.insert(log, `nest return {id} {rarity} {size} {variant}`)
		end,
		delivered = function(id)
			table.insert(log, `nest delivered {id}`)
		end,
	}
	return nests, log
end

local function recordingHome(log: { string }, grade: number?): EggHomes.Home
	return {
		grade = function(): number?
			return grade
		end,
		returnEgg = function(rarity, size, variant)
			table.insert(log, `home return {rarity} {size} {variant}`)
		end,
		delivered = function()
			table.insert(log, "home delivered")
		end,
	}
end

describe("EggHomes", function()
	it("sends every id to the nests when no keeper registered it", function()
		local nests, log = recordingNests()
		local homes = EggHomes.new(nests)
		expect(homes.grade("Nest1")).toBe(4)
		expect(homes.grade("Nowhere")).toBeNil()
		homes.returnEgg("Nest1", "Rare", "Large", "Normal")
		homes.delivered("Nest1")
		expect(log).toEqual({ "nest return Nest1 Rare Large Normal", "nest delivered Nest1" })
	end)

	it("sends a registered id to its keeper", function()
		local nests, log = recordingNests()
		local homes = EggHomes.new(nests)
		homes.register("StarSerpent", recordingHome(log, 9))
		expect(homes.grade("StarSerpent")).toBe(9)
		homes.returnEgg("StarSerpent", "Epic", "Small", "Normal")
		homes.delivered("StarSerpent")
		-- The nests still answer for their own.
		homes.delivered("Nest1")
		expect(log).toEqual({ "home return Epic Small Normal", "home delivered", "nest delivered Nest1" })
	end)

	it("gives an id back to the nests once its keeper lets it go", function()
		local nests, log = recordingNests()
		local homes = EggHomes.new(nests)
		homes.register("StarSerpent", recordingHome(log, 9))
		homes.unregister("StarSerpent")
		expect(homes.grade("StarSerpent")).toBeNil()
		homes.delivered("StarSerpent")
		expect(log).toEqual({ "nest delivered StarSerpent" })
	end)

	it("refuses a home that is taken", function()
		local nests, log = recordingNests()
		local homes = EggHomes.new(nests)
		homes.register("StarSerpent", recordingHome(log, 9))
		expect(function()
			homes.register("StarSerpent", recordingHome(log, 3))
		end).toThrow()
	end)
end)
