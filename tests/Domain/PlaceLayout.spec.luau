--!strict

local PlaceLayout = require("../../src/shared/Domain/PlaceLayout")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local OPTIONS: PlaceLayout.Options = {
	inner = 20,
	outer = 92,
	arc = math.rad(300),
	gap = 1.5,
	airMax = 10,
	rowSpread = 2,
	minSqueeze = 0.5,
	squeezeStep = 0.02,
}

local function radiusOf(spot: PlaceLayout.Spot): number
	return math.sqrt(spot.x * spot.x + spot.z * spot.z)
end

-- The smallest air between two places, studs (negative when they overlap).
local function closestGap(widths: { number }, spots: { PlaceLayout.Spot }): number
	local closest = math.huge
	for a = 1, #spots do
		for b = a + 1, #spots do
			local distance = math.sqrt((spots[a].x - spots[b].x) ^ 2 + (spots[a].z - spots[b].z) ^ 2)
			closest = math.min(closest, distance - (widths[a] + widths[b]) / 2)
		end
	end
	return closest
end

local function repeated(width: number, count: number): { number }
	local widths = {}
	for index = 1, count do
		widths[index] = width
	end
	return widths
end

describe("PlaceLayout.arrange", function()
	it("gives nothing for no places", function()
		local layout = PlaceLayout.arrange({}, OPTIONS)
		expect(#layout.spots).toBe(0)
		expect(layout.squeeze).toBe(1)
	end)

	it("stands a short row in the middle of the horseshoe, at the back", function()
		local layout = PlaceLayout.arrange({ 2, 2, 2 }, OPTIONS)
		expect(#layout.spots).toBe(3)
		local sumX = 0
		for _, spot in layout.spots do
			sumX += spot.x
			expect(spot.z > 0).toBe(true)
			expect(radiusOf(spot)).toBeCloseTo(OPTIONS.inner + 1, 1e-6)
		end
		expect(sumX).toBeCloseTo(0, 1e-6)
		expect(layout.squeeze).toBe(1)
	end)

	it("puts the biggest of a row in its middle", function()
		local layout = PlaceLayout.arrange({ 2, 3, 2 }, OPTIONS)
		expect(layout.spots[2].x).toBeCloseTo(0, 1e-6)
		expect(layout.spots[1].x * layout.spots[3].x < 0).toBe(true)
	end)

	it("puts small places in the inner rows and big ones farther out", function()
		local widths = repeated(3, 20)
		for index = 21, 30 do
			widths[index] = 20
		end
		local layout = PlaceLayout.arrange(widths, OPTIONS)
		local farthestSmall, nearestBig = 0, math.huge
		for index, spot in layout.spots do
			if widths[index] == 3 then
				farthestSmall = math.max(farthestSmall, radiusOf(spot))
			else
				nearestBig = math.min(nearestBig, radiusOf(spot))
			end
		end
		expect(farthestSmall < nearestBig).toBe(true)
	end)

	it("keeps every place within the horseshoe and apart while there is room", function()
		local widths = {}
		for index = 1, 30 do
			widths[index] = 2 + (index * 7) % 13
		end
		local layout = PlaceLayout.arrange(widths, OPTIONS)
		expect(layout.squeeze).toBe(1)
		expect(layout.reach <= OPTIONS.outer).toBe(true)
		-- The gap is kept along the arc; straight across it is a little less.
		expect(closestGap(widths, layout.spots) >= OPTIONS.gap / 2).toBe(true)
		for index, spot in layout.spots do
			local radius = radiusOf(spot)
			expect(radius - widths[index] / 2 >= OPTIONS.inner - 1e-6).toBe(true)
			expect(radius + widths[index] / 2 <= OPTIONS.outer + 1e-6).toBe(true)
			-- Within the horseshoe: never in the entrance's wedge.
			expect(math.abs(math.atan2(spot.x, spot.z)) <= OPTIONS.arc / 2 + 1e-6).toBe(true)
		end
	end)

	it("moves places closer when they do not fit, keeping to the floor", function()
		local tight = PlaceLayout.arrange(repeated(30, 30), OPTIONS)
		expect(tight.squeeze < 1).toBe(true)
		expect(tight.squeeze >= OPTIONS.minSqueeze - 1e-9).toBe(true)
		-- The aliens keep their size: their own edges stay within the horseshoe, inside and out and
		-- at the ends of the rows; only neighbours move into each other.
		expect(tight.reach <= OPTIONS.outer).toBe(true)
		for _, spot in tight.spots do
			local radius = radiusOf(spot)
			expect(radius + 15 <= OPTIONS.outer + 1e-6).toBe(true)
			expect(radius - 15 >= OPTIONS.inner - 1e-6).toBe(true)
			local edge = math.abs(math.atan2(spot.x, spot.z)) + math.asin(15 / radius)
			expect(edge <= OPTIONS.arc / 2 + 1e-6).toBe(true)
		end

		local huge = PlaceLayout.arrange(repeated(80, 30), OPTIONS)
		expect(huge.squeeze).toBeCloseTo(OPTIONS.minSqueeze, 1e-6)
		expect(huge.reach > OPTIONS.outer).toBe(true)
	end)

	it("spreads a short row's places at one step, with air up to the ceiling", function()
		local layout = PlaceLayout.arrange({ 2, 4, 3 }, OPTIONS)
		local spots = layout.spots
		-- The widest in the middle, the others one step to either side.
		expect(spots[2].x).toBeCloseTo(0, 1e-6)
		local radius = radiusOf(spots[2])
		local function along(spot: PlaceLayout.Spot): number
			return radius * math.atan2(spot.x, spot.z)
		end
		local left, right = along(spots[1]), along(spots[3])
		expect(math.abs(left)).toBeCloseTo(math.abs(right), 1e-6)
		-- The step is the widest's slot plus the most air: the row has room to spare.
		expect(math.abs(left)).toBeCloseTo(4 + OPTIONS.airMax, 1e-6)
	end)

	it("gives a full row only the least air", function()
		-- 2-stud places along the first row's arc: as many as fit, then the next row.
		local layout = PlaceLayout.arrange(repeated(2, 60), OPTIONS)
		local radius = OPTIONS.inner + 1
		local first: { number } = {}
		for _, spot in layout.spots do
			if math.abs(radiusOf(spot) - radius) < 1e-6 then
				table.insert(first, radius * math.atan2(spot.x, spot.z))
			end
		end
		table.sort(first)
		expect(#first > 2).toBe(true)
		for position = 2, #first do
			expect(first[position] - first[position - 1] < 2 + OPTIONS.airMax).toBe(true)
			expect(first[position] - first[position - 1] >= 2 + OPTIONS.gap - 1e-6).toBe(true)
		end
	end)

	it("lays out the same places the same way every time", function()
		local widths = { 5, 2, 9, 2, 5 }
		local first = PlaceLayout.arrange(widths, OPTIONS)
		local second = PlaceLayout.arrange(widths, OPTIONS)
		for index = 1, #widths do
			expect(first.spots[index].x).toBe(second.spots[index].x)
			expect(first.spots[index].z).toBe(second.spots[index].z)
		end
	end)

	it("rejects a place with no width", function()
		expect(function()
			PlaceLayout.arrange({ 2, 0 }, OPTIONS)
		end).toThrow("width")
	end)
end)
