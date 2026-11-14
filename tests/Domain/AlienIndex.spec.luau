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

describe("AlienIndex.pending", function()
	it("lists the finds not yet claimed and the complete sets not yet claimed", function()
		local index = AlienIndex.empty()
		for _, alienId in SET.aliens do
			AlienIndex.discover(index, alienId)
		end
		AlienIndex.claim(index, SET.aliens[1])
		AlienIndex.discover(index, "A.Common.Meteor")
		local aliens, sets = AlienIndex.pending(index, { SET, METEOR_SET })
		expect(#aliens).toBe(#SET.aliens - 1 + 1)
		expect(table.find(aliens, SET.aliens[1])).toBeNil()
		expect(table.find(aliens, "A.Common.Meteor") ~= nil).toBe(true)
		expect(#sets).toBe(1)
		expect(sets[1].id).toBe(SET.id)
		-- As many as are waiting.
		expect(#aliens + #sets).toBe(AlienIndex.waiting(index, { SET, METEOR_SET }))
	end)

	it("lists nothing once everything is taken", function()
		local index = AlienIndex.empty()
		for _, alienId in SET.aliens do
			AlienIndex.discover(index, alienId)
			AlienIndex.claim(index, alienId)
		end
		AlienIndex.claimSet(index, SET)
		local aliens, sets = AlienIndex.pending(index, { SET })
		expect(#aliens).toBe(0)
		expect(#sets).toBe(0)
	end)
end)

describe("AlienIndex.openingSet", function()
	local FAR_SET: AlienIndex.Set = {
		id = AlienIndex.setId(5, "Normal"),
		grade = 5,
		variant = "Normal",
		aliens = { "B.Common", "B.Uncommon", "B.Rare" },
	}
	local ALL = { SET, FAR_SET, METEOR_SET }
	local NORMAL = { SET, FAR_SET }

	it("opens where a reward waits, in the order of the sets", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, { "B.Common" })
		AlienIndex.discover(index, "A.Rare.Meteor")
		expect(AlienIndex.openingSet(index, ALL, NORMAL)).toBe(METEOR_SET)
		AlienIndex.discover(index, "A.Common")
		expect(AlienIndex.openingSet(index, ALL, NORMAL)).toBe(SET)
	end)

	it("counts a complete, unclaimed set as waiting", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, { "A.Common", "A.Uncommon", "A.Rare" })
		expect(AlienIndex.openingSet(index, ALL, NORMAL)).toBe(SET)
	end)

	it("without rewards, opens at the farthest guardian with a find", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, { "A.Common", "B.Uncommon" })
		expect(AlienIndex.openingSet(index, ALL, NORMAL)).toBe(FAR_SET)
	end)

	it("has no place for an empty index", function()
		expect(AlienIndex.openingSet(AlienIndex.empty(), ALL, NORMAL)).toBe(nil)
	end)
end)

describe("AlienIndex.applied", function()
	it("adds a find with its reward waiting, leaving the old state as it was", function()
		local before = AlienIndex.empty()
		local after = AlienIndex.applied(before, { kind = "Found", id = "A.Common" })
		expect(after.found["A.Common"]).toBe(false)
		expect(before.found["A.Common"]).toBe(nil)
		expect(after == before).toBe(false)
	end)

	it("does not undo a taken reward when the find comes again", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, { "A.Common" })
		local after = AlienIndex.applied(index, { kind = "Found", id = "A.Common" })
		expect(after.found["A.Common"]).toBe(true)
	end)

	it("marks an alien's reward taken", function()
		local index = AlienIndex.applied(AlienIndex.empty(), { kind = "Found", id = "A.Rare" })
		local after = AlienIndex.applied(index, { kind = "Claimed", id = "A.Rare" })
		expect(after.found["A.Rare"]).toBe(true)
		expect(AlienIndex.waiting(after, { SET })).toBe(0)
	end)

	it("marks a set's reward taken once", function()
		local index = AlienIndex.empty()
		AlienIndex.seed(index, SET.aliens)
		local once = AlienIndex.applied(index, { kind = "SetClaimed", id = SET.id })
		local twice = AlienIndex.applied(once, { kind = "SetClaimed", id = SET.id })
		expect(AlienIndex.isSetClaimed(once, SET)).toBe(true)
		expect(#twice.sets).toBe(1)
	end)

	it("ends where the server's own index ends after the same finds and claims", function()
		local server = AlienIndex.empty()
		local client = AlienIndex.empty()
		local function both(change: AlienIndex.Change, serverSide: () -> ())
			serverSide()
			client = AlienIndex.applied(client, change)
		end
		both({ kind = "Found", id = "A.Common" }, function()
			AlienIndex.discover(server, "A.Common")
		end)
		both({ kind = "Found", id = "A.Uncommon" }, function()
			AlienIndex.discover(server, "A.Uncommon")
		end)
		both({ kind = "Claimed", id = "A.Common" }, function()
			AlienIndex.claim(server, "A.Common")
		end)
		both({ kind = "Found", id = "A.Rare" }, function()
			AlienIndex.discover(server, "A.Rare")
		end)
		both({ kind = "SetClaimed", id = SET.id }, function()
			AlienIndex.claimSet(server, SET)
		end)
		expect(client.found).toEqual(server.found)
		expect(client.sets).toEqual(server.sets)
	end)
end)
