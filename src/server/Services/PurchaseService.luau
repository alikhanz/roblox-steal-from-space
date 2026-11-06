--!strict
-- Robux purchases (decision 061). The one MarketplaceService.ProcessReceipt in the game:
--   1. waits for the player's active profile;
--   2. skips a receipt already granted (its PurchaseId is in the profile);
--   3. grants the product and records the receipt in one profile update;
--   4. waits until the store holds a save with the receipt in it;
--   5. only then answers PurchaseGranted; anything else is NotProcessedYet, and Roblox asks again
--      (CONVENTIONS section 7, ProfileStore's "Caching PurchaseId" example).
-- Passes: ownership is checked with Roblox on join and noted on purchase; the profile keeps a
-- copy for when Roblox's check fails. What each purchase does is Domain/Purchases; which ids
-- belong to this game is MonetizationConfig (in a game it does not list, purchases are off).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
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
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)

-- How long a receipt waits for the player's profile to become active, seconds.
local PROFILE_WAIT_SECONDS = 60
local PROFILE_POLL_SECONDS = 0.5
-- A pass check that fails is tried this many times in all.
local PASS_CHECK_TRIES = 2
local PASS_CHECK_RETRY_SECONDS = 5
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
}

export type PurchaseService = {
	name: string,
	start: () -> (),
	-- What the player's passes do (no profile: nothing).
	passEffects: (player: Player) -> Purchases.PassEffects,
	-- The egg the player is about to make ready now: the receipt applies to it when it comes.
	chooseReadyNowEgg: (player: Player, uid: number) -> Notice?,
	-- The receipt handler itself (dev commands run fake receipts through it).
	processReceipt: (receipt: { [string]: any }) -> Enum.ProductPurchaseDecision,
	-- Notes a pass as owned (on purchase; dev commands).
	notePass: (player: Player, pass: Purchases.PassId) -> boolean,
	-- Fires once per granted receipt.
	purchased: Signal.Signal<Player, Granted>,
	-- Fires when a pass was noted as owned.
	passesChanged: Signal.Signal<Player>,
}

local PurchaseService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function passOfId(catalog: MonetizationConfig.GameCatalog, gamePassId: number): Purchases.PassId?
	for pass, id in catalog.passes do
		if id == gamePassId then
			return pass
		end
	end
	return nil
end

function PurchaseService.new(dependencies: Dependencies): PurchaseService
	local purchased = Signal.new() :: Signal.Signal<Player, Granted>
	local passesChanged = Signal.new() :: Signal.Signal<Player>
	-- The egg each player chose to make ready now (session only: a late receipt picks one itself).
	local readyNowChoice: { [Player]: number } = {}

	local function passEffects(player: Player): Purchases.PassEffects
		local data = dependencies.getData(player)
		return Purchases.passEffects(if data then data.passes else {}, MonetizationConfig.PASS_TUNING)
	end

	local function notePass(player: Player, pass: Purchases.PassId): boolean
		local noted = false
		dependencies.update(player, function(data)
			noted = Purchases.notePass(data, pass)
		end)
		if noted then
			if LOG then
				print(`[PurchaseService] {player.Name} owns {pass}`)
			end
			passesChanged.fire(player)
		end
		return noted
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
		}
		local multiplier = Upgrades.jetpackMultiplier(data.jetpackLevel, UpgradeConfig.TUNING)
		local current = now()
		if product.kind == "Training" then
			local effects = Purchases.passEffects(data.passes, MonetizationConfig.PASS_TUNING)
			local rate = BigNum.mul(
				Upgrades.trainerRate(data.trainerLevel, UpgradeConfig.TUNING),
				BigNum.fromNumber(effects.trainerMultiplier)
			)
			local paid = Purchases.trainingPack(rate, product.seconds or 0, multiplier)
			data.trained = BigNum.add(data.trained, paid.trained)
			granted.speed = paid.speed
		elseif product.kind == "ReadyNow" then
			local made = Purchases.makeReady(data, readyNowChoice[player], product.tier or 1, function(egg)
				return MonetizationConfig.readyNowTierOf(egg.grade, egg.rarity)
			end, current)
			readyNowChoice[player] = nil
			if not made then
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
				local coins, trained = Purchases.takePendingDouble(data)
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
			if product.kind == "ReadyNow" or product.kind == "IncubatorSlot" then
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

	-- Asks Roblox which passes the player owns and notes them. A failed check keeps the copy in
	-- the profile as it is.
	local function checkPasses(player: Player)
		local catalog = MonetizationConfig.catalogFor(game.GameId)
		if not catalog then
			return
		end
		for pass, gamePassId in catalog.passes do
			for try = 1, PASS_CHECK_TRIES do
				local ok, owns =
					pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)
				if ok then
					if owns then
						notePass(player, pass)
					end
					break
				elseif try < PASS_CHECK_TRIES then
					task.wait(PASS_CHECK_RETRY_SECONDS)
				else
					warn(`[PurchaseService] Pass check for {player.Name} failed: {owns}`)
				end
			end
		end
	end

	local function start()
		MarketplaceService.ProcessReceipt = processReceipt
		dependencies.activated.connect(function(player)
			task.spawn(checkPasses, player)
		end)
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
			local catalog = MonetizationConfig.catalogFor(game.GameId)
			local pass = if catalog and wasPurchased then passOfId(catalog, gamePassId) else nil
			if pass then
				notePass(player, pass)
			end
		end)
		PlayerEvents.observe(function() end, function(player)
			readyNowChoice[player] = nil
		end)
	end

	return {
		name = "PurchaseService",
		start = start,
		passEffects = passEffects,
		chooseReadyNowEgg = chooseReadyNowEgg,
		processReceipt = processReceipt,
		notePass = notePass,
		purchased = purchased,
		passesChanged = passesChanged,
	}
end

return table.freeze(PurchaseService)
