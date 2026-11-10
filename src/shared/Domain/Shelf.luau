--!strict
-- The island's shelf (docs/design/screens/storage-shelf.md): which niche the n-th alien with no
-- place stands in, and where that is. Pure Luau; the numbers are Config/ShelfShape's, the frame is
-- the shelf's own (see there): -Z out of the niches, the arc bending toward -Z.
--
-- Niches fill from the middle tier (eye level) outward, below before above, and in each tier from
-- the middle column outward: a few aliens stand as a group in the middle, not in a corner.

local Shelf = {}

export type Shape = {
	read COLUMNS: number,
	read TIERS: number,
	read CELL_WIDTH: number,
	read CELL_HEIGHT: number,
	read DEPTH: number,
	read RADIUS: number,
	read BASE_HEIGHT: number,
	read BOARD_THICKNESS: number,
	read CROWN_HEIGHT: number,
	read UPRIGHT_WIDTH: number,
	read BACK_THICKNESS: number,
}

-- A niche: its column (1 at -X) and tier (1 at the bottom).
export type Niche = {
	column: number,
	tier: number,
}

-- Where an alien stands in a niche: the middle of its board's top, and the turn about Y that faces
-- it out of the niche (CFrame.Angles(0, angle, 0) turns -Z to the niche's facing).
export type Spot = {
	x: number,
	y: number,
	z: number,
	angle: number,
}

-- 1..count ordered from the middle outward, the lower first of two as far from it.
local function middleOut(count: number): { number }
	local order: { number } = {}
	for index = 1, count do
		table.insert(order, index)
	end
	local middle = (count + 1) / 2
	table.sort(order, function(a: number, b: number): boolean
		local da, db = math.abs(a - middle), math.abs(b - middle)
		if da ~= db then
			return da < db
		end
		return a < b
	end)
	return order
end

function Shelf.capacity(shape: Shape): number
	return shape.COLUMNS * shape.TIERS
end

-- The niche of the `index`-th alien on the shelf (1-based); nil past the last niche.
function Shelf.niche(index: number, shape: Shape): Niche?
	if index < 1 or index > Shelf.capacity(shape) or index % 1 ~= 0 then
		return nil
	end
	local tiers = middleOut(shape.TIERS)
	local columns = middleOut(shape.COLUMNS)
	local tierAt = (index - 1) // shape.COLUMNS + 1
	local columnAt = (index - 1) % shape.COLUMNS + 1
	return { column = columns[columnAt], tier = tiers[tierAt] }
end

-- The angle of `column`'s middle round the arc's centre: 0 in the middle, negative toward -X.
function Shelf.columnAngle(column: number, shape: Shape): number
	return (column - (shape.COLUMNS + 1) / 2) * shape.CELL_WIDTH / shape.RADIUS
end

-- Where an alien stands in `niche`.
function Shelf.spot(niche: Niche, shape: Shape): Spot
	local angle = Shelf.columnAngle(niche.column, shape)
	local radius = shape.RADIUS
	return {
		x = radius * math.sin(angle),
		y = shape.BASE_HEIGHT + (niche.tier - 1) * shape.CELL_HEIGHT + shape.BOARD_THICKNESS,
		z = -(radius - radius * math.cos(angle)),
		-- Facing the arc's centre, (0, 0, -radius).
		angle = angle,
	}
end

-- The clear room in a niche for an alien: between the uprights, and from its board to the next
-- one (or the crown).
function Shelf.room(shape: Shape): (number, number)
	return shape.CELL_WIDTH - shape.UPRIGHT_WIDTH, shape.CELL_HEIGHT - shape.BOARD_THICKNESS
end

-- The shelf's full height, plinth to crown.
function Shelf.height(shape: Shape): number
	return shape.BASE_HEIGHT + shape.TIERS * shape.CELL_HEIGHT + shape.CROWN_HEIGHT
end

return table.freeze(Shelf)
