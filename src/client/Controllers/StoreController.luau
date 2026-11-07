--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The shop (decision 061): the HUD menu tile, the window with everything sold for Robux, and the
-- toasts for what a purchase gave. Prices and passes come from PurchaseState, the numbers a
-- purchase would give from the profile copy and the same formulas the server uses.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Icons = require(script.Parent.Parent.UI.Icons)
local Marks = require(ReplicatedStorage.Shared.Locale.Marks)
local MenuState = require(script.Parent.Parent.State.MenuState)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local PurchaseState = require(script.Parent.Parent.State.PurchaseState)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local StoreWindow = require(script.Parent.Parent.UI.StoreWindow)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)

local create = Vide.create

local PLAYER_GUI_WAIT_TIMEOUT = 30
local HOUR = 60 * 60

local PASS_TEXTS: { [Purchases.PassId]: { title: Text.Key, hint: Text.Key } } = {
	DoubleTraining = { title = "store.doubleTraining.title", hint = "store.doubleTraining.hint" },
	NightShift = { title = "store.nightShift.title", hint = "store.nightShift.hint" },
}
-- Each pass's icon and colour on its card.
local PASS_LOOKS: { [Purchases.PassId]: { icon: Icons.Name, color: Color3 } } = {
	DoubleTraining = { icon = "Bolt", color = Theme.NEON.SPEED },
	NightShift = { icon = "Moon", color = Color3.fromHex("#8E8CFF") },
}
-- The training packs' titles, in MonetizationConfig.TRAINING_PACK_SECONDS order.
local TRAINING_TITLES: { Text.Key } = {
	"store.trainingHour.title",
	"store.trainingEight.title",
	"store.trainingDay.title",
}

export type Dependencies = {
	profile: ProfileState.ProfileState,
	purchases: PurchaseState.PurchaseState,
	toasts: ToastState.ToastState,
	windows: WindowState.WindowState,
	menu: MenuState.MenuState,
}

export type StoreController = {
	name: string,
	start: () -> (),
	-- Opens the shop; `source` says where from (the analytics of the purchases made in it).
	open: (source: MonetizationConfig.ShopSource) -> (),
}

local StoreController = {}

function StoreController.new(dependencies: Dependencies): StoreController
	local profile = dependencies.profile
	local purchases = dependencies.purchases
	local isOpen = dependencies.windows.slot("Store")
	local openedFrom: MonetizationConfig.ShopSource = "Store"
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local function price(value: number?): string
		return PurchaseState.priceText(locale, value)
	end

	local function open(from: MonetizationConfig.ShopSource)
		openedFrom = from
		purchases.refreshPrices()
		isOpen(true)
	end

	-- The speed stat a training pack of `seconds` adds now (Purchases.trainingPack, as the server).
	local function packSpeed(seconds: number): BigNum.BigNum
		local upgrades = profile.upgrades()
		local rate = Purchases.trainerRate(upgrades.trainerLevel, purchases.trainerMultiplier(), UpgradeConfig.TUNING)
		local jetpack = Upgrades.jetpackMultiplier(upgrades.jetpackLevel, UpgradeConfig.TUNING)
		return Purchases.trainingPack(rate, seconds, jetpack).speed
	end

	local function slotTier(): number
		return Purchases.slotTier(profile.bay().incubatorSlots, MonetizationConfig.SLOT_TIER_LAST)
	end

	local function passCards(): { StoreWindow.Pass }
		local tuning = MonetizationConfig.PASS_TUNING
		local hintArgs: { [Purchases.PassId]: Text.Args } = {
			DoubleTraining = { factor = tuning.doubleTrainingMultiplier },
			NightShift = {
				income = tuning.nightShiftIncomeCapSeconds // HOUR,
				incomeBase = tuning.incomeCapSeconds // HOUR,
				training = tuning.nightShiftTrainingCapSeconds // HOUR,
				trainingBase = tuning.trainingCapSeconds // HOUR,
			},
		}
		local cards: { StoreWindow.Pass } = {}
		for _, pass in MonetizationConfig.PASS_ORDER do
			if not purchases.sellsPass(pass) then
				continue
			end
			local texts = PASS_TEXTS[pass]
			local looks = PASS_LOOKS[pass]
			table.insert(cards, {
				title = text(texts.title),
				hint = function()
					return text(texts.hint, hintArgs[pass])
				end,
				icon = looks.icon,
				color = looks.color,
				price = function()
					return price(purchases.passPrice(pass))
				end,
				priceReady = function()
					return purchases.passPrice(pass) ~= nil
				end,
				owned = function()
					return purchases.owns(pass)
				end,
				onBuy = function()
					purchases.promptPass(openedFrom, pass)
				end,
			})
		end
		return cards
	end

	local function productCards(): { StoreWindow.Product }
		local cards: { StoreWindow.Product } = {}
		for index, seconds in MonetizationConfig.TRAINING_PACK_SECONDS do
			if not purchases.sells("Training", nil, seconds) then
				continue
			end
			table.insert(cards, {
				title = text(TRAINING_TITLES[index]),
				-- Exactly what the pack gives now, from the player's trainer (decision 024).
				value = function()
					return `{Marks.SPEED}+{BigNum.format(packSpeed(seconds))}`
				end,
				color = Theme.NEON.SPEED,
				price = function()
					return price(purchases.productPrice("Training", nil, seconds))
				end,
				priceReady = function()
					return purchases.productPrice("Training", nil, seconds) ~= nil
				end,
				offered = function()
					return true
				end,
				status = function()
					return ""
				end,
				onBuy = function()
					purchases.promptProduct(openedFrom, "Training", nil, seconds)
				end,
			})
		end
		-- "Egg ready now" is not here: it is sold on the egg itself (decision 063).
		local function hasRoom(): boolean
			return profile.bay().incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
		end
		table.insert(cards, {
			title = text("store.slot.title"),
			-- Slots now and after the purchase.
			value = function()
				local slots = profile.bay().incubatorSlots
				return if hasRoom()
					then text("store.slotGrow.hint", { from = slots, to = slots + 1 })
					else tostring(slots)
			end,
			valueIcon = "Egg" :: Icons.Name,
			color = Theme.NEON.EGG,
			price = function()
				return price(purchases.productPrice("IncubatorSlot", slotTier()))
			end,
			priceReady = function()
				return purchases.productPrice("IncubatorSlot", slotTier()) ~= nil
			end,
			offered = function()
				return hasRoom() and purchases.sells("IncubatorSlot", slotTier())
			end,
			status = function()
				return if hasRoom() then "" else text("store.slotMax.hint")
			end,
			onBuy = function()
				purchases.promptProduct(openedFrom, "IncubatorSlot", slotTier())
			end,
		})
		return cards
	end

	-- What a granted purchase gave, as a toast.
	local function announce(granted: PurchaseState.Granted)
		if granted.hatched then
			-- The egg hatched at once: the hatch has its own announcement.
			return
		end
		local coins = BigNum.format(granted.coins)
		local speed = BigNum.format(granted.speed)
		-- Not if-expressions: each branch gives the message and its kind together.
		local message: string
		local kind: Toasts.Kind
		if granted.compensated then
			message, kind = text("store.compensated.toast", { coins = coins }), "Coins"
		elseif granted.kind == "Training" then
			message, kind = text("store.training.toast", { speed = speed }), "Speed"
		elseif granted.kind == "ReadyNow" then
			message, kind = text("store.readyNow.toast"), "Egg"
		elseif granted.kind == "IncubatorSlot" then
			message, kind = text("store.slot.toast"), "Egg"
		else
			message, kind = text("store.double.toast", { coins = coins, speed = speed }), "Good"
		end
		dependencies.toasts.push(message, kind)
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			return create("ScreenGui")({
				Name = "StoreUi",
				ResetOnSpawn = false,
				DisplayOrder = 11,
				StoreWindow({
					visible = function()
						return isOpen()
					end,
					coins = function()
						return BigNum.format(profile.coins())
					end,
					texts = {
						title = text("store.window.title"),
						hint = text("store.window.hint"),
						forever = text("store.forever.title"),
						now = text("store.now.title"),
						owned = text("store.owned.hint"),
					},
					passes = passCards(),
					products = productCards(),
					onClose = function()
						isOpen(false)
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		if not purchases.available then
			-- An unpublished place sells nothing: no button, no window.
			return
		end
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[StoreController] PlayerGui did not appear")
		mountUi(playerGui)
		-- The tile in the HUD menu row; its key is answered by MenuState.
		dependencies.menu.add({
			slot = "Store",
			onPress = function()
				if isOpen() then
					isOpen(false)
				else
					open("Store")
				end
			end,
		})

		purchases.granted.connect(announce)
		purchases.passUnlocked.connect(function(pass)
			local name = text(PASS_TEXTS[pass].title)
			dependencies.toasts.push(text("store.unlocked.toast", { name = name }), "Good")
		end)
	end

	return {
		name = "StoreController",
		start = start,
		open = open,
	}
end

return table.freeze(StoreController)
