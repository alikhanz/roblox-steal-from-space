--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The jetpack shop on the client (docs/design/screens/jetpack-shop.md): the sign and prompt
-- texts on the kiosk, and the shop window that the prompt opens. The window's data comes from
-- the profile copy (level, coins) and the speed stat; buying is a request to the server, which
-- answers with UpgradesChanged or a notice (toasted by the bay window controller). The window
-- closes when the player walks away from the kiosk.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ShopWindow = require(script.Parent.Parent.UI.ShopWindow)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
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
-- The window closes this far past the prompt's reach, so a step back does not close it.
local CLOSE_DISTANCE_SLACK = 4
-- Multipliers below this are written out in full.
local FULL_MULTIPLIER_BELOW = 10000

export type Dependencies = {
	profile: ProfileState.ProfileState,
	windows: WindowState.WindowState,
	toasts: ToastState.ToastState,
	-- The player's speed stat.
	speed: () -> BigNum.BigNum,
}

export type ShopController = {
	name: string,
	start: () -> (),
}

local ShopController = {}

function ShopController.new(dependencies: Dependencies): ShopController
	local profile = dependencies.profile
	local speed = dependencies.speed
	local isOpen = dependencies.windows.slot("Shop")
	local locale: Text.Locale = "en"
	-- The counter whose prompt opened the window: walking away from it closes the window.
	local openedAt: BasePart? = nil
	-- A buy was asked for: the next level-up gets a toast (not the first snapshot on joining).
	local buyAsked = false

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local tuning = UpgradeConfig.TUNING
	local top = Upgrades.jetpackMaxLevel(tuning)

	local function owned(): number
		return profile.upgrades().jetpackLevel
	end

	local function atTop(): boolean
		return owned() >= top
	end

	-- The next level's price; nil at the top, where there is nothing to buy.
	local function nextPrice(): BigNum.BigNum?
		local level = owned()
		return if level < top then Upgrades.jetpackPrice(level, tuning) else nil
	end

	local function canBuy(): boolean
		local price = nextPrice()
		return price ~= nil and not BigNum.lessThan(profile.coins(), price)
	end

	-- A multiplier in full while it has four digits ("×2048" reads better than "×2.04K").
	local function multiplier(level: number): string
		local value = Upgrades.jetpackMultiplier(level, tuning)
		local plain = BigNum.toNumber(value)
		return if plain < FULL_MULTIPLIER_BELOW then string.format("%.4g", plain) else BigNum.format(value)
	end

	-- The next jetpack, or the owned one at the top.
	local function card(): ShopWindow.Card
		local level = owned()
		local shown = math.min(level + 1, top)
		local looks = JetpackLooks.forLevel(shown)
		local stat = speed()
		return {
			name = Names.jetpack(locale, shown),
			flameStart = looks.flameStart,
			flameEnd = looks.flameEnd,
			upgrade = if level >= top
				then text("shop.multiplier.hint", { factor = multiplier(level) })
				else text("shop.upgrade.hint", { from = multiplier(level), to = multiplier(shown) }),
			gain = if level >= top
				then ""
				else text("shop.gain.hint", {
					from = BigNum.format(stat),
					to = BigNum.format(Upgrades.speedWithJetpack(stat, level, shown, tuning)),
				}),
		}
	end

	-- Every level, the starting one to the top.
	local function rows(): { ShopWindow.Row }
		local level = owned()
		local price = nextPrice()
		local list = {}
		for each = 0, top do
			local state: "Past" | "Owned" | "Next" | "Locked" = if each < level
				then "Past"
				elseif each == level then "Owned"
				elseif each == level + 1 then "Next"
				else "Locked"
			local looks = JetpackLooks.forLevel(each)
			table.insert(list, {
				level = each,
				name = Names.jetpack(locale, each),
				multiplier = text("shop.multiplier.hint", { factor = multiplier(each) }),
				flameStart = looks.flameStart,
				flameEnd = looks.flameEnd,
				state = state,
				price = if state == "Next" and price then BigNum.format(price) else "",
			})
		end
		return list
	end

	local function saving(): string
		local price = nextPrice()
		if not price or canBuy() then
			return ""
		end
		return text("shop.saving.hint", { coins = BigNum.format(profile.coins()), price = BigNum.format(price) })
	end

	local function savingShare(): number
		local price = nextPrice()
		if not price or BigNum.isZero(price) then
			return 1
		end
		return BigNum.toNumber(BigNum.div(profile.coins(), price))
	end

	local function close()
		isOpen(false)
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			-- A level-up after a buy: a toast with the new jetpack's name.
			local lastLevel = owned()
			Vide.effect(function()
				local level = owned()
				if level > lastLevel and buyAsked then
					buyAsked = false
					dependencies.toasts.push(
						text("shop.bought.toast", { name = Names.jetpack(locale, level) }),
						Theme.TOAST_GOOD
					)
				end
				lastLevel = level
			end)

			return create("ScreenGui")({
				Name = "ShopUi",
				ResetOnSpawn = false,
				DisplayOrder = 11,
				ShopWindow({
					visible = function()
						return isOpen()
					end,
					coins = function()
						return BigNum.format(profile.coins())
					end,
					texts = {
						title = text("shop.window.title"),
						hint = text("shop.window.hint"),
						nextTitle = text("shop.next.title"),
						topTitle = text("shop.ownedTop.title"),
						topHint = text("shop.top.hint"),
						ladderTitle = text("shop.ladder.title"),
						owned = text("shop.owned.hint"),
					},
					card = card,
					atTop = atTop,
					buyText = function()
						local price = nextPrice()
						return if price then text("shop.buy.button", { price = BigNum.format(price) }) else ""
					end,
					canBuy = canBuy,
					saving = saving,
					savingShare = savingShare,
					rows = rows,
					count = function()
						return text("shop.ladderCount.hint", { owned = owned() + 1, total = top + 1 })
					end,
					ownedIndex = function()
						return owned() + 1
					end,
					onBuy = function()
						buyAsked = true
						Remotes.UpgradeJetpack.Fire()
					end,
					onClose = close,
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

	-- Closes the window once the player is out of the opening prompt's reach.
	local function closeWhenAway()
		local counter = openedAt
		if not counter or not isOpen() then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not root or not root:IsA("BasePart") or not counter:IsDescendantOf(workspace) then
			return
		end
		if (root.Position - counter.Position).Magnitude > ShopConfig.PROMPT_DISTANCE + CLOSE_DISTANCE_SLACK then
			close()
		end
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
				local parent = prompt.Parent
				openedAt = if parent and parent:IsA("BasePart") then parent else nil
				isOpen(true)
			end
		end)
		RunService.Heartbeat:Connect(closeWhenAway)
	end

	return {
		name = "ShopController",
		start = start,
	}
end

return table.freeze(ShopController)
