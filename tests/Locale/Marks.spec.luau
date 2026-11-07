--!strict

local Marks = require("../../src/shared/Locale/Marks")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Marks.split", function()
	it("keeps a text without marks whole", function()
		expect(Marks.split("Quest complete!")).toEqual({ { text = "Quest complete!" } })
		expect(Marks.split("  spaced  ")).toEqual({ { text = "  spaced  " } })
	end)

	it("cuts words and marks in order, trimming the spaces around marks", function()
		expect(Marks.split("Reward: ●+12K and ⚡+3.4K")).toEqual({
			{ text = "Reward:" },
			{ icon = "Coin" },
			{ text = "+12K and" },
			{ icon = "Bolt" },
			{ text = "+3.4K" },
		})
	end)

	it("handles marks at the edges and side by side", function()
		expect(Marks.split("●77K")).toEqual({ { icon = "Coin" }, { text = "77K" } })
		expect(Marks.split("+1 slot ●")).toEqual({ { text = "+1 slot" }, { icon = "Coin" } })
		expect(Marks.split("●⚡")).toEqual({ { icon = "Coin" }, { icon = "Bolt" } })
	end)

	it("reads R$ as the Robux mark", function()
		expect(Marks.split("×2 for R$ 5")).toEqual({ { text = "×2 for" }, { icon = "Robux" }, { text = "5" } })
	end)

	it("tells whether a text has a mark", function()
		expect(Marks.has("Buy: ●77K")).toBe(true)
		expect(Marks.has("More ⚡")).toBe(true)
		expect(Marks.has("Claim")).toBe(false)
	end)
end)
