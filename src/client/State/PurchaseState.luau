--!strict
-- Robux purchases on the client (decision 061): this game's catalog, the prices Roblox shows for
-- it, the passes the player owns and the purchase prompts. A prompt only asks Roblox; what a
-- purchase gives comes from the server, by its receipt (PurchaseService), and arrives here as
-- `granted`.

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

-- What a granted purchase gave (speed as the stat shows it).
export type Granted = {
	kind: MonetizationConfig.ProductKind,
	compensated: boolean,
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
	-- Roblox's price, in Robux (reactive); nil until Roblox answers, or when it does not.
	productPrice: (kind: MonetizationConfig.ProductKind, tier: number?, seconds: number?) -> number?,
	passPrice: (pass: Purchases.PassId) -> number?,
	-- The game sells this pass.
	sellsPass: (pass: Purchases.PassId) -> boolean,
	-- The player owns the pass (reactive).
	owns: (pass: Purchases.PassId) -> boolean,
	-- The trainer's multiplier from the passes (reactive).
	trainerMultiplier: () -> number,
	-- Shows Roblox's prompt for a product; `egg` is the egg an "Egg ready now" is for.
	promptProduct: (
		source: MonetizationConfig.ShopSource,
		kind: MonetizationConfig.ProductKind,
		tier: number?,
		seconds: number?,
		egg: number?
	) -> (),
	promptPass: (source: MonetizationConfig.ShopSource, pass: Purchases.PassId) -> (),
	-- A purchase was granted.
	granted: Signal.Signal<Granted>,
	-- A pass became the player's (after the first reading: not for passes owned on join).
	passUnlocked: Signal.Signal<Purchases.PassId>,
}

local PurchaseState = {}

-- A price as buttons show it: "25 R$", or "… R$" while it is not known.
function PurchaseState.priceText(locale: Text.Locale, price: number?): string
	return Text.get(locale, "store.robux.hint", { price = if price then tostring(price) else "…" })
end

function PurchaseState.new(): PurchaseState
	local catalog = MonetizationConfig.catalogFor(game.GameId)
	-- Roblox ids -> price; products and passes apart (their ids are separate ranges).
	local productPrices = Vide.source({} :: { [number]: number })
	local passPrices = Vide.source({} :: { [number]: number })
	local ownedPasses = Vide.source({} :: { [string]: boolean })
	local multiplier = Vide.source(1)
	local granted = Signal.new() :: Signal.Signal<Granted>
	local passUnlocked = Signal.new() :: Signal.Signal<Purchases.PassId>

	local function productId(kind: MonetizationConfig.ProductKind, tier: number?, seconds: number?): number?
		return if catalog then MonetizationConfig.productIdOf(catalog, kind, tier, seconds) else nil
	end

	local function passId(pass: Purchases.PassId): number?
		return if catalog then catalog.passes[pass] else nil
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

	local function readPasses(player: Player, announce: boolean)
		local value = player:GetAttribute(MonetizationConfig.PASSES_ATTRIBUTE)
		local before = Vide.untrack(ownedPasses)
		local now: { [string]: boolean } = {}
		if type(value) == "string" then
			for _, pass in string.split(value, ",") do
				if pass ~= "" then
					now[pass] = true
				end
			end
		end
		ownedPasses(now)
		if announce then
			for _, pass in MonetizationConfig.PASS_ORDER do
				if now[pass] and not before[pass] then
					passUnlocked.fire(pass)
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
		-- The server publishes the passes on the player once the profile is active: the first
		-- value is the passes owned on join, later ones are purchases.
		local announcePasses = player:GetAttribute(MonetizationConfig.PASSES_ATTRIBUTE) ~= nil
		player:GetAttributeChangedSignal(MonetizationConfig.PASSES_ATTRIBUTE):Connect(function()
			readPasses(player, announcePasses)
			announcePasses = true
		end)
		readPasses(player, false)
		player:GetAttributeChangedSignal(MonetizationConfig.TRAINER_MULTIPLIER_ATTRIBUTE):Connect(function()
			readMultiplier(player)
		end)
		readMultiplier(player)

		Remotes.Purchased.SetCallback(function(value)
			local coins = BigNum.fromSaved(value.coins)
			local speed = BigNum.fromSaved(value.speed)
			if coins and speed then
				granted.fire({ kind = value.kind, compensated = value.compensated, coins = coins, speed = speed })
			end
		end)

		if catalog then
			local products = {}
			for id in catalog.products do
				table.insert(products, id)
			end
			local passes = {}
			for _, id in catalog.passes do
				table.insert(passes, id)
			end
			task.spawn(loadPrices, products, Enum.InfoType.Product, productPrices)
			task.spawn(loadPrices, passes, Enum.InfoType.GamePass, passPrices)
		end
	end

	return {
		name = "PurchaseState",
		start = start,
		available = catalog ~= nil,
		sells = function(kind, tier, seconds)
			return productId(kind, tier, seconds) ~= nil
		end,
		productPrice = function(kind, tier, seconds)
			local id = productId(kind, tier, seconds)
			return if id then productPrices()[id] else nil
		end,
		passPrice = function(pass)
			local id = passId(pass)
			return if id then passPrices()[id] else nil
		end,
		sellsPass = function(pass)
			return passId(pass) ~= nil
		end,
		owns = function(pass)
			return ownedPasses()[pass] == true
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
		promptPass = function(source, pass)
			local id = passId(pass)
			if not id or ownedPasses()[pass] then
				return
			end
			Remotes.PurchasePrompted.Fire({ item = pass, source = source })
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
		end,
		granted = granted,
		passUnlocked = passUnlocked,
	}
end

return table.freeze(PurchaseState)
