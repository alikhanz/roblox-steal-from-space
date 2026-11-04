--!strict

local AlienIndex = require("../../src/shared/Domain/AlienIndex")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local SET: AlienIndex.Set = {
	id = AlienIndex.setId(2, "Normal"),
	grade = 2,
	variant = "Normal",
	aliens = { "A.Common", "A.Uncommon", "A.Rare" },
}
local METEOR_SET: AlienIndex.Set = {
	id = AlienIndex.setId(2, "Meteor"),
	grade = 2,
	variant = "Meteor",
	aliens = { "A.Common.Meteor", "A.Uncommon.Meteor", "A.Rare.Meteor" },
}

describe("AlienIndex.setId", function()
	it("names the usual set by its grade and a variant's set with the variant", function()
		expect(AlienIndex.setId(3, "Normal")).toBe("3")
		expect(AlienIndex.setId(3, "Meteor")).toBe("3.Meteor")
	end)
end)

describe("AlienIndex.discover", function()
	it("finds an alien once", function()
		local index = AlienIndex.empty()
		expect(AlienIndex.discover(index, "A.Common")).toBe(true)
		expect(AlienIndex.discover(index, "A.Common")).toBe(false)
		expect(AlienIndex.isFound(index, "A.Common")).toBe(true)
		expect(AlienIndex.isFound(index, "A.Rare")).toBe(false)
	end)

	it("keeps a taken reward taken when found again", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, { "A.Common" })
		AlienIndex.discover(index, "A.Common")
		expect(AlienIndex.claim(index, "A.Common")).toBe("IndexClaimed")
	end)
end)

describe("AlienIndex.claim", function()
	it("pays a found alien once", function()
		local index = AlienIndex.empty()
		expect(AlienIndex.claim(index, "A.Common")).toBe("IndexNothing")
		AlienIndex.discover(index, "A.Common")
		expect(AlienIndex.claim(index, "A.Common")).toBeNil()
		expect(AlienIndex.claim(index, "A.Common")).toBe("IndexClaimed")
	end)
end)

describe("AlienIndex sets", function()
	it("pays a full set once", function()
		local index = AlienIndex.empty()
		AlienIndex.discover(index, "A.Common")
		AlienIndex.discover(index, "A.Uncommon")
		expect(AlienIndex.claimSet(index, SET)).toBe("IndexNothing")
		AlienIndex.discover(index, "A.Rare")
		expect(AlienIndex.foundOf(index, SET.aliens)).toBe(3)
		expect(AlienIndex.claimSet(index, SET)).toBeNil()
		expect(AlienIndex.isSetClaimed(index, SET)).toBe(true)
		expect(AlienIndex.claimSet(index, SET)).toBe("IndexClaimed")
	end)

	it("keeps a guardian's sets of different variants apart", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, SET.aliens)
		expect(AlienIndex.claimSet(index, SET)).toBeNil()
		expect(AlienIndex.isSetClaimed(index, METEOR_SET)).toBe(false)
		expect(AlienIndex.claimSet(index, METEOR_SET)).toBe("IndexNothing")
	end)

	it("counts what waits: new finds and full unclaimed sets", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, { "A.Common", "A.Uncommon" })
		expect(AlienIndex.waiting(index, { SET })).toBe(0)
		AlienIndex.discover(index, "A.Rare")
		expect(AlienIndex.waiting(index, { SET })).toBe(2)
		AlienIndex.claim(index, "A.Rare")
		expect(AlienIndex.waiting(index, { SET })).toBe(1)
		AlienIndex.claimSet(index, SET)
		expect(AlienIndex.waiting(index, { SET })).toBe(0)
	end)

	it("counts only the finds of the sets asked about", function()
		local index = AlienIndex.empty()
		AlienIndex.discover(index, "A.Common")
		AlienIndex.discover(index, "A.Common.Meteor")
		AlienIndex.discover(index, "A.Rare.Meteor")
		expect(AlienIndex.waiting(index, { SET })).toBe(1)
		expect(AlienIndex.waiting(index, { METEOR_SET })).toBe(2)
		expect(AlienIndex.waiting(index, { SET, METEOR_SET })).toBe(3)
	end)
end)
