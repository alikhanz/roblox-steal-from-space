--!strict
-- What a player can do with their bay and coins: place and move aliens, crossbreed, sell, buy
-- pods and upgrades. Every command checks the profile and the request, then applies one
-- change; the bay is rebuilt afterwards (which also sends the client its coins). Returns nil
-- on success or why the command was refused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Crossbreed = require(ReplicatedStorage.Shared.Domain.Crossbreed)
local Loot = require(ReplicatedStorage.Shared.Domain.Loot)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)

export type Notice =
	"NoProfile"
	| "UnknownAlien"
	| "InventoryFull"
	| "NotEnoughCoins"
	| "MaxPods"
	| "NoSuchPod"
	| "WrongCount"
	| "MixedGrades"
	| "MixedVariants"

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- Rebuilds the player's bay after a change.
	refresh: (player: Player) -> (),
}

export type EconomyService = {
	name: string,
	autoPlace: (player: Player) -> Notice?,
	-- Puts the alien into pod `pod` (1-based); whoever stood there goes to the inventory or floor.
	moveToPod: (player: Player, uid: number, pod: number) -> Notice?,
	moveToInventory: (player: Player, uid: number) -> Notice?,
	crossbreed: (player: Player, uids: { number }) -> Notice?,
	sell: (player: Player, uid: number) -> Notice?,
	buyPod: (player: Player) -> Notice?,
	-- Buys the next level of the trainer or the jetpack.
	upgradeTrainer: (player: Player) -> Notice?,
	upgradeJetpack: (player: Player) -> Notice?,
	-- Fires when a crossbreed produces an alien: the player, the alien and where it went.
	crossbred: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>,
	trainerUpgraded: Signal.Signal<Player>,
	jetpackUpgraded: Signal.Signal<Player>,
	-- Fires on every coin purchase or sale: the player, what (Pod, Trainer, Jetpack, Sell), the
	-- coins it cost (negative for a sale: coins gained) and the balance after (analytics).
	coinsTraded: Signal.Signal<Player, CoinTrade, BigNum.BigNum, BigNum.BigNum>,
}

export type CoinTrade = "Pod" | "Trainer" | "Jetpack" | "Sell"

local EconomyService = {}

local function incomeOf(alienId: string): BigNum.BigNum
	local alien = AlienConfig.ALIENS[alienId]
	return if alien then alien.income else BigNum.ZERO
end

local function isUid(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 1
end

function EconomyService.new(dependencies: Dependencies): EconomyService
	local random = Random.new()
	local crossbred = Signal.new() :: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>
	local trainerUpgraded = Signal.new() :: Signal.Signal<Player>
	local jetpackUpgraded = Signal.new() :: Signal.Signal<Player>
	local coinsTraded = Signal.new() :: Signal.Signal<Player, CoinTrade, BigNum.BigNum, BigNum.BigNum>

	-- Runs `check` on the live profile, then `apply` as one update, then rebuilds the bay.
	local function command(
		player: Player,
		check: (data: PlayerData.PlayerData) -> Notice?,
		apply: (data: PlayerData.PlayerData) -> ()
	): Notice?
		local data = dependencies.getData(player)
		if not data then
			return "NoProfile"
		end
		local notice = check(data)
		if notice then
			return notice
		end
		if not dependencies.update(player, apply) then
			return "NoProfile"
		end
		dependencies.refresh(player)
		return nil
	end

	local function autoPlace(player: Player): Notice?
		return command(player, function()
			return nil
		end, function(data)
			Bay.autoPlace(data, incomeOf, BayConfig.INVENTORY_SLOTS)
		end)
	end

	local function moveToPod(player: Player, uid: number, pod: number): Notice?
		return command(player, function(data)
			if not isUid(uid) or not Bay.find(data, uid) then
				return "UnknownAlien"
			end
			if not isUid(pod) or pod > #data.pods then
				return "NoSuchPod"
			end
			return nil
		end, function(data)
			local alien = Bay.remove(data, uid) :: PlayerData.AlienRecord
			local displaced = data.pods[pod].alien
			data.pods[pod].alien = alien
			if displaced then
				if #data.inventory < BayConfig.INVENTORY_SLOTS then
					table.insert(data.inventory, displaced)
				else
					table.insert(data.floor, displaced)
				end
			end
		end)
	end

	local function moveToInventory(player: Player, uid: number): Notice?
		return command(player, function(data)
			local _, location = Bay.find(data, if isUid(uid) then uid else 0)
			if not location then
				return "UnknownAlien"
			end
			if location ~= "Inventory" and #data.inventory >= BayConfig.INVENTORY_SLOTS then
				return "InventoryFull"
			end
			return nil
		end, function(data)
			local _, location = Bay.find(data, uid)
			if location ~= "Inventory" then
				table.insert(data.inventory, Bay.remove(data, uid) :: PlayerData.AlienRecord)
			end
		end)
	end

	local function crossbreed(player: Player, uids: { number }): Notice?
		local resultId: AlienConfig.AlienId? = nil
		local resultLocation: Bay.Location? = nil
		local notice = command(player, function(data)
			if #uids ~= BayConfig.CROSSBREED_COUNT then
				return "WrongCount"
			end
			local parents: { Crossbreed.Parent } = {}
			local seen: { [number]: boolean } = {}
			for _, uid in uids do
				local record = if isUid(uid) and not seen[uid] then Bay.find(data, uid) else nil
				local alien = record and AlienConfig.ALIENS[record.id]
				if not alien then
					return "UnknownAlien"
				end
				seen[uid] = true
				table.insert(parents, alien)
			end
			return Crossbreed.check(parents, BayConfig.CROSSBREED_COUNT)
		end, function(data)
			-- The check passed: every parent shares the first one's grade and variant.
			local first = AlienConfig.ALIENS[(Bay.find(data, uids[1]) :: PlayerData.AlienRecord).id]
			local positions = {}
			for _, uid in uids do
				local record = Bay.remove(data, uid) :: PlayerData.AlienRecord
				table.insert(positions, AlienConfig.TIER_POSITIONS[AlienConfig.ALIENS[record.id].tier])
			end
			local entries = Crossbreed.resultEntries(AlienConfig.HATCH_ENTRIES, positions, BayConfig.CROSSBREED_LUCK)
			local tier = Loot.pick(entries, random:NextNumber())
			resultId = AlienConfig.GRADES[first.grade].variants[first.variant][tier]
			resultLocation =
				Bay.addCrossbred(data, { uid = Bay.newUid(data), id = resultId :: string }, BayConfig.INVENTORY_SLOTS)
		end)
		if not notice and resultId and resultLocation then
			crossbred.fire(player, resultId, resultLocation)
		end
		return notice
	end

	local function sell(player: Player, uid: number): Notice?
		local gained: BigNum.BigNum? = nil
		local balance: BigNum.BigNum? = nil
		local notice = command(player, function(data)
			local record = if isUid(uid) then Bay.find(data, uid) else nil
			return if record and AlienConfig.ALIENS[record.id] then nil else "UnknownAlien"
		end, function(data)
			local record = Bay.remove(data, uid) :: PlayerData.AlienRecord
			local price = BigNum.mul(incomeOf(record.id), BigNum.fromNumber(BayConfig.SELL_INCOME_SECONDS))
			Wallet.earn(data, price)
			gained, balance = price, data.coins
		end)
		if not notice and gained and balance then
			coinsTraded.fire(player, "Sell", BigNum.mul(gained, BigNum.fromNumber(-1)), balance)
		end
		return notice
	end

	local function price(data: PlayerData.PlayerData): BigNum.BigNum
		return Bay.podPrice(#data.pods, BayConfig.STARTING_PODS, BayConfig.POD_PRICE_BASE, BayConfig.POD_PRICE_GROWTH)
	end

	local function buyPod(player: Player): Notice?
		local paid: BigNum.BigNum? = nil
		local balance: BigNum.BigNum? = nil
		local notice = command(player, function(data)
			if #data.pods >= BayConfig.MAX_PODS then
				return "MaxPods"
			end
			if BigNum.lessThan(data.coins, price(data)) then
				return "NotEnoughCoins"
			end
			return nil
		end, function(data)
			-- Checked again inside the update: the profile is the one that counts.
			if #data.pods >= BayConfig.MAX_PODS or BigNum.lessThan(data.coins, price(data)) then
				return
			end
			paid = price(data)
			data.coins = BigNum.sub(data.coins, price(data))
			table.insert(data.pods, {})
			balance = data.coins
		end)
		if not notice and paid and balance then
			coinsTraded.fire(player, "Pod", paid, balance)
		end
		return notice
	end

	-- Spends coins on the next level of an upgrade; `priceOf` and `level` read the live profile.
	local function upgrade(
		player: Player,
		priceOf: (data: PlayerData.PlayerData) -> BigNum.BigNum,
		raise: (data: PlayerData.PlayerData) -> (),
		upgraded: Signal.Signal<Player>,
		trade: CoinTrade
	): Notice?
		local paid: BigNum.BigNum? = nil
		local balance: BigNum.BigNum? = nil
		local notice = command(player, function(data)
			return if BigNum.lessThan(data.coins, priceOf(data)) then "NotEnoughCoins" else nil
		end, function(data)
			local cost = priceOf(data)
			-- Checked again inside the update: the profile is the one that counts.
			if BigNum.lessThan(data.coins, cost) then
				return
			end
			data.coins = BigNum.sub(data.coins, cost)
			raise(data)
			paid, balance = cost, data.coins
		end)
		if not notice then
			upgraded.fire(player)
			if paid and balance then
				coinsTraded.fire(player, trade, paid, balance)
			end
		end
		return notice
	end

	local function upgradeTrainer(player: Player): Notice?
		return upgrade(player, function(data)
			return Upgrades.trainerPrice(data.trainerLevel, UpgradeConfig.TUNING)
		end, function(data)
			data.trainerLevel += 1
		end, trainerUpgraded, "Trainer")
	end

	local function upgradeJetpack(player: Player): Notice?
		return upgrade(player, function(data)
			return Upgrades.jetpackPrice(data.jetpackLevel, UpgradeConfig.TUNING)
		end, function(data)
			data.jetpackLevel += 1
		end, jetpackUpgraded, "Jetpack")
	end

	return {
		name = "EconomyService",
		autoPlace = autoPlace,
		moveToPod = moveToPod,
		moveToInventory = moveToInventory,
		crossbreed = crossbreed,
		sell = sell,
		buyPod = buyPod,
		upgradeTrainer = upgradeTrainer,
		upgradeJetpack = upgradeJetpack,
		crossbred = crossbred,
		trainerUpgraded = trainerUpgraded,
		jetpackUpgraded = jetpackUpgraded,
		coinsTraded = coinsTraded,
	}
end

return table.freeze(EconomyService)
