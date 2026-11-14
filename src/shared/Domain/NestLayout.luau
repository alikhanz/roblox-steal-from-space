--!strict
-- Where a zone's nests lie (decision 057): its ring is split into one narrow ring per guardian
-- post, the zone's first post innermost, its last outermost, and each post's nests stand on its
-- own ring at even angles (with a little jitter). So the nests around a player are of one level,
-- and flying out from the station the guardians grow stronger step by step, never jumping. The
-- rings' nests are turned against each other so they do not line up radially. Pure: the random
-- numbers come in.

local NestLayout = {}

export type Ring = {
	read ringMin: number,
	read ringMax: number,
	read heightSpread: number,
	read postCount: number,
	read nestsPerPost: number,
}

export type Spot = {
	-- The guardian post within the zone (1 innermost).
	post: number,
	-- Its place among its post's nests, from 1.
	index: number,
	-- Around the station, radians.
	angle: number,
	-- From the station, studs.
	distance: number,
	-- Above or below the station's level, studs.
	height: number,
}

-- How far a nest may stray from its post's ring, as a share of half the ring's width: it stays
-- inside its own ring, so every nest of a post is nearer than every nest of the next.
local RADIAL_JITTER = 0.6
-- How far a nest may stray from its even angle, as a share of the step between them.
local ANGLE_JITTER = 0.25
-- Each post's ring is turned by this much more than the one inside it (the golden angle), so
-- nests of neighbouring posts do not sit in a line.
local RING_TURN = math.pi * (3 - math.sqrt(5))

-- The middle of guardian `post`'s own ring within the zone's, and how far a nest may stray from
-- it either way, studs: every nest of the post, and every meteor crater of it, lies within.
function NestLayout.postBand(ring: Ring, post: number): (number, number)
	assert(ring.postCount >= 1, "a zone needs posts")
	assert(ring.ringMax > ring.ringMin, "a zone's ring needs a width")
	assert(post >= 1 and post <= ring.postCount and post % 1 == 0, `post {post} out of range`)
	local width = (ring.ringMax - ring.ringMin) / ring.postCount
	return ring.ringMin + (post - 0.5) * width, RADIAL_JITTER * width / 2
end

-- Every nest of the zone, post by post, each post's in order (its `index` among them). `random`
-- gives numbers in [0, 1).
function NestLayout.place(ring: Ring, random: () -> number): { Spot }
	assert(ring.postCount >= 1 and ring.nestsPerPost >= 1, "a zone needs posts and nests")
	local spots: { Spot } = {}
	for post = 1, ring.postCount do
		local middle, stray = NestLayout.postBand(ring, post)
		for index = 1, ring.nestsPerPost do
			local step = (index - 1 + (random() * 2 - 1) * ANGLE_JITTER) / ring.nestsPerPost
			table.insert(spots, {
				post = post,
				index = index,
				angle = step * math.pi * 2 + post * RING_TURN,
				distance = middle + (random() * 2 - 1) * stray,
				height = (random() * 2 - 1) * ring.heightSpread,
			})
		end
	end
	return spots
end

return table.freeze(NestLayout)
