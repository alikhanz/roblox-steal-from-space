--!strict
-- Robux purchases (decisions 061, 132). The one MarketplaceService.ProcessReceipt in the game:
--   1. waits for the player's active profile;
--   2. skips a receipt already granted (its PurchaseId is in the profile);
--   3. grants the product and records the receipt in one profile update;
--   4. waits until the store holds a save with the receipt in it;
--   5. only then answers PurchaseGranted; anything else is NotProcessedYet, and Roblox asks again
--      (CONVENTIONS section 7, ProfileStore's "Caching PurchaseId" example).
-- Subscriptions (monthly, Roblox's own): their status is asked of Roblox on join, when Roblox says
-- it changed, after the player closes a subscription prompt and every few minutes while they
-- play; the profile keeps what the last answer said, which pays the time away and stands in when
-- Roblox's check fails. Whether Roblox lets the player subscribe at all (PolicyService) is published
-- for the shop. What each purchase does is Domain/Purchases; which ids belong to this game is
-- MonetizationConfig (in a game it does not list, purchases are off).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)

-- How long a receipt waits for the player's profile to become active, seconds.
local PROFILE_WAIT_SECONDS = 60
local PROFILE_POLL_SECONDS = 0.5
-- A subscription or policy check that fails is tried this many times in all.
local CHECK_TRIES = 2
local CHECK_RETRY_SECONDS = 5
-- While playing, a subscription that ran out (cancelled, not renewed) stops this soon.
local SUBSCRIPTION_POLL_SECONDS = 15 * 60
local LOG = RunService:IsStudio()

export type Notice = "NoSuchEgg"

-- What a granted purchase gave, for the client and the analytics.
export type Granted = {
	kind: MonetizationConfig.ProductKind,
	tier: number?,
	-- Nothing to apply it to: the player got coins instead (MonetizationConfig.COMPENSATION_MINUTES).
	compensated: boolean,
	coins: BigNum.BigNum,
	-- The speed stat added (trained points times the jetpack).
	speed: BigNum.BigNum,
	-- Where the player was last offered a purchase this session ("-": nowhere known).
	source: string,
	-- "Egg ready now" for the egg the player chose: it hatched at once (a late receipt, or one
	-- for another egg, only makes an egg ready).
	hatched: boolean,
	-- The egg it hatched.
	egg: number?,
}

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	waitUntilSaved: (player: Player, isSaved: (saved: { [string]: any }) -> boolean) -> boolean,
	getIncomePerSecond: (player: Player) -> BigNum.BigNum,
	-- Re-publishes the speed stat, and rebuilds the bay (an egg ready, a slot more).
	publishSpeed: (player: Player) -> (),
	refreshBay: (player: Player) -> (),
	-- Hatches a ready egg (an "Egg ready now" bought at that very egg hatches it at once).
	hatchEgg: (player: Player, uid: number) -> (),
	scheduler: Scheduler.Scheduler,
}

export type PurchaseService = {
	name: string,
	start: () -> (),
	-- What the player's subscriptions do (no profile: nothing).
	effects: (player: Player) -> Purchases.Effects,
	-- The egg the player is about to make ready now: the receipt applies to it when it comes.
	chooseReadyNowEgg: (player: Player, uid: number) -> Notice?,
	-- The client is about to show a purchase prompt: where (for the analytics) and, for
	-- "Egg ready now", which egg.
	notePrompt: (
		player: Player,
		item: MonetizationConfig.ShopItem,
		source: MonetizationConfig.ShopSource,
		egg: number?
	) -> Notice?,
	-- The receipt handler itself (dev commands run fake receipts through it).
	processReceipt: (receipt: { [string]: any }) -> Enum.ProductPurchaseDecision,
	-- The player closed a subscription prompt: their status is asked again.
	subscriptionPromptClosed: (player: Player) -> (),
	-- Sets a subscription in Studio, as if Roblox said so; Roblox's checks then leave this player's
	-- subscriptions alone until they leave (dev commands).
	setSubscribedForTest: (player: Player, subscription: Purchases.SubscriptionId, subscribed: boolean) -> boolean,
	-- Fires once per granted receipt.
	purchased: Signal.Signal<Player, Granted>,
	-- Fires when a subscription started or ended: the player, which one and whether it is on now.
	subscriptionChanged: Signal.Signal<Player, Purchases.SubscriptionId, boolean>,
	-- Fires for every purchase prompt a client reports.
	prompted: Signal.Signal<Player, MonetizationConfig.ShopItem, MonetizationConfig.ShopSource>,
}

local PurchaseService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function subscriptionOfId(
	catalog: MonetizationConfig.GameCatalog,
	subscriptionId: string
): Purchases.SubscriptionId?
	for subscription, id in catalog.subscriptions do
		if id == subscriptionId then
			return subscription
		end
	end
	return nil
end

-- Calls `ask` up to CHECK_TRIES times until it succeeds; its result, or nil when every try failed
-- (the last error is warned about).
local function withRetries<T>(what: string, ask: () -> T): T?
	for try = 1, CHECK_TRIES do
		local ok, result = pcall(ask)
		if ok then
			return result
		elseif try < CHECK_TRIES then
			task.wait(CHECK_RETRY_SECONDS)
		else
			warn(`[PurchaseService] {what} failed: {result}`)
		end
	end
	return nil
end

function PurchaseService.new(dependencies: Dependencies): PurchaseService
	local purchased = Signal.new() :: Signal.Signal<Player, Granted>
	local subscriptionChanged = Signal.new() :: Signal.Signal<Player, Purchases.SubscriptionId, boolean>
	local prompted = Signal.new() :: Signal.Signal<Player, MonetizationConfig.ShopItem, MonetizationConfig.ShopSource>
	-- The egg each player chose to make ready now (session only: a late receipt picks one itself).
	local readyNowChoice: { [Player]: number } = {}
	-- Where each player was last offered a purchase (session only), for the analytics.
	local lastSource: { [Player]: MonetizationConfig.ShopSource } = {}
	-- Players whose subscriptions a Studio command set: Roblox's checks leave them alone.
	local testOverrides: { [Player]: boolean } = {}

	local function effects(player: Player): Purchases.Effects
		local data = dependencies.getData(player)
		return Purchases.effects(if data then data.subscriptions else {}, MonetizationConfig.SUBSCRIPTION_TUNING)
	end

	-- The subscriptions on the player, for every client (the shop, the trainer sign over their bay).
	local function publish(player: Player)
		local data = dependencies.getData(player)
		if not data then
			return
		end
		local current = Purchases.effects(data.subscriptions, MonetizationConfig.SUBSCRIPTION_TUNING)
		player:SetAttribute(MonetizationConfig.SUBSCRIPTIONS_ATTRIBUTE, table.concat(data.subscriptions, ","))
		player:SetAttribute(MonetizationConfig.TRAINER_MULTIPLIER_ATTRIBUTE, current.trainerMultiplier)
	end

	local function setSubscribed(player: Player, subscription: Purchases.SubscriptionId, subscribed: boolean): boolean
		local changed = false
		dependencies.update(player, function(data)
			changed = Purchases.setSubscribed(data, subscription, subscribed)
		end)
		if changed then
			if LOG then
				print(`[PurchaseService] {player.Name}: {subscription} {if subscribed then "on" else "off"}`)
			end
			publish(player)
			subscriptionChanged.fire(player, subscription, subscribed)
		end
		return changed
	end

	-- Asks Roblox whether the player has `subscription` and notes the answer. A failed check keeps
	-- the profile's copy as it is.
	local function checkSubscription(player: Player, subscription: Purchases.SubscriptionId)
		local catalog = MonetizationConfig.catalogFor(game.GameId)
		local id = if catalog then catalog.subscriptions[subscription] else nil
		if not id or testOverrides[player] then
			return
		end
		local status = withRetries(`Subscription check of {subscription} for {player.Name}`, function()
			return MarketplaceService:GetUserSubscriptionStatusAsync(player, id)
		end)
		-- The player may have left, or a Studio command took over, while Roblox answered.
		if type(status) == "table" and player.Parent == Players and not testOverrides[player] then
			setSubscribed(player, subscription, status.IsSubscribed == true)
		end
	end

	local function checkSubscriptions(player: Player)
		for _, subscription in MonetizationConfig.SUBSCRIPTION_ORDER do
			checkSubscription(player, subscription)
		end
	end

	-- Whether Roblox lets the player buy subscriptions (the shop offers them only then). Unknown
	-- (the check failed) counts as no.
	local function checkPolicy(player: Player)
		local policy = withRetries(`Policy check for {player.Name}`, function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if player.Parent == Players then
			local eligible = type(policy) == "table" and policy.IsEligibleToPurchaseSubscription == true
			player:SetAttribute(MonetizationConfig.CAN_SUBSCRIBE_ATTRIBUTE, eligible)
		end
	end

	local function subscriptionPromptClosed(player: Player)
		task.spawn(checkSubscriptions, player)
		task.delay(MonetizationConfig.SUBSCRIPTION_RECHECK_SECONDS, function()
			if player.Parent == Players then
				checkSubscriptions(player)
			end
		end)
	end

	local function setSubscribedForTest(
		player: Player,
		subscription: Purchases.SubscriptionId,
		subscribed: boolean
	): boolean
		assert(RunService:IsStudio(), "subscriptions are set by hand only in Studio")
		if not dependencies.getData(player) then
			return false
		end
		testOverrides[player] = true
		setSubscribed(player, subscription, subscribed)
		return true
	end

	local function chooseReadyNowEgg(player: Player, uid: number): Notice?
		local data = dependencies.getData(player)
		local current = now()
		if data then
			for _, egg in data.incubator do
				if egg.uid == uid and not Bay.isReady(egg, current) then
					readyNowChoice[player] = uid
					return nil
				end
			end
		end
		return "NoSuchEgg"
	end

	local function notePrompt(
		player: Player,
		item: MonetizationConfig.ShopItem,
		source: MonetizationConfig.ShopSource,
		egg: number?
	): Notice?
		lastSource[player] = source
		prompted.fire(player, item, source)
		return if item == "ReadyNow" and egg then chooseReadyNowEgg(player, egg) else nil
	end

	-- Coins worth some minutes of the player's income, for a purchase with nothing to apply to.
	local function compensate(player: Player, data: PlayerData.PlayerData): BigNum.BigNum
		local coins = PlayReward.worth(
			MonetizationConfig.COMPENSATION_MINUTES,
			dependencies.getIncomePerSecond(player),
			BigNum.ZERO,
			BigNum.fromNumber(MonetizationConfig.COMPENSATION_MIN_COINS)
		)
		Wallet.earn(data, coins)
		return coins
	end

	-- What `product` does, inside the receipt's profile update (must not yield).
	local function grant(player: Player, data: PlayerData.PlayerData, product: MonetizationConfig.Product): Granted
		local granted: Granted = {
			kind = product.kind,
			tier = product.tier,
			compensated = false,
			coins = BigNum.ZERO,
			speed = BigNum.ZERO,
			source = lastSource[player] or "-",
			hatched = false,
		}
		local multiplier = Upgrades.jetpackMultiplier(data.jetpackLevel, UpgradeConfig.TUNING)
		local current = now()
		if product.kind == "Training" then
			local subscribed = Purchases.effects(data.subscriptions, MonetizationConfig.SUBSCRIPTION_TUNING)
			local rate = Purchases.trainerRate(data.trainerLevel, subscribed.trainerMultiplier, UpgradeConfig.TUNING)
			local paid = Purchases.trainingPack(rate, product.seconds or 0, multiplier)
			data.trained = BigNum.add(data.trained, paid.trained)
			granted.speed = paid.speed
		elseif product.kind == "ReadyNow" then
			local chosen = readyNowChoice[player]
			local made = Purchases.makeReady(data, chosen, product.tier or 1, function(egg)
				return MonetizationConfig.readyNowTierOf(egg.grade, egg.rarity)
			end, current)
			readyNowChoice[player] = nil
			if made and made == chosen then
				granted.hatched = true
				granted.egg = made
			elseif not made then
				granted.compensated = true
				granted.coins = compensate(player, data)
			end
		elseif product.kind == "IncubatorSlot" then
			if data.incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS then
				data.incubatorSlots += 1
				Bay.fillSlots(data, current)
			else
				granted.compensated = true
				granted.coins = compensate(player, data)
			end
		elseif product.kind == "CollectDouble" then
			if Purchases.hasPendingDouble(data) then
				-- A cheaper tier than the reward needs (a prompt from an older reward, or not from
				-- the screen at all) pays only up to that tier's limit (decision 064).
				local coins, trained =
					Purchases.takePendingDouble(data, MonetizationConfig.doubleLimitOf(product.tier or 1))
				Wallet.earn(data, coins)
				data.trained = BigNum.add(data.trained, trained)
				granted.coins = coins
				granted.speed = BigNum.mul(trained, multiplier)
			else
				granted.compensated = true
				granted.coins = compensate(player, data)
			end
		end
		return granted
	end

	local function waitForProfile(player: Player): PlayerData.PlayerData?
		local waited = 0
		while not dependencies.getData(player) and player.Parent == Players and waited < PROFILE_WAIT_SECONDS do
			task.wait(PROFILE_POLL_SECONDS)
			waited += PROFILE_POLL_SECONDS
		end
		return dependencies.getData(player)
	end

	local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
		local notYet = Enum.ProductPurchaseDecision.NotProcessedYet
		local catalog = MonetizationConfig.catalogFor(game.GameId)
		local product = if catalog then catalog.products[receipt.ProductId] else nil
		local purchaseId = receipt.PurchaseId
		if not product or type(purchaseId) ~= "string" then
			warn(`[PurchaseService] Unknown product {receipt.ProductId} in game {game.GameId}; not granted`)
			return notYet
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player or not waitForProfile(player) then
			return notYet
		end

		local granted: Granted? = nil
		local applied = dependencies.update(player, function(data)
			if Purchases.hasReceipt(data.purchaseIds, purchaseId) then
				return
			end
			granted = grant(player, data, product)
			Purchases.recordReceipt(data, purchaseId, MonetizationConfig.RECEIPTS_KEPT)
		end)
		if not applied then
			return notYet
		end
		local given = granted :: Granted?
		if given then
			if LOG then
				print(
					`[PurchaseService] {player.Name} bought {given.kind}{if given.tier then ` {given.tier}` else ""}`
						.. (if given.compensated then " (nothing to apply to: coins instead)" else "")
				)
			end
			dependencies.publishSpeed(player)
			if given.hatched and given.egg then
				-- Rebuilds the bay itself.
				dependencies.hatchEgg(player, given.egg)
			elseif product.kind == "ReadyNow" or product.kind == "IncubatorSlot" then
				dependencies.refreshBay(player)
			end
			purchased.fire(player, given)
		end

		local saved = dependencies.waitUntilSaved(player, function(lastSaved)
			local receipts = lastSaved.purchaseIds
			return type(receipts) == "table" and table.find(receipts, purchaseId) ~= nil
		end)
		return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else notYet
	end

	local function start()
		MarketplaceService.ProcessReceipt = processReceipt
		dependencies.activated.connect(function(player)
			-- The copy in the profile counts at once; Roblox's answer may change it.
			publish(player)
			task.spawn(checkSubscriptions, player)
			task.spawn(checkPolicy, player)
		end)
		Players.UserSubscriptionStatusChanged:Connect(function(player, subscriptionId)
			local catalog = MonetizationConfig.catalogFor(game.GameId)
			local subscription = if catalog then subscriptionOfId(catalog, subscriptionId) else nil
			if subscription then
				task.spawn(checkSubscription, player, subscription)
			end
		end)
		-- A cancelled subscription runs to the end of its month, then stops: noticed in play too.
		dependencies.scheduler.every(SUBSCRIPTION_POLL_SECONDS, function()
			for _, player in Players:GetPlayers() do
				if dependencies.getData(player) then
					task.spawn(checkSubscriptions, player)
				end
			end
		end)
		PlayerEvents.observe(function() end, function(player)
			readyNowChoice[player] = nil
			lastSource[player] = nil
			testOverrides[player] = nil
		end)
	end

	return {
		name = "PurchaseService",
		start = start,
		effects = effects,
		chooseReadyNowEgg = chooseReadyNowEgg,
		notePrompt = notePrompt,
		processReceipt = processReceipt,
		subscriptionPromptClosed = subscriptionPromptClosed,
		setSubscribedForTest = setSubscribedForTest,
		purchased = purchased,
		subscriptionChanged = subscriptionChanged,
		prompted = prompted,
	}
end

return table.freeze(PurchaseService)
