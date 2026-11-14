--!strict
-- Which guardian stands at a nest of the world (decision 135). Each nest has a home post, the
-- post of the ring it stands on (Domain/NestLayout). Half of a post's nests, every other one,
-- are anchors and always keep their home post, so every guardian always has nests of its own
-- (the tutorial leads to the first one). The rest change their guardian each time they grow a
-- new egg: to the home post or one of its neighbours in the zone, never the one just there, so
-- the nests around a player show the guardians of their level and the ones next to it, and a
-- guardian passed by in a rush still turns up near the others. Pure: the random number comes in.

local NestPosts = {}

-- Whether the nest `indexInPost` (1 for the first of its post's nests) keeps its home post.
function NestPosts.isAnchor(indexInPost: number): boolean
	assert(indexInPost >= 1 and indexInPost % 1 == 0, `nest index {indexInPost} must be a whole number from 1`)
	return indexInPost % 2 == 1
end

-- The posts a changing nest of `home` may take in a zone of `postCount` posts: its home and the
-- neighbours on either side within the zone.
function NestPosts.choices(home: number, postCount: number): { number }
	assert(home >= 1 and home <= postCount and home % 1 == 0, `home post {home} out of range`)
	local result = {}
	for post = math.max(home - 1, 1), math.min(home + 1, postCount) do
		table.insert(result, post)
	end
	return result
end

-- The post a changing nest of `home`, now at `current`, takes for its new egg: one of its
-- choices other than `current`, picked by `roll` in [0, 1). With nothing else to take (a zone of
-- one post) it stays.
function NestPosts.next(current: number, home: number, postCount: number, roll: number): number
	local others = {}
	for _, post in NestPosts.choices(home, postCount) do
		if post ~= current then
			table.insert(others, post)
		end
	end
	if #others == 0 then
		return current
	end
	local index = math.clamp(math.floor(roll * #others) + 1, 1, #others)
	return others[index]
end

return table.freeze(NestPosts)
