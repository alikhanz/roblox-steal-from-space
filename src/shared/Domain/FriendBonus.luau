--!strict
-- The friend bonus (decision 128): +PERCENT_PER_FRIEND % pet income for each Roblox friend
-- playing on the same server, at most MAX_FRIENDS of them. It scales the coins the aliens on
-- places bring each second while the player is in the game (not the income of each alien, not
-- the time away, not the rewards worth minutes of play), so the server pays it and the HUD shows
-- it from here.
--
-- `Circle` keeps who is friends with whom on the server: the server asks Roblox once per pair
-- (when the later of the two joins) and forgets a player when they leave. Pure Luau: the
-- players are user ids.

local AlienIncome = require("./AlienIncome")
local BigNum = require("./BigNum")
local FriendConfig = require("../Config/FriendConfig")

export type Circle = {
	-- `a` and `b` are friends, both on the server.
	link: (a: number, b: number) -> (),
	-- `userId` left: they are nobody's friend here any more. Returns the friends they had here.
	forget: (userId: number) -> { number },
	-- How many friends `userId` has on the server.
	countOf: (userId: number) -> number,
	-- Their user ids.
	friendsOf: (userId: number) -> { number },
}

local FriendBonus = {}

-- The bonus in percent for `friends` friends on the server: 0, 10, 20, 30, then 30.
function FriendBonus.percentOf(friends: number): number
	assert(friends >= 0 and friends % 1 == 0, "friends are counted in whole players")
	return math.min(friends, FriendConfig.MAX_FRIENDS) * FriendConfig.PERCENT_PER_FRIEND
end

-- The most the bonus can be, in percent.
function FriendBonus.maxPercent(): number
	return FriendConfig.MAX_FRIENDS * FriendConfig.PERCENT_PER_FRIEND
end

-- What the bonus adds to `coins` the aliens earned (zero without friends).
function FriendBonus.extra(coins: BigNum.BigNum, friends: number): BigNum.BigNum
	local percent = FriendBonus.percentOf(friends)
	return if percent == 0 then BigNum.ZERO else AlienIncome.scaled(coins, percent)
end

-- `coins` with the bonus.
function FriendBonus.boosted(coins: BigNum.BigNum, friends: number): BigNum.BigNum
	return BigNum.add(coins, FriendBonus.extra(coins, friends))
end

function FriendBonus.newCircle(): Circle
	-- userId -> the user ids of their friends here.
	local links: { [number]: { [number]: true } } = {}

	local function linksOf(userId: number): { [number]: true }
		local found = links[userId]
		if not found then
			found = {}
			links[userId] = found
		end
		return found
	end

	local function friendsOf(userId: number): { number }
		local list = {}
		for friend in links[userId] or {} do
			table.insert(list, friend)
		end
		table.sort(list)
		return list
	end

	return {
		link = function(a: number, b: number)
			assert(a ~= b, "a player is not their own friend")
			linksOf(a)[b] = true
			linksOf(b)[a] = true
		end,
		forget = function(userId: number): { number }
			local friends = friendsOf(userId)
			for _, friend in friends do
				local theirs = links[friend]
				if theirs then
					theirs[userId] = nil
				end
			end
			links[userId] = nil
			return friends
		end,
		countOf = function(userId: number): number
			local total = 0
			for _ in links[userId] or {} do
				total += 1
			end
			return total
		end,
		friendsOf = friendsOf,
	}
end

return table.freeze(FriendBonus)
