--!strict
-- Which guardian post a nest gets. Nests are ranked by distance from the station and split into
-- equal groups, one per post, so the farther the nest, the faster its guardian and the richer
-- its eggs' grade.

local Posts = {}

-- The post (1-based) of the nest ranked `rank` of `nestCount`, given `postCount` posts.
function Posts.indexFor(rank: number, nestCount: number, postCount: number): number
	assert(postCount >= 1, "there must be at least one post")
	assert(nestCount >= 1 and rank >= 1 and rank <= nestCount, "nest rank out of range")
	return math.clamp(math.ceil(rank / nestCount * postCount), 1, postCount)
end

return table.freeze(Posts)
