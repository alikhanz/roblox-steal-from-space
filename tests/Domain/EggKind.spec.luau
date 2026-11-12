--!strict

local EggKind = require("../../src/shared/Domain/EggKind")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("EggKind.of", function()
	it("calls an egg of the usual variant without luck a normal egg", function()
		expect(EggKind.of(nil, false)).toBe("Normal")
		expect(EggKind.of("Normal", false)).toBe("Normal")
	end)

	it("knows a meteor egg by its variant", function()
		expect(EggKind.of("Meteor", false)).toBe("Meteor")
	end)

	it("knows the star egg by its luck, whatever its variant", function()
		expect(EggKind.of(nil, true)).toBe("Star")
		expect(EggKind.of("Meteor", true)).toBe("Star")
	end)
end)

describe("EggKind.parse", function()
	it("reads a kind back from an attribute", function()
		expect(EggKind.parse("Meteor")).toBe("Meteor")
		expect(EggKind.parse("Star")).toBe("Star")
	end)

	it("treats anything else as a normal egg", function()
		expect(EggKind.parse(nil)).toBe("Normal")
		expect(EggKind.parse("Mythic")).toBe("Normal")
		expect(EggKind.parse(3)).toBe("Normal")
	end)
end)
