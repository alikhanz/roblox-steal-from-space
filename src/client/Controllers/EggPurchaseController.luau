--!strict
-- "Egg ready now" at the egg itself (decision 063): the prompt on a warming egg in the player's
-- own bay (BayService) says "Hatch for 6 R$" with the price of this egg's tier, and pressing it
-- asks Roblox for that purchase, for this egg. What the purchase does comes from the server, by
-- its receipt (PurchaseService): the egg hatches at once.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local PurchaseState = require(script.Parent.Parent.State.PurchaseState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Dependencies = {
	purchases: PurchaseState.PurchaseState,
}

export type EggPurchaseController = {
	name: string,
	start: () -> (),
}

local EggPurchaseController = {}

function EggPurchaseController.new(dependencies: Dependencies): EggPurchaseController
	local purchases = dependencies.purchases
	local locale: Text.Locale = "en"
	-- The prompts on screen now, each with the scope that keeps its price up to date.
	local shown: { [ProximityPrompt]: () -> () } = {}

	-- The price tier of a "hatch now" prompt in the player's own bay; nil for any other prompt.
	local function tierOf(prompt: ProximityPrompt): number?
		local tier = prompt:GetAttribute(BayConfig.READY_NOW_TIER_ATTRIBUTE)
		local owner = prompt:GetAttribute(BayConfig.PROMPT_OWNER_ATTRIBUTE)
		return if type(tier) == "number" and owner == Players.LocalPlayer.UserId then tier else nil
	end

	local function eggOf(prompt: ProximityPrompt): number?
		local part = prompt.Parent
		local uid = if part then part:GetAttribute(BayConfig.EGG_UID_ATTRIBUTE) else nil
		return if type(uid) == "number" then uid else nil
	end

	local function hide(prompt: ProximityPrompt)
		local destroy = shown[prompt]
		if destroy then
			shown[prompt] = nil
			destroy()
		end
	end

	local function show(prompt: ProximityPrompt)
		local tier = tierOf(prompt)
		if not tier or shown[prompt] then
			return
		end
		-- Roblox may have changed the price since it was read: the words follow the new one.
		purchases.refreshPrices()
		shown[prompt] = Vide.root(function()
			Vide.effect(function()
				local price = PurchaseState.priceText(locale, purchases.productPrice("ReadyNow", tier))
				prompt.ActionText = Text.get(locale, "egg.hatchNow.button", { price = price })
			end)
		end)
		prompt.Destroying:Once(function()
			hide(prompt)
		end)
	end

	local function start()
		if not purchases.available then
			return
		end
		locale = Text.localeOf(Players.LocalPlayer)
		ProximityPromptService.PromptShown:Connect(show)
		ProximityPromptService.PromptHidden:Connect(hide)
		ProximityPromptService.PromptTriggered:Connect(function(prompt)
			local tier = tierOf(prompt)
			local egg = eggOf(prompt)
			if tier and egg then
				purchases.promptProduct("Egg", "ReadyNow", tier, nil, egg)
			end
		end)
	end

	return {
		name = "EggPurchaseController",
		start = start,
	}
end

return table.freeze(EggPurchaseController)
