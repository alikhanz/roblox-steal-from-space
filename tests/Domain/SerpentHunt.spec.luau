--!strict

local SerpentHunt = require("../../src/shared/Domain/SerpentHunt")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("SerpentHunt", function()
	it("starts with the egg inside and the serpent fleeing", function()
		local state = SerpentHunt.start()
		expect(state).toEqual({ egg = "Inside", hits = 0 })
		expect(SerpentHunt.behavior(state)).toBe("Flee")
	end)

	it("knocks the egg out on the last hit, not before", function()
		local state, knocked = SerpentHunt.hit(SerpentHunt.start(), 3)
		expect(knocked).toBe(false)
		state, knocked = SerpentHunt.hit(state, 3)
		expect(knocked).toBe(false)
		expect(state.hits).toBe(2)
		state, knocked = SerpentHunt.hit(state, 3)
		expect(knocked).toBe(true)
		expect(state.egg).toBe("Out")
		expect(SerpentHunt.behavior(state)).toBe("Guard")
	end)

	it("ignores hits once the egg is out", function()
		local state = SerpentHunt.hit(SerpentHunt.start(), 1)
		local again, knocked = SerpentHunt.hit(state, 1)
		expect(knocked).toBe(false)
		expect(again).toEqual(state)
	end)

	it("takes the egg back inside, hits from scratch, when it leaves play undelivered", function()
		local state = SerpentHunt.hit(SerpentHunt.hit(SerpentHunt.start(), 2), 2)
		expect(state.egg).toBe("Out")
		expect(SerpentHunt.returned(state)).toEqual({ egg = "Inside", hits = 0 })
	end)

	it("leaves once the egg is delivered", function()
		local state = SerpentHunt.delivered(SerpentHunt.hit(SerpentHunt.start(), 1))
		expect(state.egg).toBe("Delivered")
		expect(SerpentHunt.behavior(state)).toBe("Leave")
		-- Nothing brings a delivered egg back.
		expect(SerpentHunt.returned(state)).toEqual(state)
	end)

	it("cannot deliver an egg still inside", function()
		expect(SerpentHunt.delivered(SerpentHunt.start())).toEqual(SerpentHunt.start())
	end)

	it("ends by where the egg is when the time is up", function()
		local inside = SerpentHunt.start()
		local out = SerpentHunt.hit(inside, 1)
		expect(SerpentHunt.ending(inside, false)).toBe("TookEgg")
		expect(SerpentHunt.ending(out, false)).toBe("EggLeft")
		expect(SerpentHunt.ending(out, true)).toBe("EggKept")
		expect(SerpentHunt.ending(SerpentHunt.delivered(out), false)).toBe("Delivered")
	end)
end)
