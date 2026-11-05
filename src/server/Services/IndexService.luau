--!strict
-- The alien index on the server: marks aliens found as they come to the player (hatched,
-- crossbred, given by a Studio command) and pays the rewards the player takes in the index
-- window: minutes of their own income for each new alien by tier, and more for a full guardian
-- set (Domain/AlienIndex, IndexConfig). All state lives in the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienIndex = require(ReplicatedStorage.Shared.Domain.AlienIndex)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local IndexConfig = require(ReplicatedStorage.Shared.Config.IndexConfig)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

export type Notice = AlienIndex.ClaimRefusal

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	getIncomePerSecond: (player: Player) -> BigNum.BigNum,
	-- Aliens that came to the player.
	hatched: Signal.Signal<Player, string, Bay.Location>,
	crossbred: Signal.Signal<Player, string, Bay.Location>,
}

export type IndexService = {
	name: string,
	start: () -> (),
	-- The player's index changed (a find, a claim).
	changed: Signal.Signal<Player>,
	-- An alien was found for the first time.
	discovered: Signal.Signal<Player, string>,
	-- A reward was taken: the coins, and what for (an alien id, or "Set" for a full set).
	rewarded: Signal.Signal<Player, BigNum.BigNum, string>,
	-- Marks an alien found (for aliens that come by other ways, like Studio commands).
	discover: (player: Player, alienId: string) -> (),
	claimAlien: (player: Player, alienId: string) -> Notice?,
	claimSet: (player: Player, setId: string) -> Notice?,
	-- Every reward waiting, at once.
	claimAll: (player: Player) -> Notice?,
}

local IndexService = {}

function IndexService.new(dependencies: Dependencies): IndexService
	local changed = Signal.new() :: Signal.Signal<Player>
	local discovered = Signal.new() :: Signal.Signal<Player, string>
	local rewarded = Signal.new() :: Signal.Signal<Player, BigNum.BigNum, string>

	local function discover(player: Player, alienId: string)
		if not AlienConfig.ALIENS[alienId] then
			return
		end
		local isNew = false
		dependencies.update(player, function(data)
			isNew = AlienIndex.discover(data.index, alienId)
		end)
		if isNew then
			changed.fire(player)
			discovered.fire(player, alienId)
		end
	end

	-- Pays `minutes` of income in the same update as `take` marks the reward taken.
	local function pay(
		player: Player,
		minutes: number,
		take: (data: PlayerData.PlayerData) -> Notice?
	): (Notice?, BigNum.BigNum)
		local income = dependencies.getIncomePerSecond(player)
		local notice: Notice? = "IndexNothing"
		local coins = BigNum.ZERO
		dependencies.update(player, function(data)
			notice = take(data)
			if notice then
				return
			end
			-- Only coins: the speed points of other rewards would be the trainer's, and the index
			-- is about collecting, not training.
			local pace = { income = income, trainerLevel = data.trainerLevel, jetpackLevel = data.jetpackLevel }
			local paid = PlayReward.of(minutes, pace, IndexConfig.MIN_REWARD_COINS, false, UpgradeConfig.TUNING)
			PlayReward.pay(data, paid)
			coins = paid.coins
		end)
		return notice, coins
	end

	local function claimAlien(player: Player, alienId: string): Notice?
		local alien = AlienConfig.ALIENS[alienId]
		if not alien then
			return "IndexNothing"
		end
		local notice, coins = pay(player, IndexConfig.REWARD_MINUTES[alien.tier], function(data)
			return AlienIndex.claim(data.index, alienId)
		end)
		if not notice then
			changed.fire(player)
			rewarded.fire(player, coins, alienId)
		end
		return notice
	end

	local function claimSet(player: Player, setId: string): Notice?
		local set = IndexConfig.SETS_BY_ID[setId]
		if not set then
			return "IndexNothing"
		end
		local notice, coins = pay(player, IndexConfig.SET_REWARD_MINUTES, function(data)
			return AlienIndex.claimSet(data.index, set)
		end)
		if not notice then
			changed.fire(player)
			rewarded.fire(player, coins, "Set")
		end
		return notice
	end

	-- Takes every reward waiting in the index, aliens and sets, each as if claimed on its own.
	local function claimAll(player: Player): Notice?
		local data = dependencies.getData(player)
		if not data then
			return "IndexNothing"
		end
		local aliens, sets = AlienIndex.pending(data.index, IndexConfig.SETS)
		if #aliens == 0 and #sets == 0 then
			return "IndexNothing"
		end
		for _, alienId in aliens do
			claimAlien(player, alienId)
		end
		for _, set in sets do
			claimSet(player, set.id)
		end
		return nil
	end

	local function start()
		dependencies.hatched.connect(function(player, alienId)
			discover(player, alienId)
		end)
		dependencies.crossbred.connect(function(player, alienId)
			discover(player, alienId)
		end)
	end

	return {
		name = "IndexService",
		start = start,
		changed = changed,
		discovered = discovered,
		rewarded = rewarded,
		discover = discover,
		claimAlien = claimAlien,
		claimSet = claimSet,
		claimAll = claimAll,
	}
end

return table.freeze(IndexService)
