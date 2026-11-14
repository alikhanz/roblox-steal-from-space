--!strict
-- Robux purchases on the client (decisions 061, 132): this game's catalog, the prices Roblox shows
-- for it, the subscriptions the player has and the purchase prompts. A prompt only asks Roblox;
-- what a purchase gives comes from the server, by its receipt (PurchaseService), and arrives here
-- as `granted`; a subscription counts once the server has asked Roblox about it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)

-- A price Roblox did not give is asked for again once after this long, seconds.
local PRICE_RETRY_SECONDS = 15
-- Prices are asked for again when shown, but not more often than this, seconds.
local PRICE_REFRESH_SECONDS = 30

-- What a granted purchase gave (speed as the stat shows it).
export type Granted = {
	kind: MonetizationConfig.ProductKind,
	-- A week: whose perk.
	perk: Purchases.SubscriptionId?,
	compensated: boolean,
	-- "Egg ready now" hatched the chosen egg at once.
	hatched: boolean,
	coins: BigNum.BigNum,
	speed: BigNum.BigNum,
}

export type PurchaseState = {
	name: string,
	start: () -> (),
	-- Purchases are on: this game has a catalog (an unpublished place has none).
	available: boolean,
	-- The game sells this product (kind and tier, or training seconds).
	sells: (kind: MonetizationConfig.ProductKind, tier: number?, seconds: number?) -> boolean,
	-- Asks Roblox for the prices again (at most every 30 s): call it when prices come on screen.
	refreshPrices: () -> (),
	-- Roblox's price, in Robux (reactive); nil until Roblox answers, or when it does not.
	productPrice: (kind: MonetizationConfig.ProductKind, tier: number?, seconds: number?) -> number?,
	-- The subscription's price as Roblox gives it ("149"); nil until Roblox answers.
	subscriptionPrice: (subscription: Purchases.SubscriptionId) -> string?,
	-- The game sells this subscription and Roblox lets this player subscribe (reactive).
	sellsSubscription: (subscription: Purchases.SubscriptionId) -> boolean,
	-- The player has the subscription (reactive).
	isSubscribed: (subscription: Purchases.SubscriptionId) -> boolean,
	-- The game sells a week of the perk (decision 140).
	sellsWeek: (perk: Purchases.SubscriptionId) -> boolean,
	-- Roblox's price of a week of the perk (reactive); nil until Roblox answers.
	weekPrice: (perk: Purchases.SubscriptionId) -> number?,
	-- The server time the player's week of the perk runs until (reactive); 0: never bought.
	weekUntil: (perk: Purchases.SubscriptionId) -> number,
	-- The trainer's multiplier from the subscriptions (reactive).
	trainerMultiplier: () -> number,
	-- Shows Roblox's prompt for a product; `egg` is the egg an "Egg ready now" is for.
	promptProduct: (
		source: MonetizationConfig.ShopSource,
		kind: MonetizationConfig.ProductKind,
		tier: number?,
		seconds: number?,
		egg: number?
	) -> (),
	promptSubscription: (source: MonetizationConfig.ShopSource, subscription: Purchases.SubscriptionId) -> (),
	promptWeek: (source: MonetizationConfig.ShopSource, perk: Purchases.SubscriptionId) -> (),
	-- A purchase was granted.
	granted: Signal.Signal<Granted>,
	-- A subscription started (after the first reading: not for ones the player had on join).
	subscriptionStarted: Signal.Signal<Purchases.SubscriptionId>,
}

local PurchaseState = {}

-- A price as buttons show it: "25 R$", or "… R$" while it is not known.
function PurchaseState.priceText(locale: Text.Locale, price: number?): string
	return Text.get(locale, "store.robux.hint", { price = if price then tostring(price) else "…" })
end

function PurchaseState.new(): PurchaseState
	local catalog = MonetizationConfig.catalogFor(game.GameId)
	-- Roblox product ids -> price; subscription ids -> the price as Roblox gives it.
	local productPrices = Vide.source({} :: { [number]: number })
	local subscriptionPrices = Vide.source({} :: { [string]: string })
	local subscribed = Vide.source({} :: { [string]: boolean })
	local canSubscribe = Vide.source(false)
	local weeks = Vide.source({} :: { [string]: number })
	local multiplier = Vide.source(1)
	local granted = Signal.new() :: Signal.Signal<Granted>
	local subscriptionStarted = Signal.new() :: Signal.Signal<Purchases.SubscriptionId>

	local function productId(kind: MonetizationConfig.ProductKind, tier: number?, seconds: number?): number?
		return if catalog then MonetizationConfig.productIdOf(catalog, kind, tier, seconds) else nil
	end

	local function subscriptionId(subscription: Purchases.SubscriptionId): string?
		return if catalog then catalog.subscriptions[subscription] else nil
	end

	-- Roblox's price of a subscription: a Robux one comes as a number, others as display text.
	local function loadSubscriptionPrice(id: string)
		local ok, info = pcall(MarketplaceService.GetSubscriptionProductInfoAsync, MarketplaceService, id)
		local price = if ok and type(info) == "table" then info.PriceInRobux or info.DisplayPrice else nil
		if type(price) == "number" or type(price) == "string" then
			local copy = table.clone(subscriptionPrices())
			copy[id] = tostring(price)
			subscriptionPrices(copy)
		else
			warn(`[PurchaseState] No price from Roblox for subscription {id}: {if ok then "none given" else info}`)
		end
	end

	-- Asks Roblox for the price of each id; returns the ids it did not answer for.
	local function fetchPrices(
		ids: { number },
		infoType: Enum.InfoType,
		prices: Vide.Source<{ [number]: number }>
	): { number }
		local failed = {}
		for _, id in ids do
			local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, infoType)
			local price = if ok and type(info) == "table" then info.PriceInRobux else nil
			if type(price) == "number" then
				local copy = table.clone(prices())
				copy[id] = price
				prices(copy)
			else
				table.insert(failed, id)
			end
		end
		return failed
	end

	local function loadPrices(ids: { number }, infoType: Enum.InfoType, prices: Vide.Source<{ [number]: number }>)
		local failed = fetchPrices(ids, infoType, prices)
		if #failed > 0 then
			task.wait(PRICE_RETRY_SECONDS)
			failed = fetchPrices(failed, infoType, prices)
			if #failed > 0 then
				warn(`[PurchaseState] No price from Roblox for {table.concat(failed, ", ")}`)
			end
		end
	end

	-- Asks Roblox for every price again, at most once in PRICE_REFRESH_SECONDS. Roblox's price
	-- optimization changes prices while the game runs, so a price read on join may already be
	-- off when the player looks at it.
	local lastRefresh = -math.huge
	local function refreshPrices()
		if not catalog or os.clock() - lastRefresh < PRICE_REFRESH_SECONDS then
			return
		end
		lastRefresh = os.clock()
		local products = {}
		for id in catalog.products do
			table.insert(products, id)
		end
		task.spawn(loadPrices, products, Enum.InfoType.Product, productPrices)
		for _, id in catalog.subscriptions do
			task.spawn(loadSubscriptionPrice, id)
		end
	end

	local function readSubscriptions(player: Player, announce: boolean)
		local value = player:GetAttribute(MonetizationConfig.SUBSCRIPTIONS_ATTRIBUTE)
		local before = Vide.untrack(subscribed)
		local now: { [string]: boolean } = {}
		if type(value) == "string" then
			for _, subscription in string.split(value, ",") do
				if subscription ~= "" then
					now[subscription] = true
				end
			end
		end
		subscribed(now)
		if announce then
			for _, subscription in MonetizationConfig.SUBSCRIPTION_ORDER do
				if now[subscription] and not before[subscription] then
					subscriptionStarted.fire(subscription)
				end
			end
		end
	end

	local function readMultiplier(player: Player)
		local value = player:GetAttribute(MonetizationConfig.TRAINER_MULTIPLIER_ATTRIBUTE)
		multiplier(if type(value) == "number" and value > 0 then value else 1)
	end

	local function start()
		local player = Players.LocalPlayer
		-- The server publishes the subscriptions on the player once the profile is active: the
		-- first value is the ones the player had, later ones are what Roblox said since.
		local announce = player:GetAttribute(MonetizationConfig.SUBSCRIPTIONS_ATTRIBUTE) ~= nil
		player:GetAttributeChangedSignal(MonetizationConfig.SUBSCRIPTIONS_ATTRIBUTE):Connect(function()
			readSubscriptions(player, announce)
			announce = true
		end)
		readSubscriptions(player, false)
		local function readWeeks()
			local now: { [string]: number } = {}
			for _, perk in MonetizationConfig.SUBSCRIPTION_ORDER do
				local value = player:GetAttribute(MonetizationConfig.WEEK_ATTRIBUTE_PREFIX .. perk)
				now[perk] = if type(value) == "number" then value else 0
			end
			weeks(now)
		end
		for _, perk in MonetizationConfig.SUBSCRIPTION_ORDER do
			player:GetAttributeChangedSignal(MonetizationConfig.WEEK_ATTRIBUTE_PREFIX .. perk):Connect(readWeeks)
		end
		readWeeks()
		local function readCanSubscribe()
			canSubscribe(player:GetAttribute(MonetizationConfig.CAN_SUBSCRIBE_ATTRIBUTE) == true)
		end
		player:GetAttributeChangedSignal(MonetizationConfig.CAN_SUBSCRIBE_ATTRIBUTE):Connect(readCanSubscribe)
		readCanSubscribe()
		-- The server asks Roblox again once the prompt is gone (a purchase takes a moment to show).
		MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(function(user)
			if user == player then
				Remotes.SubscriptionPromptClosed.Fire()
			end
		end)
		player:GetAttributeChangedSignal(MonetizationConfig.TRAINER_MULTIPLIER_ATTRIBUTE):Connect(function()
			readMultiplier(player)
		end)
		readMultiplier(player)

		Remotes.Purchased.SetCallback(function(value)
			local coins = BigNum.fromSaved(value.coins)
			local speed = BigNum.fromSaved(value.speed)
			if coins and speed then
				granted.fire({
					kind = value.kind,
					perk = value.perk,
					compensated = value.compensated,
					hatched = value.hatched,
					coins = coins,
					speed = speed,
				})
			end
		end)

		refreshPrices()
	end

	return {
		name = "PurchaseState",
		start = start,
		available = catalog ~= nil,
		refreshPrices = refreshPrices,
		sells = function(kind, tier, seconds)
			return productId(kind, tier, seconds) ~= nil
		end,
		productPrice = function(kind, tier, seconds)
			local id = productId(kind, tier, seconds)
			return if id then productPrices()[id] else nil
		end,
		subscriptionPrice = function(subscription)
			local id = subscriptionId(subscription)
			return if id then subscriptionPrices()[id] else nil
		end,
		sellsSubscription = function(subscription)
			return subscriptionId(subscription) ~= nil and canSubscribe()
		end,
		isSubscribed = function(subscription)
			return subscribed()[subscription] == true
		end,
		sellsWeek = function(perk)
			return catalog ~= nil and MonetizationConfig.weekProductOf(catalog, perk) ~= nil
		end,
		weekPrice = function(perk)
			local id = if catalog then MonetizationConfig.weekProductOf(catalog, perk) else nil
			return if id then productPrices()[id] else nil
		end,
		weekUntil = function(perk)
			return weeks()[perk] or 0
		end,
		trainerMultiplier = function()
			return multiplier()
		end,
		promptProduct = function(source, kind, tier, seconds, egg)
			local id = productId(kind, tier, seconds)
			if not id then
				warn(`[PurchaseState] This game does not sell {kind} {tier or seconds or ""}`)
				return
			end
			Remotes.PurchasePrompted.Fire({ item = kind, source = source, egg = egg })
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
		end,
		promptSubscription = function(source, subscription)
			local id = subscriptionId(subscription)
			if not id or subscribed()[subscription] or not canSubscribe() then
				return
			end
			Remotes.PurchasePrompted.Fire({ item = subscription, source = source })
			MarketplaceService:PromptSubscriptionPurchase(Players.LocalPlayer, id)
		end,
		promptWeek = function(source, perk)
			local id = if catalog then MonetizationConfig.weekProductOf(catalog, perk) else nil
			if not id then
				warn(`[PurchaseState] This game does not sell a week of {perk}`)
				return
			end
			Remotes.PurchasePrompted.Fire({ item = "Week", source = source })
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
		end,
		granted = granted,
		subscriptionStarted = subscriptionStarted,
	}
end

return table.freeze(PurchaseState)
