--!strict
-- The game's Roblox community and the one-time gift for joining it (decision 098,
-- Domain/CommunityGift). Pure Luau: tests load it in Lune.

local BigNum = require("../Domain/BigNum")

-- Each game's community, by game id (decision 011: Dev and Prod are separate games). Both share
-- one community, but each game is listed on its own, like MonetizationConfig's catalogs.
local COMMUNITIES: { [number]: number } = {
	-- Steal from Space Dev: Fly & Steal Space Eggs.
	[10774871729] = 1096766348,
	-- Fly & Steal Space Eggs (Prod, owned by the community).
	[10775754016] = 1096766348,
}

local CommunityConfig = {}

-- Trained speed the gift adds: the stat shows it times the jetpack's multiplier, so the gift is
-- worth the same share whenever it is taken (user, 2026-11-10).
CommunityConfig.GIFT_TRAINED = BigNum.fromNumber(10000)
-- Asking Roblox about a player's communities: this many tries, this far apart, seconds.
CommunityConfig.CHECK_ATTEMPTS = 3
CommunityConfig.CHECK_RETRY_SECONDS = 2
-- A player may ask for a new check (after Roblox's join prompt) at most this often, seconds.
CommunityConfig.RECHECK_SECONDS = 5
-- Player attribute: the gift is taken (false: not yet; none: no profile yet).
CommunityConfig.GIFT_TAKEN_ATTRIBUTE = "CommunityGiftTaken"

-- The community of the game with `gameId`, or nil: no invitation and no gift in a game not
-- listed here (an unpublished place in Studio has game id 0).
function CommunityConfig.communityFor(gameId: number): number?
	return COMMUNITIES[gameId]
end

return table.freeze(CommunityConfig)
