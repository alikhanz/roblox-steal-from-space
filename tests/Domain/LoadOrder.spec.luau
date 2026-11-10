--!strict

local LoadOrder = require("../../src/shared/Domain/LoadOrder")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local TIMEOUT = 20

describe("LoadOrder queue", function()
	it("is empty when new", function()
		local queue = LoadOrder.new() :: LoadOrder.Queue<string>
		expect(LoadOrder.size(queue)).toBe(0)
		expect(LoadOrder.pop(queue)).toBe(nil)
	end)

	it("gives the highest priority first, whatever came first", function()
		local queue = LoadOrder.new() :: LoadOrder.Queue<string>
		LoadOrder.push(queue, 2, "pets")
		LoadOrder.push(queue, 1, "icons")
		LoadOrder.push(queue, 6, "jetpack")
		LoadOrder.push(queue, 4, "sounds")
		expect(LoadOrder.pop(queue)).toBe("jetpack")
		expect(LoadOrder.pop(queue)).toBe("sounds")
		expect(LoadOrder.pop(queue)).toBe("pets")
		expect(LoadOrder.pop(queue)).toBe("icons")
		expect(LoadOrder.pop(queue)).toBe(nil)
	end)

	it("keeps the order of arrival within one priority", function()
		local queue = LoadOrder.new() :: LoadOrder.Queue<string>
		LoadOrder.push(queue, 2, "first pet")
		LoadOrder.push(queue, 2, "second pet")
		LoadOrder.push(queue, 2, "third pet")
		expect(LoadOrder.pop(queue)).toBe("first pet")
		expect(LoadOrder.pop(queue)).toBe("second pet")
		expect(LoadOrder.size(queue)).toBe(1)
	end)

	it("puts something more urgent that comes later before what waits", function()
		local queue = LoadOrder.new() :: LoadOrder.Queue<string>
		LoadOrder.push(queue, 2, "pet")
		LoadOrder.push(queue, 2, "pet 2")
		expect(LoadOrder.pop(queue)).toBe("pet")
		LoadOrder.push(queue, 5, "guardian")
		expect(LoadOrder.pop(queue)).toBe("guardian")
		expect(LoadOrder.pop(queue)).toBe("pet 2")
	end)
end)

describe("LoadOrder.jetpackReady", function()
	it("waits while the profile has not given the level", function()
		expect(LoadOrder.jetpackReady({ expected = nil, worn = 0, loaded = true, elapsed = 2 }, TIMEOUT)).toBe(false)
	end)

	it("waits for the jetpack of the player's level, not the Starter worn before it", function()
		expect(LoadOrder.jetpackReady({ expected = 5, worn = 0, loaded = true, elapsed = 3 }, TIMEOUT)).toBe(false)
		expect(LoadOrder.jetpackReady({ expected = 5, worn = 5, loaded = false, elapsed = 3 }, TIMEOUT)).toBe(false)
		expect(LoadOrder.jetpackReady({ expected = 5, worn = 5, loaded = true, elapsed = 3 }, TIMEOUT)).toBe(true)
	end)

	it("lets a newcomer's Starter open the way once it is loaded", function()
		expect(LoadOrder.jetpackReady({ expected = 0, worn = 0, loaded = true, elapsed = 1 }, TIMEOUT)).toBe(true)
	end)

	it("waits while the character has no jetpack", function()
		expect(LoadOrder.jetpackReady({ expected = 0, worn = nil, loaded = false, elapsed = 1 }, TIMEOUT)).toBe(false)
	end)

	it("stops waiting after the timeout whatever the jetpack", function()
		expect(LoadOrder.jetpackReady({ expected = nil, worn = nil, loaded = false, elapsed = 20 }, TIMEOUT)).toBe(true)
		expect(LoadOrder.jetpackReady({ expected = 5, worn = 0, loaded = false, elapsed = 25 }, TIMEOUT)).toBe(true)
	end)
end)
