--!strict
-- The star serpent's body follows its head the way a snake does: every segment lies on the path
-- the head has flown, a fixed distance behind the one before. The path is a trail of the head's
-- past positions, newest first. Pure: works only with the vectors it is given.

local SerpentBody = {}

-- Adds the head's position to the front of `trail` once it has moved `step` studs from the last
-- one, and drops the end past `length` studs of path (all the body needs).
function SerpentBody.record(trail: { Vector3 }, head: Vector3, step: number, length: number)
	local last = trail[1]
	if last and (head - last).Magnitude < step then
		return
	end
	table.insert(trail, 1, head)
	local covered = 0
	for index = 2, #trail do
		covered += (trail[index] - trail[index - 1]).Magnitude
		if covered > length then
			-- Keep this point: the path must reach past `length`.
			for _ = index + 1, #trail do
				table.remove(trail)
			end
			return
		end
	end
end

-- Where `count` segments go, `spacing` studs apart along the path from `head` back through
-- `trail`. Segments past the end of the path bunch up at its end (a serpent just out of its lair).
function SerpentBody.place(head: Vector3, trail: { Vector3 }, spacing: number, count: number): { Vector3 }
	local result: { Vector3 } = {}
	local from = head
	local index = 1
	-- How far along the current piece of path the next segment lies.
	local want = spacing
	while #result < count do
		local to = trail[index]
		if not to then
			-- No path left: the rest wait at its end.
			while #result < count do
				table.insert(result, from)
			end
			break
		end
		local piece = (to - from).Magnitude
		if piece >= want and piece > 0 then
			from = from + (to - from) * (want / piece)
			table.insert(result, from)
			want = spacing
		else
			want -= piece
			from = to
			index += 1
		end
	end
	return result
end

-- The thickness of segment `index` of `count`, from `first` at the neck down to `last` at the tail.
function SerpentBody.sizeOf(index: number, count: number, first: number, last: number): number
	local share = if count > 1 then (index - 1) / (count - 1) else 0
	return first + (last - first) * share
end

-- How a copy of a segment made `made` thick is stretched to be `size` thick: across and up by
-- size / made, along the body less (to `floor` of it at the least), so thin segments, still the
-- same distance apart, close up into one body.
function SerpentBody.stretchOf(size: number, made: number, floor: number): (number, number)
	local across = size / made
	return across, floor + (1 - floor) * across
end

export type Sphere = {
	read center: Vector3,
	read radius: number,
}

-- What attacks land on (the server's measure of the body the clients draw): a sphere of
-- `headRadius` round the head, then one per segment laid down the path behind the neck as
-- `place` lays them (`count` of them, `spacing` apart, `first` thick at the neck down to `last`),
-- each `padding` wider than the segment.
function SerpentBody.hitSpheres(
	head: Vector3,
	headRadius: number,
	neck: Vector3,
	trail: { Vector3 },
	spacing: number,
	count: number,
	first: number,
	last: number,
	padding: number
): { Sphere }
	local spheres: { Sphere } = { { center = head, radius = headRadius } }
	for index, center in SerpentBody.place(neck, trail, spacing, count) do
		local size = SerpentBody.sizeOf(index, count, first, last)
		table.insert(spheres, { center = center, radius = size / 2 + padding })
	end
	return spheres
end

-- Whether segment `index` wears the stars on its flanks: every `every`-th.
function SerpentBody.starred(index: number, every: number): boolean
	return every > 0 and index % every == 0
end

return table.freeze(SerpentBody)
