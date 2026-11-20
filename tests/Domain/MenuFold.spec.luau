--!strict

local MenuFold = require("../../src/shared/Domain/MenuFold")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local MAIN = { Bay = true, Store = true, Quests = true }

local function tile(slot: string, shown: boolean?, badge: number?, pulse: boolean?): MenuFold.Tile
	return { slot = slot, shown = shown ~= false, badge = badge or 0, pulse = pulse == true }
end

local function row(): { MenuFold.Tile }
	return {
		tile("Bay"),
		tile("Store"),
		tile("Quests", true, 2),
		tile("Index", true, 1),
		tile("Controls"),
		tile("Invite"),
		tile("Gift", true, 1),
		tile("Community", true, 1),
	}
end

describe("MenuFold.of", function()
	it("keeps the main tiles in the row and folds the rest behind more", function()
		local fold = MenuFold.of(row(), MAIN, false)
		expect(fold.more).toBe(true)
		for _, slot in { "Bay", "Store", "Quests" } do
			expect(fold.inRow[slot]).toBe(true)
		end
		for _, slot in { "Index", "Controls", "Invite", "Gift", "Community" } do
			expect(fold.inRow[slot]).toBe(false)
		end
	end)

	it("sums the hidden tiles' badges on more, not the main ones'", function()
		expect(MenuFold.of(row(), MAIN, false).moreBadge).toBe(3)
	end)

	it("opens the folded tiles beside more and clears its badge", function()
		local fold = MenuFold.of(row(), MAIN, true)
		expect(fold.more).toBe(true)
		expect(fold.moreBadge).toBe(0)
		for _, slot in { "Index", "Controls", "Invite", "Gift", "Community" } do
			expect(fold.inRow[slot]).toBe(true)
		end
	end)

	it("passes a hidden tile's call to more while folded", function()
		local tiles = row()
		tiles[4] = tile("Index", true, 0, true)
		expect(MenuFold.of(tiles, MAIN, false).morePulse).toBe(true)
		expect(MenuFold.of(tiles, MAIN, true).morePulse).toBe(false)
	end)

	it("does not call through more for a main tile", function()
		local tiles = row()
		tiles[1] = tile("Bay", true, 0, true)
		expect(MenuFold.of(tiles, MAIN, false).morePulse).toBe(false)
	end)

	it("leaves tiles that are not shown out of the row and out of the badge", function()
		local tiles = row()
		tiles[7] = tile("Gift", false, 1)
		local fold = MenuFold.of(tiles, MAIN, true)
		expect(fold.inRow.Gift).toBe(false)
		expect(MenuFold.of(tiles, MAIN, false).moreBadge).toBe(2)
	end)

	it("puts a single foldable tile in the row instead of more", function()
		local tiles = {
			tile("Bay"),
			tile("Store", false),
			tile("Quests"),
			tile("Index", true, 4),
			tile("Controls", false),
			tile("Invite", false),
		}
		local fold = MenuFold.of(tiles, MAIN, false)
		expect(fold.more).toBe(false)
		expect(fold.inRow.Index).toBe(true)
		expect(fold.moreBadge).toBe(0)
	end)

	it("has no more tile when nothing is left to fold", function()
		local fold = MenuFold.of({ tile("Bay"), tile("Store"), tile("Quests") }, MAIN, false)
		expect(fold.more).toBe(false)
	end)
end)
