--!strict
-- The gift for joining the game's Roblox community (decision 098): trained speed, once per
-- profile, offered once the tutorial is done. Whether the player is in the community is the
-- server's to ask Roblox; this module decides what that answer pays. Pure Luau.

local BigNum = require("./BigNum")
local Tutorial = require("./Tutorial")
local Upgrades = require("./Upgrades")

local CommunityGift = {}

-- What of the profile the gift reads and writes.
export type Profile = {
	trained: BigNum.BigNum,
	tutorialStep: number,
	communityGiftTaken: boolean,
}

-- The gift may still come: not taken yet, and the tutorial is done (before it, the gift would
-- skip what the tutorial teaches).
function CommunityGift.isOffered(data: Profile): boolean
	return not data.communityGiftTaken and data.tutorialStep >= Tutorial.DONE
end

-- Pays the gift into `data` for a player found in the community: `gift` trained speed, and the
-- gift is marked taken, so leaving and joining again pays nothing. False when not offered.
function CommunityGift.claim(data: Profile, gift: BigNum.BigNum): boolean
	if not CommunityGift.isOffered(data) then
		return false
	end
	data.trained = BigNum.add(data.trained, gift)
	data.communityGiftTaken = true
	return true
end

-- The stat `gift` trained speed adds with a jetpack at `jetpackLevel`: what the invitation
-- promises and the toast says.
function CommunityGift.shown(gift: BigNum.BigNum, jetpackLevel: number, tuning: Upgrades.Tuning): BigNum.BigNum
	return Upgrades.speed(gift, jetpackLevel, tuning)
end

-- Whether `groups`, the list Roblox gives for a user (GroupService:GetGroupsAsync, entries with
-- an `Id`), has the community `communityId`.
function CommunityGift.isMember(groups: { any }, communityId: number): boolean
	for _, group in groups do
		if type(group) == "table" and group.Id == communityId then
			return true
		end
	end
	return false
end

return table.freeze(CommunityGift)
