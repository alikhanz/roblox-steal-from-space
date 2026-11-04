--!strict
-- How fast the local player is going right now, from the profile copy: the income of the pods
-- and what a reward worth some minutes of play would pay (Domain/PlayReward, the same formula
-- the server pays with). Quests, the login gift and the index show their rewards through it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local ProfileState = require(script.Parent.ProfileState)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

local Pace = {}

local function incomeOf(alienId: string): BigNum.BigNum
	local alien = AlienConfig.ALIENS[alienId]
	return if alien then alien.income else BigNum.ZERO
end

-- Coins per second from the pods.
function Pace.income(profile: ProfileState.ProfileState): BigNum.BigNum
	return Bay.incomePerSecond(profile.bay(), incomeOf)
end

-- What `minutes` of play pay now: coins, and the speed stat gained when `withSpeed`. Reads Vide
-- sources, so it recomputes as the profile changes.
function Pace.reward(
	profile: ProfileState.ProfileState,
	minutes: number,
	minimumCoins: BigNum.BigNum,
	withSpeed: boolean
): (BigNum.BigNum, BigNum.BigNum)
	local upgrades = profile.upgrades()
	local pace = {
		income = Pace.income(profile),
		trainerLevel = upgrades.trainerLevel,
		jetpackLevel = upgrades.jetpackLevel,
	}
	local paid = PlayReward.of(minutes, pace, minimumCoins, withSpeed, UpgradeConfig.TUNING)
	return paid.coins, paid.speed
end

return table.freeze(Pace)
