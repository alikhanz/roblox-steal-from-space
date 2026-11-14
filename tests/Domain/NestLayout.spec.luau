--!strict

local NestLayout = require("../../src/shared/Domain/NestLayout")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local RING: NestLayout.Ring = { ringMin = 600, ringMax = 900, heightSpread = 100, postCount = 6, nestsPerPost = 5 }

-- A small seeded generator (Lune has no Random): the same numbers every run.
local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

describe("NestLayout.place", function()
	it("gives every post its number of nests", function()
		local spots = NestLayout.place(RING, seeded(1))
		expect(#spots).toBe(30)
		local perPost: { [number]: number } = {}
		for _, spot in spots do
			perPost[spot.post] = (perPost[spot.post] or 0) + 1
		end
		for post = 1, 6 do
			expect(perPost[post]).toBe(5)
		end
	end)

	it("puts every nest of a post nearer than every nest of the next", function()
		for seed = 1, 20 do
			local nearest: { [number]: number } = {}
			local farthest: { [number]: number } = {}
			for _, spot in NestLayout.place(RING, seeded(seed)) do
				nearest[spot.post] = math.min(nearest[spot.post] or math.huge, spot.distance)
				farthest[spot.post] = math.max(farthest[spot.post] or -math.huge, spot.distance)
			end
			for post = 1, 5 do
				expect(farthest[post] < nearest[post + 1]).toBe(true)
			end
		end
	end)

	it("keeps every nest within the zone's ring and height", function()
		for _, spot in NestLayout.place(RING, seeded(3)) do
			expect(spot.distance >= RING.ringMin and spot.distance <= RING.ringMax).toBe(true)
			expect(math.abs(spot.height) <= RING.heightSpread).toBe(true)
		end
	end)

	it("spreads a post's nests around the ring", function()
		local angles: { number } = {}
		for _, spot in NestLayout.place(RING, seeded(4)) do
			if spot.post == 2 then
				table.insert(angles, spot.angle % (math.pi * 2))
			end
		end
		table.sort(angles)
		-- Five nests: no two closer than half an even step (72 degrees).
		for index = 2, #angles do
			expect(angles[index] - angles[index - 1] > math.rad(72) / 2).toBe(true)
		end
	end)
end)

describe("NestLayout.postBand", function()
	it("gives each post an even share of the zone's ring, the first innermost", function()
		local ring = { ringMin = 100, ringMax = 700, heightSpread = 10, postCount = 6, nestsPerPost = 6 }
		local middle, stray = NestLayout.postBand(ring, 1)
		expect(middle).toBeCloseTo(150, 1e-9)
		expect(stray).toBeCloseTo(30, 1e-9)
		local last = NestLayout.postBand(ring, 6)
		expect(last).toBeCloseTo(650, 1e-9)
	end)

	it("holds every nest of the post", function()
		local ring = { ringMin = 100, ringMax = 700, heightSpread = 10, postCount = 6, nestsPerPost = 6 }
		local seed = 0
		local function random(): number
			seed = (seed * 9301 + 49297) % 233280
			return seed / 233280
		end
		for _, spot in NestLayout.place(ring, random) do
			local middle, stray = NestLayout.postBand(ring, spot.post)
			expect(math.abs(spot.distance - middle) <= stray + 1e-9).toBe(true)
		end
	end)
end)
