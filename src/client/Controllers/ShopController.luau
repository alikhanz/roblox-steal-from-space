--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The jetpack shop on the client: the sign and prompt texts on the kiosk, and the shop window
-- that the prompt opens. Rows come from the profile copy (level, coins); buying is a request
-- to the server, which answers with UpgradesChanged or a notice.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ShopWindow = require(script.Parent.Parent.UI.ShopWindow)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local create = Vide.create

local PLAYER_GUI_WAIT_TIMEOUT = 30
local PART_WAIT_TIMEOUT = 10
-- From the panel's center to just over its top edge.
local SIGN_STUDS_ABOVE = 4.5
local SIGN_MAX_DISTANCE = 120
-- Rows shown past the owned one, so the next few goals are always on the list.
local ROWS_AHEAD = 2

export type Dependencies = {
	profile: ProfileState.ProfileState,
	windows: WindowState.WindowState,
}

export type ShopController = {
	name: string,
	start: () -> (),
}

local ShopController = {}

function ShopController.new(dependencies: Dependencies): ShopController
	local profile = dependencies.profile
	local isOpen = dependencies.windows.slot("Shop")
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local function nextPrice(): BigNum.BigNum
		return Upgrades.jetpackPrice(profile.upgrades().jetpackLevel, UpgradeConfig.TUNING)
	end

	local function rows(): { ShopWindow.Row }
		local owned = profile.upgrades().jetpackLevel
		local count = math.max(#JetpackLooks.LEVELS, owned + 1 + ROWS_AHEAD)
		local list = {}
		for level = 0, count - 1 do
			local state: "Past" | "Owned" | "Next" | "Locked" = if level < owned
				then "Past"
				elseif level == owned then "Owned"
				elseif level == owned + 1 then "Next"
				else "Locked"
			table.insert(list, {
				level = level,
				name = Names.jetpack(locale, level),
				multiplier = text("shop.multiplier.hint", {
					factor = BigNum.format(Upgrades.jetpackMultiplier(level, UpgradeConfig.TUNING)),
				}),
				color = JetpackLooks.forLevel(level).flameEnd,
				state = state,
				price = text("shop.buy.button", { price = BigNum.format(nextPrice()) }),
			})
		end
		return list
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			return create("ScreenGui")({
				Name = "ShopUi",
				ResetOnSpawn = false,
				DisplayOrder = 11,
				ShopWindow({
					visible = function()
						return isOpen()
					end,
					rows = rows,
					texts = {
						title = text("shop.window.title"),
						hint = text("shop.window.hint"),
						past = text("shop.past.hint"),
						owned = text("shop.owned.hint"),
						locked = text("shop.locked.hint"),
					},
					canBuy = function()
						return not BigNum.lessThan(profile.coins(), nextPrice())
					end,
					onBuy = function()
						Remotes.UpgradeJetpack.Fire()
					end,
					onClose = function()
						isOpen(false)
					end,
				}),
			})
		end, playerGui)
	end

	-- The kiosk's sign and the prompt's texts, in this client's language.
	local function watchShop(instance: Instance)
		task.spawn(function()
			local panel = instance:WaitForChild(ShopConfig.SIGN_NAME, PART_WAIT_TIMEOUT)
			local counter = instance:WaitForChild(ShopConfig.COUNTER_NAME, PART_WAIT_TIMEOUT)
			if not panel or not panel:IsA("BasePart") or not counter or not instance:IsDescendantOf(workspace) then
				warn(`[ShopController] {instance:GetFullName()} is not a complete shop; no sign`)
				return
			end
			local prompt = counter:WaitForChild("ProximityPrompt", PART_WAIT_TIMEOUT)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.ObjectText = text("shop.sign.title")
				prompt.ActionText = text("shop.open.button")
			end
			Vide.mount(function()
				return WorldLabel({
					adornee = panel,
					title = text("shop.sign.title"),
					value = text("shop.window.hint"),
					studsAbove = SIGN_STUDS_ABOVE,
					maxDistance = SIGN_MAX_DISTANCE,
				})
			end, instance)
		end)
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[ShopController] PlayerGui did not appear")
		mountUi(playerGui)

		for _, instance in CollectionService:GetTagged(ShopConfig.TAG) do
			watchShop(instance)
		end
		CollectionService:GetInstanceAddedSignal(ShopConfig.TAG):Connect(watchShop)

		ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
			local model = prompt:FindFirstAncestorOfClass("Model")
			if player == Players.LocalPlayer and model and CollectionService:HasTag(model, ShopConfig.TAG) then
				isOpen(true)
			end
		end)
	end

	return {
		name = "ShopController",
		start = start,
	}
end

return table.freeze(ShopController)
