--!strict

local Test = require("../../lune/lib/Test")
local Trainer = require("../../src/shared/Domain/Trainer")
local describe, it, expect = Test.describe, Test.it, Test.expect

local PAD: Trainer.Pad = { x = 0, z = -8, radius = 2, height = 6 }

describe("Trainer.isOnPad", function()
	it("counts standing on the disc and a little past its edge", function()
		expect(Trainer.isOnPad(0, 1, -8, PAD, 1)).toBe(true)
		expect(Trainer.isOnPad(2.9, 1, -8, PAD, 1)).toBe(true)
		expect(Trainer.isOnPad(0, 1, -5, PAD, 1)).toBe(true)
		expect(Trainer.isOnPad(3.1, 1, -8, PAD, 1)).toBe(false)
		expect(Trainer.isOnPad(2.2, 1, -5.8, PAD, 1)).toBe(false)
	end)

	it("ignores whoever is above or below the pad", function()
		expect(Trainer.isOnPad(0, 7, -8, PAD, 0)).toBe(false)
		expect(Trainer.isOnPad(0, -1, -8, PAD, 0)).toBe(false)
		expect(Trainer.isOnPad(0, 6, -8, PAD, 0)).toBe(true)
	end)

	it("rejects a negative tolerance", function()
		expect(function()
			Trainer.isOnPad(0, 1, -8, PAD, -1)
		end).toThrow("tolerance")
	end)
end)
