--!strict
-- How fast the local player is going, on one slow beat (decision 141): the pods' income, the speed
-- stat and what a reward worth some minutes of play pays (Domain/PlayReward, the same formula the
-- server pays with). They are taken from the profile copy every BEAT_SECONDS and passed on only
-- when they moved, so whatever follows income or ⚡ (the income line, the rewards of quests, the
-- index and the login gift, the guardians' signs, the jetpack shop's gain) is worked out at most
-- that often, not on every change of the bay, the coins earned or ⚡. The coin balance, the ⚡
-- plaque and the speed goal read the live sources.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienIncome = require(ReplicatedStorage.Shared.Domain.AlienIncome)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local ProfileState = require(script.Parent.ProfileState)
local SpeedState = require(script.Parent.SpeedState)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)

-- How often the numbers are taken again.
local BEAT_SECONDS = 3

-- What a reward needs besides the income.
type Levels = {
	trainerLevel: number,
	jetpackLevel: number,
	coinsEarned: BigNum.BigNum,
}

export type Dependencies = {
	profile: ProfileState.ProfileState,
	speed: SpeedState.SpeedState,
}

export type PaceState = {
	name: string,
	start: () -> (),
	-- Coins a second from the places (each alien by its own roll), as of the last beat (reactive).
	income: () -> BigNum.BigNum,
	-- The speed stat as of the last beat (reactive).
	speed: () -> BigNum.BigNum,
	-- What `minutes` of play pay: coins, and the speed stat gained when `withSpeed`; with `share`,
	-- no more than that share of the coins earned and the trained points allow (decision 114).
	-- Reactive on the beat.
	reward: (
		minutes: number,
		minimumCoins: BigNum.BigNum,
		withSpeed: boolean,
		share: number?
	) -> (BigNum.BigNum, BigNum.BigNum),
}

local PaceState = {}

function PaceState.new(dependencies: Dependencies): PaceState
	local profile = dependencies.profile

	local function levelsNow(): Levels
		local upgrades = profile.upgrades()
		return {
			trainerLevel = upgrades.trainerLevel,
			jetpackLevel = upgrades.jetpackLevel,
			coinsEarned = profile.coinsEarned(),
		}
	end

	local function incomeNow(): BigNum.BigNum
		return Bay.incomePerSecond(profile.bay(), AlienIncome.of)
	end

	local income = Vide.source(Vide.untrack(incomeNow))
	local speed = Vide.source(Vide.untrack(dependencies.speed.speed))
	local levels = Vide.source(Vide.untrack(levelsNow))

	-- Takes the numbers again; each source is written only when its value moved.
	local function beat()
		Vide.untrack(function()
			local newIncome = incomeNow()
			if not BigNum.equals(newIncome, income()) then
				income(newIncome)
			end
			local newSpeed = dependencies.speed.speed()
			if not BigNum.equals(newSpeed, speed()) then
				speed(newSpeed)
			end
			local newLevels = levelsNow()
			local old = levels()
			if
				newLevels.trainerLevel ~= old.trainerLevel
				or newLevels.jetpackLevel ~= old.jetpackLevel
				or not BigNum.equals(newLevels.coinsEarned, old.coinsEarned)
			then
				levels(newLevels)
			end
		end)
	end

	local function reward(
		minutes: number,
		minimumCoins: BigNum.BigNum,
		withSpeed: boolean,
		share: number?
	): (BigNum.BigNum, BigNum.BigNum)
		local current = levels()
		local pace = {
			income = income(),
			trainerLevel = current.trainerLevel,
			jetpackLevel = current.jetpackLevel,
		}
		local limit: PlayReward.Limit? = nil
		if share then
			local multiplier = Upgrades.jetpackMultiplier(current.jetpackLevel, UpgradeConfig.TUNING)
			limit = {
				share = share,
				trained = BigNum.div(speed(), multiplier),
				coinsEarned = current.coinsEarned,
			}
		end
		local paid = PlayReward.of(minutes, pace, minimumCoins, withSpeed, UpgradeConfig.TUNING, limit)
		return paid.coins, paid.speed
	end

	local function start()
		-- The profile's arrival is taken at once: the income line should not wait a beat for it.
		Vide.root(function()
			Vide.effect(function()
				if profile.loaded() then
					beat()
				end
			end)
		end)
		local since = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			since += deltaTime
			if since >= BEAT_SECONDS then
				since = 0
				beat()
			end
		end)
	end

	return {
		name = "PaceState",
		start = start,
		income = function(): BigNum.BigNum
			return income()
		end,
		speed = function(): BigNum.BigNum
			return speed()
		end,
		reward = reward,
	}
end

return table.freeze(PaceState)
