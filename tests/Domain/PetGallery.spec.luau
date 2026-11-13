--!strict

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local PetGallery = require("../../src/shared/Domain/PetGallery")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local PLACES = 30

describe("PetGallery.pages", function()
	local pages = PetGallery.pages(PLACES)

	it("goes family after family in the gallery's order, each family's pages together", function()
		local order: { string } = {}
		for _, page in pages do
			if order[#order] ~= page.family then
				table.insert(order, page.family)
			end
			expect(#page.aliens <= PLACES).toBe(true)
			expect(page.part >= 1 and page.part <= page.parts).toBe(true)
		end
		expect(order).toEqual({ "slime", "crab", "worm", "ray", "swarm", "whale" })
	end)

	it("shows every kind of a family at every tier once across its pages, a third of them meteor", function()
		for _, family in PetGallery.FAMILIES do
			local seen: { [string]: boolean } = {}
			local count, meteors = 0, 0
			for _, page in pages do
				if page.family == family then
					for _, alienId in page.aliens do
						local alien = AlienConfig.ALIENS[alienId]
						expect(AlienConfig.KINDS[alien.kind].family).toBe(family)
						local key = `{alien.kind}:{alien.tier}`
						expect(seen[key]).toBeNil()
						seen[key] = true
						count += 1
						if alien.variant == "Meteor" then
							meteors += 1
						end
					end
				end
			end
			local kinds = 0
			for _, kind in AlienConfig.KINDS do
				if kind.family == family then
					kinds += 1
				end
			end
			expect(count).toBe(kinds * #AlienConfig.TIER_ORDER)
			expect(meteors).toBe(count // 3)
		end
	end)

	it("puts every kind of the family on each full page, and every tier", function()
		for _, page in pages do
			if #page.aliens < PLACES then
				continue
			end
			local kinds: { [string]: boolean } = {}
			local tiers: { [string]: boolean } = {}
			for _, alienId in page.aliens do
				local alien = AlienConfig.ALIENS[alienId]
				kinds[alien.kind] = true
				tiers[alien.tier] = true
			end
			for kindId, kind in AlienConfig.KINDS do
				if kind.family == page.family then
					expect(kinds[kindId]).toBe(true)
				end
			end
			for _, tier in AlienConfig.TIER_ORDER do
				expect(tiers[tier]).toBe(true)
			end
		end
	end)
end)

describe("PetGallery.next and label", function()
	it("starts at the first page and goes round after the last", function()
		expect(PetGallery.next(0, 12)).toBe(1)
		expect(PetGallery.next(5, 12)).toBe(6)
		expect(PetGallery.next(12, 12)).toBe(1)
	end)

	it("names a page by its family and part", function()
		expect(PetGallery.label({ family = "crab", part = 1, parts = 2, aliens = {} })).toBe("crab 1/2")
	end)
end)
