--!strict

local NestPosts = require("../../src/shared/Domain/NestPosts")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("NestPosts.isAnchor", function()
	it("keeps every other nest of a post, starting with the first", function()
		expect(NestPosts.isAnchor(1)).toBe(true)
		expect(NestPosts.isAnchor(2)).toBe(false)
		expect(NestPosts.isAnchor(3)).toBe(true)
		expect(NestPosts.isAnchor(6)).toBe(false)
	end)
end)

describe("NestPosts.choices", function()
	it("offers the home post and its neighbours within the zone", function()
		expect(table.concat(NestPosts.choices(3, 6), ",")).toBe("2,3,4")
		expect(table.concat(NestPosts.choices(1, 6), ",")).toBe("1,2")
		expect(table.concat(NestPosts.choices(6, 6), ",")).toBe("5,6")
	end)
end)

describe("NestPosts.next", function()
	it("always moves to another of the choices", function()
		for _, roll in { 0, 0.3, 0.6, 0.99 } do
			local post = NestPosts.next(3, 3, 6, roll)
			expect(post == 2 or post == 4).toBe(true)
			local back = NestPosts.next(4, 3, 6, roll)
			expect(back == 2 or back == 3).toBe(true)
		end
	end)

	it("takes each other choice about as often", function()
		local counts = { [2] = 0, [4] = 0 }
		for step = 0, 99 do
			local post = NestPosts.next(3, 3, 6, step / 100)
			counts[post] += 1
		end
		expect(counts[2]).toBe(50)
		expect(counts[4]).toBe(50)
	end)

	it("swaps between the two choices at a zone's edge", function()
		expect(NestPosts.next(1, 1, 6, 0.5)).toBe(2)
		expect(NestPosts.next(2, 1, 6, 0.5)).toBe(1)
		expect(NestPosts.next(6, 6, 6, 0.1)).toBe(5)
	end)

	it("stays when there is nothing else to take", function()
		expect(NestPosts.next(1, 1, 1, 0.5)).toBe(1)
	end)
end)
