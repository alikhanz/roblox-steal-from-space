--!strict
-- The aliens' icon sheets (Config/AlienIcons, assets/aliens/icons) against the registry.

local fs = require("@lune/fs")

local AlienConfig = require("../../src/shared/Config/AlienConfig")
local AlienIcons = require("../../src/shared/Config/AlienIcons")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local ICONS_DIR = "assets/aliens/icons"

describe("Alien icons", function()
	it("has an uploaded sheet and its file for every guardian", function()
		for _, grade in AlienConfig.GRADES do
			local main = grade.kinds[1]
			expect(AlienIcons.SHEETS[main]).toBeTruthy()
			expect(fs.isFile(`{ICONS_DIR}/icons-{main}.png`)).toBe(true)
		end
	end)

	it("lists sheets only for main kinds", function()
		local mains: { [string]: boolean } = {}
		for _, grade in AlienConfig.GRADES do
			mains[grade.kinds[1]] = true
		end
		for kindId in AlienIcons.SHEETS do
			expect(mains[kindId]).toBe(true)
		end
	end)

	it("cuts a kind's row and a tier's column out of its guardian's sheet", function()
		local grade = AlienConfig.GRADES[2]
		local rare = grade.variants.Normal[grade.kinds[3]].Epic
		local icon = assert(AlienIcons.iconOf(rare))
		expect(icon.image).toBe(AlienIcons.SHEETS[grade.kinds[1]])
		expect(icon.x).toBe(3 * AlienIcons.CELL)
		expect(icon.y).toBe(2 * AlienIcons.CELL)
		local meteor = assert(AlienIcons.iconOf(grade.variants.Meteor[grade.kinds[3]].Epic))
		expect(meteor.x).toBe(icon.x)
		expect(meteor.y).toBe(icon.y)
	end)

	it("has none for an unknown alien", function()
		expect(AlienIcons.iconOf("Nowhere1.nobody.Common")).toBeNil()
	end)
end)
