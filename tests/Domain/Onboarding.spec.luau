--!strict

local Onboarding = require("../../src/shared/Domain/Onboarding")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Onboarding", function()
	it("numbers the steps in funnel order from 1", function()
		for index, step in Onboarding.STEPS do
			expect(step.number).toBe(index)
		end
	end)

	it("marks a step once", function()
		local grabbed = Onboarding.step("GrabbedEgg")
		local mask, isNew = Onboarding.mark(0, grabbed)
		expect(isNew).toBe(true)
		expect(Onboarding.has(mask, grabbed)).toBe(true)
		local again, isNewAgain = Onboarding.mark(mask, grabbed)
		expect(isNewAgain).toBe(false)
		expect(again).toBe(mask)
	end)

	it("keeps steps reached out of order apart", function()
		local mask = Onboarding.mark(0, Onboarding.step("StoleFromPost4"))
		expect(Onboarding.has(mask, Onboarding.step("FirstPurchase"))).toBe(false)
		expect(Onboarding.has(mask, Onboarding.step("StoleFromPost4"))).toBe(true)
	end)

	it("rejects an unknown step name", function()
		expect(function()
			Onboarding.step("Flew")
		end).toThrow()
	end)

	it("knows which theft milestones a delivery reaches", function()
		local function names(grade: number): string
			local list = {}
			for _, step in Onboarding.stealSteps(grade, 7) do
				table.insert(list, step.name)
			end
			return table.concat(list, ",")
		end
		expect(names(3)).toBe("")
		expect(names(4)).toBe("StoleFromPost4")
		expect(names(6)).toBe("StoleFromPost4,StoleFromPost6")
		expect(names(9)).toBe("StoleFromPost4,StoleFromPost6,StoleInIceRings")
	end)
end)
