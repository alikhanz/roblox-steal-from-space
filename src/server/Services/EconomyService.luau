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
	| "ShelfFull"
	| "NotEnoughCoins"
	| "MaxPods"
	| "NoSuchPod"
	| "WrongCount"
	| "MixedGrades"
	| "MixedTiers"
	| "MixedVariants"
	| "JetpackTop"
	| "MaxIncubatorSlots"

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- Rebuilds the player's bay after a change.
	refresh: (player: Player) -> (),
}

export type EconomyService = {
	name: string,
	autoPlace: (player: Player) -> Notice?,
	-- Puts the alien into pod `pod` (1-based); whoever stood there swaps with it (Bay.moveToPod).
	moveToPod: (player: Player, uid: number, pod: number) -> Notice?,
	-- Takes an alien out of its pod onto the shelf, while the shelf has room.
	moveToShelf: (player: Player, uid: number) -> Notice?,
	crossbreed: (player: Player, uids: { number }) -> Notice?,
	sell: (player: Player, uid: number) -> Notice?,
	-- Sells all of `uids` at once, or none of them ("Sell all", decision 110).
	sellMany: (player: Player, uids: { number }) -> Notice?,
	-- One more pod; the best of the shelf stands in it at once (decision 110).
	buyPod: (player: Player) -> Notice?,
	-- One more incubator slot.
	buyIncubatorSlot: (player: Player) -> Notice?,
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

export type CoinTrade = "Pod" | "IncubatorSlot" | "Trainer" | "Jetpack" | "Sell"

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
			Bay.autoPlace(data, incomeOf)
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
			Bay.moveToPod(data, uid, pod)
		end)
	end

	local function moveToShelf(player: Player, uid: number): Notice?
		return command(player, function(data)
			local _, location = Bay.find(data, if isUid(uid) then uid else 0)
			if location ~= "Pod" then
				return "UnknownAlien"
			end
			if #data.floor >= BayConfig.SHELF_SLOTS then
				return "ShelfFull"
			end
			return nil
		end, function(data)
			Bay.toShelf(data, uid, BayConfig.SHELF_SLOTS)
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
			-- The check passed: every parent shares the first one's grade, tier and variant.
			local first = AlienConfig.ALIENS[(Bay.find(data, uids[1]) :: PlayerData.AlienRecord).id]
			local kinds: { AlienConfig.KindId } = {}
			for _, uid in uids do
				local record = Bay.remove(data, uid) :: PlayerData.AlienRecord
				table.insert(kinds, AlienConfig.ALIENS[record.id].kind)
			end
			local entries = Crossbreed.resultEntries(
				AlienConfig.TIER_ORDER,
				AlienConfig.TIER_POSITIONS[first.tier],
				BayConfig.CROSSBREED_UP_CHANCE[first.tier]
			)
			local tier = Loot.pick(entries, random:NextNumber())
			local kind = Crossbreed.resultKind(kinds, random:NextNumber())
			resultId = AlienConfig.GRADES[first.grade].variants[first.variant][kind][tier]
			-- Three went, one comes: there is always room for it.
			resultLocation = Bay.addHatched(data, { uid = Bay.newUid(data), id = resultId :: string })
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

	-- Every uid a whole number, at most SELL_MANY_MAX of them (the client asks; the profile decides).
	local function isUidList(uids: any): boolean
		if type(uids) ~= "table" or #uids == 0 or #uids > BayConfig.SELL_MANY_MAX then
			return false
		end
		for _, uid in uids do
			if not isUid(uid) then
				return false
			end
		end
		return true
	end

	local function sellMany(player: Player, uids: { number }): Notice?
		local gained: BigNum.BigNum? = nil
		local balance: BigNum.BigNum? = nil
		local notice = command(player, function(data)
			if not isUidList(uids) then
				return "UnknownAlien"
			end
			local seen: { [number]: boolean } = {}
			for _, uid in uids do
				local record = if seen[uid] then nil else Bay.find(data, uid)
				if not record or not AlienConfig.ALIENS[record.id] then
					return "UnknownAlien"
				end
				seen[uid] = true
			end
			return nil
		end, function(data)
			local removed = Bay.removeMany(data, uids)
			if not removed then
				return
			end
			local total = BigNum.ZERO
			for _, record in removed do
				total = BigNum.add(total, incomeOf(record.id))
			end
			local price = BigNum.mul(total, BigNum.fromNumber(BayConfig.SELL_INCOME_SECONDS))
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
			-- The best of the shelf takes the new pod at once (decision 110).
			Bay.fillPod(data, #data.pods, incomeOf)
			balance = data.coins
		end)
		if not notice and paid and balance then
			coinsTraded.fire(player, "Pod", paid, balance)
		end
		return notice
	end

	local function slotPrice(data: PlayerData.PlayerData): BigNum.BigNum
		return Bay.slotPrice(
			data.incubatorSlots,
			BayConfig.STARTING_INCUBATOR_SLOTS,
			BayConfig.SLOT_PRICE_BASE,
			BayConfig.SLOT_PRICE_GROWTH
		)
	end

	-- One more incubator slot (decision 058); the first waiting egg moves straight into it.
	local function buyIncubatorSlot(player: Player): Notice?
		local paid: BigNum.BigNum? = nil
		local balance: BigNum.BigNum? = nil
		local notice = command(player, function(data)
			if data.incubatorSlots >= BayConfig.MAX_INCUBATOR_SLOTS then
				return "MaxIncubatorSlots"
			end
			if BigNum.lessThan(data.coins, slotPrice(data)) then
				return "NotEnoughCoins"
			end
			return nil
		end, function(data)
			-- Checked again inside the update: the profile is the one that counts.
			local cost = slotPrice(data)
			if data.incubatorSlots >= BayConfig.MAX_INCUBATOR_SLOTS or BigNum.lessThan(data.coins, cost) then
				return
			end
			data.coins = BigNum.sub(data.coins, cost)
			data.incubatorSlots += 1
			-- The bay's clock: BayService hatches against server time.
			Bay.fillSlots(data, workspace:GetServerTimeNow())
			paid, balance = cost, data.coins
		end)
		if not notice and paid and balance then
			coinsTraded.fire(player, "IncubatorSlot", paid, balance)
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
		local current = dependencies.getData(player)
		if current and current.jetpackLevel >= Upgrades.jetpackMaxLevel(UpgradeConfig.TUNING) then
			return "JetpackTop"
		end
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
		moveToShelf = moveToShelf,
		crossbreed = crossbreed,
		sell = sell,
		sellMany = sellMany,
		buyPod = buyPod,
		buyIncubatorSlot = buyIncubatorSlot,
		upgradeTrainer = upgradeTrainer,
		upgradeJetpack = upgradeJetpack,
		crossbred = crossbred,
		trainerUpgraded = trainerUpgraded,
		jetpackUpgraded = jetpackUpgraded,
		coinsTraded = coinsTraded,
	}
end

return table.freeze(EconomyService)
