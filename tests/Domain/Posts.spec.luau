--!strict

local Posts = require("../../src/shared/Domain/Posts")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Posts.indexFor", function()
	it("splits the nests into equal groups, nearest first", function()
		local got = {}
		for rank = 1, 9 do
			got[rank] = Posts.indexFor(rank, 9, 3)
		end
		expect(got).toEqual({ 1, 1, 1, 2, 2, 2, 3, 3, 3 })
	end)

	it("rounds uneven splits toward the nearer post", function()
		local got = {}
		for rank = 1, 4 do
			got[rank] = Posts.indexFor(rank, 4, 3)
		end
		expect(got).toEqual({ 1, 2, 3, 3 })
	end)

	it("gives every nest the only post", function()
		expect(Posts.indexFor(1, 5, 1)).toBe(1)
		expect(Posts.indexFor(5, 5, 1)).toBe(1)
	end)

	it("rejects ranks out of range", function()
		expect(function()
			Posts.indexFor(0, 5, 3)
		end).toThrow("out of range")
		expect(function()
			Posts.indexFor(6, 5, 3)
		end).toThrow("out of range")
	end)
end)
