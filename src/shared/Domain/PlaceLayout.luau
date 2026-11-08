--!strict
-- Where the places stand on a player's island (decision 068, docs/design/screens/island.md): a
-- horseshoe of rows around the island center, open toward the entrance. A place is as wide as
-- the alien on it, so the layout follows the aliens: the small ones (and empty places) in the
-- inner rows, the giants out by the dome, the biggest of each row in its middle. When the rows
-- do not fit by the island's edge, the places move closer together, all alike, down to a floor;
-- the aliens keep their size. Pure Luau.

local PlaceLayout = {}

export type Options = {
	-- Radius of the first row's inner edge, studs.
	read inner: number,
	-- The last row's outer edge should stay within this radius.
	read outer: number,
	-- The horseshoe's angle, radians, centred on the island's back (+Z).
	read arc: number,
	-- Air between two neighbours, in a row (along its arc) and between rows, studs.
	read gap: number,
	-- A row takes places at most this many times as wide as its narrowest: the small ones do not
	-- stand in line with giants.
	read rowSpread: number,
	-- The closest the places may move together: spacing times this at the least.
	read minSqueeze: number,
	-- How much closer they move at a time while the rows do not fit.
	read squeezeStep: number,
}

-- A place's center in the island's frame: X to the right, Z toward the back (away from the
-- entrance), studs.
export type Spot = {
	read x: number,
	read z: number,
}

export type Layout = {
	-- One spot per width given, in the same order.
	read spots: { Spot },
	-- 1 when every place stands freely; less when they were moved closer.
	read squeeze: number,
	-- How far from the center the last row's outer edge reaches.
	read reach: number,
}

type Row = {
	radius: number,
	members: { number },
}

-- Rows for `order` (indices into `widths`, smallest first) with spacing times `squeeze`. A row's
-- places stand on one arc, as far out as its widest needs to keep clear of the row inside.
-- Spacing shrinks with the squeeze, the aliens do not: the horseshoe's own edges (the first row's
-- inner edge, the ends of each row, the last row's outer edge) hold for their true size; only
-- neighbours move into each other.
local function rowsFor(widths: { number }, order: { number }, options: Options, squeeze: number): ({ Row }, number)
	local rows: { Row } = {}
	local next = 1
	-- Where the next row's inner edge may start.
	local base = options.inner
	local reach = 0
	-- How far from its row's center line a place stands out on each side, studs, past its squeezed
	-- half: at the ends of a row and inside the first row.
	local function overhang(width: number): number
		return width * (1 - squeeze) / 2
	end
	local function radiusFor(widest: number): number
		local radius = base + widest * squeeze / 2
		if #rows == 0 then
			radius += overhang(widest)
		end
		return radius
	end
	while next <= #order do
		local members: { number } = {}
		local used = 0
		local widest = 0
		local narrowest = widths[order[next]]
		while next <= #order do
			local index = order[next]
			local width = widths[index]
			local length = width * squeeze + options.gap
			local wider = math.max(widest, width)
			local room = radiusFor(wider) * options.arc - 2 * overhang(wider)
			-- A row holds at least one place, however wide.
			if #members > 0 and (used + length > room or width > narrowest * options.rowSpread) then
				break
			end
			table.insert(members, index)
			used += length
			widest = wider
			next += 1
		end
		local radius = radiusFor(widest)
		table.insert(rows, { radius = radius, members = members })
		reach = radius + widest / 2
		base = radius + widest * squeeze / 2 + options.gap
	end
	return rows, reach
end

function PlaceLayout.arrange(widths: { number }, options: Options): Layout
	assert(options.minSqueeze > 0 and options.minSqueeze <= 1, "minSqueeze must be in (0, 1]")
	assert(options.squeezeStep > 0, "squeezeStep must be positive")
	if #widths == 0 then
		local none: { Spot } = {}
		return table.freeze({ spots = table.freeze(none), squeeze = 1, reach = 0 })
	end
	local order: { number } = {}
	for index, width in widths do
		assert(width > 0, `place {index} has no width`)
		order[index] = index
	end
	-- Smallest first; equal widths keep their order, so the layout never shuffles at random.
	table.sort(order, function(a, b)
		if widths[a] ~= widths[b] then
			return widths[a] < widths[b]
		end
		return a < b
	end)

	local squeeze = 1
	local rows, reach = rowsFor(widths, order, options, squeeze)
	while reach > options.outer and squeeze - options.squeezeStep >= options.minSqueeze - 1e-9 do
		squeeze -= options.squeezeStep
		rows, reach = rowsFor(widths, order, options, squeeze)
	end

	local spots: { Spot } = {}
	for _, row in rows do
		-- The biggest in the middle, the rest to either side of it, getting smaller.
		local byWidth = table.clone(row.members)
		table.sort(byWidth, function(a, b)
			if widths[a] ~= widths[b] then
				return widths[a] > widths[b]
			end
			return a < b
		end)
		local line: { number } = {}
		for position, index in byWidth do
			if position % 2 == 0 then
				table.insert(line, index)
			else
				table.insert(line, 1, index)
			end
		end
		local total = -options.gap
		for _, index in line do
			total += widths[index] * squeeze + options.gap
		end
		-- Along the row's arc, from its left end: angle 0 is the back of the island.
		local along = -total / 2
		for _, index in line do
			local width = widths[index] * squeeze
			local angle = (along + width / 2) / row.radius
			spots[index] = table.freeze({ x = row.radius * math.sin(angle), z = row.radius * math.cos(angle) })
			along += width + options.gap
		end
	end
	return table.freeze({ spots = table.freeze(spots), squeeze = squeeze, reach = reach })
end

return table.freeze(PlaceLayout)
