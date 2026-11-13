--!strict

local EggConfig = require("../../src/shared/Config/EggConfig")
local EggPieces = require("../../src/shared/Domain/EggPieces")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function ids(rarity: EggConfig.RarityId, kind: "Normal" | "Meteor" | "Star"): string
	local names = {}
	for _, piece in EggPieces.of(rarity, kind) do
		table.insert(names, piece.id)
	end
	return table.concat(names, " ")
end

local function paintOf(rarity: EggConfig.RarityId, kind: "Normal" | "Meteor" | "Star", id: string): string?
	for _, piece in EggPieces.of(rarity, kind) do
		if piece.id == id then
			return piece.paint
		end
	end
	return nil
end

describe("EggPieces.of", function()
	it("dresses a normal egg more the rarer it is", function()
		expect(ids("Common", "Normal")).toBe("GemShell GemGirdle")
		expect(ids("Uncommon", "Normal")).toBe("GemShell GemGirdle GemTip")
		expect(ids("Rare", "Normal")).toBe("GemShell GemGirdle GemTip GemFins")
		expect(ids("Epic", "Normal")).toBe("GemShell GemGirdle GemTip GemFins GemOrbit")
		expect(ids("Legendary", "Normal")).toBe("GemShell GemGirdle GemTip GemFins GemOrbit GemCrown")
	end)

	it("gives a meteor egg its rarity's add-ons, cracks and a flame instead of a tip", function()
		expect(ids("Common", "Meteor")).toBe("GemShell GemGirdle MeteorCracks MeteorFlame")
		expect(ids("Legendary", "Meteor")).toBe("GemShell GemGirdle GemFins GemOrbit GemCrown MeteorCracks MeteorFlame")
		expect(paintOf("Rare", "Meteor", "GemGirdle")).toBe("Lava")
	end)

	it("gives the star egg its star on top instead of a tip", function()
		expect(ids("Epic", "Star")).toBe("GemShell GemGirdle GemFins GemOrbit StarTop StarDots")
		expect(paintOf("Epic", "Star", "GemGirdle")).toBe("StarGold")
		-- The rarity's own light stays on what tells the rarity.
		expect(paintOf("Epic", "Star", "GemOrbit")).toBe("Line")
	end)

	it("wears each piece once, the shell first", function()
		for _, rarity in EggConfig.RARITY_ORDER do
			for _, kind in { "Normal", "Meteor", "Star" } :: { "Normal" | "Meteor" | "Star" } do
				local pieces = EggPieces.of(rarity, kind)
				expect(pieces[1].id).toBe("GemShell")
				local seen: { [string]: boolean } = {}
				for _, piece in pieces do
					expect(seen[piece.id]).toBe(nil)
					seen[piece.id] = true
				end
				expect(#pieces <= 7).toBe(true)
			end
		end
	end)
end)
