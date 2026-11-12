--!strict

local Coach = require("../../src/shared/Domain/Coach")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local PAUSE = 40

-- A player just past the tutorial with nothing to be told.
local function facts(overrides: { [string]: any }?): Coach.Facts
	local base: { [string]: any } = {
		tutorialDone = true,
		carrying = false,
		freePods = 1,
		boughtPods = 0,
		shelfCount = 0,
		shelfSlots = 24,
		jetpackLevel = 0,
		canAffordJetpack = false,
		questToClaim = false,
		hasTrio = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base :: any
end

describe("Coach.candidate", function()
	it("says nothing during the tutorial or while carrying an egg", function()
		local all = { freePods = 0, shelfCount = 24, canAffordJetpack = true, questToClaim = true, hasTrio = true }
		expect(Coach.candidate(0, facts(all))).toBe("Shelf")
		all.tutorialDone = false
		expect(Coach.candidate(0, facts(all))).toBeNil()
		all.tutorialDone = true
		all.carrying = true
		expect(Coach.candidate(0, facts(all))).toBeNil()
	end)

	it("asks for each tip on its own event", function()
		expect(Coach.candidate(0, facts())).toBeNil()
		expect(Coach.candidate(0, facts({ freePods = 0, shelfCount = 1 }))).toBe("Shelf")
		expect(Coach.candidate(0, facts({ shelfCount = 1 }))).toBeNil()
		expect(Coach.candidate(0, facts({ canAffordJetpack = true }))).toBe("Jetpack")
		expect(Coach.candidate(0, facts({ canAffordJetpack = true, jetpackLevel = 1 }))).toBeNil()
		expect(Coach.candidate(0, facts({ questToClaim = true }))).toBe("Quest")
		expect(Coach.candidate(0, facts({ hasTrio = true }))).toBe("Crossbreed")
		expect(Coach.candidate(0, facts({ shelfCount = 24 }))).toBe("Sell")
		expect(Coach.candidate(0, facts({ shelfCount = 23 }))).toBeNil()
	end)

	it("goes by priority and skips the tips already done", function()
		local all =
			facts({ freePods = 0, shelfCount = 24, canAffordJetpack = true, questToClaim = true, hasTrio = true })
		local mask = 0
		for _, expected in { "Shelf", "Jetpack", "Quest", "Crossbreed", "Sell" } do
			local tip = Coach.candidate(mask, all)
			expect(tip).toBe(expected)
			mask = Coach.mark(mask, tip :: Coach.Tip)
		end
		expect(Coach.candidate(mask, all)).toBeNil()
	end)
end)

describe("Coach.mark and Coach.doneByState", function()
	it("marks a tip once", function()
		local mask, new = Coach.mark(0, "Quest")
		expect(new).toBe(true)
		expect(Coach.isDone(mask, "Quest")).toBe(true)
		expect(Coach.isDone(mask, "Sell")).toBe(false)
		local again, newAgain = Coach.mark(mask, "Quest")
		expect(again).toBe(mask)
		expect(newAgain).toBe(false)
	end)

	it("counts a bought pod and a bought jetpack as done", function()
		expect(Coach.doneByState(0, facts())).toBe(0)
		local mask = Coach.doneByState(0, facts({ boughtPods = 2, jetpackLevel = 3 }))
		expect(Coach.isDone(mask, "Shelf")).toBe(true)
		expect(Coach.isDone(mask, "Jetpack")).toBe(true)
		expect(Coach.isDone(mask, "Quest")).toBe(false)
	end)
end)

describe("Coach.pace", function()
	it("shows the first tip at once, with nothing shown before", function()
		local pace = Coach.pace(Coach.idle(), "Shelf", 100, PAUSE)
		expect(pace.shown).toBe("Shelf")
	end)

	it("waits the pause after the tutorial ends", function()
		local pace = Coach.restFrom(100)
		expect(Coach.pace(pace, "Shelf", 110, PAUSE).shown).toBeNil()
		expect(Coach.pace(pace, "Shelf", 140, PAUSE).shown).toBe("Shelf")
	end)

	it("hides a tip at once and shows the next only after the pause", function()
		local pace = Coach.pace(Coach.idle(), "Shelf", 100, PAUSE)
		pace = Coach.pace(pace, "Jetpack", 200, PAUSE)
		expect(pace.shown).toBeNil()
		expect(Coach.pace(pace, "Jetpack", 239, PAUSE).shown).toBeNil()
		expect(Coach.pace(pace, "Jetpack", 240, PAUSE).shown).toBe("Jetpack")
	end)

	it("brings the same tip back at once (an egg carried home)", function()
		local pace = Coach.pace(Coach.idle(), "Shelf", 100, PAUSE)
		pace = Coach.pace(pace, nil, 150, PAUSE)
		expect(pace.shown).toBeNil()
		expect(Coach.pace(pace, "Shelf", 151, PAUSE).shown).toBe("Shelf")
	end)

	it("keeps a tip that is still wanted", function()
		local pace = Coach.pace(Coach.idle(), "Quest", 100, PAUSE)
		expect(Coach.pace(pace, "Quest", 500, PAUSE)).toBe(pace)
	end)
end)
