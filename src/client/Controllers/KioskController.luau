--!strict
-- The station's kiosks on the client (decision 087): each one's name on its plate and its icon
-- on its badge and in its hologram, in this client's language, and all their names running along
-- the ring's screens (UI/RingBanner); and for the kiosks of the HUD
-- menu's windows (shop, quests, daily gift) the prompt at the counter, which opens the same
-- window as the menu tile and is hidden while that tile is (no shop in this game, no gift
-- today). The jetpacks' kiosk is the jetpack shop: its prompt is ShopController's.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Parent.UI.Icons)
local KioskPrompt = require(ReplicatedStorage.Shared.World.KioskPrompt)
local KioskSign = require(script.Parent.Parent.UI.KioskSign)
local MenuState = require(script.Parent.Parent.State.MenuState)
local RingBanner = require(script.Parent.Parent.UI.RingBanner)
local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)

local PART_WAIT_TIMEOUT = 10

export type Dependencies = {
	menu: MenuState.MenuState,
	windows: WindowState.WindowState,
}

export type KioskController = {
	name: string,
	start: () -> (),
}

type KioskUi = {
	label: Text.Key,
	icon: Icons.Name,
	-- The HUD menu's tile and the window it opens; nil for the jetpack shop.
	menu: MenuState.Slot?,
	window: string?,
}

local KIOSK_UI: { [StationLooks.KioskId]: KioskUi } = {
	Jetpacks = { label = "kiosk.jetpacks.title", icon = "Jetpack" },
	Store = { label = "kiosk.store.title", icon = "Store", menu = "Store", window = "Store" },
	Quests = { label = "kiosk.quests.title", icon = "Quests", menu = "Quests", window = "Quests" },
	Gift = { label = "kiosk.gift.title", icon = "Gift", menu = "Gift", window = "LoginGift" },
}

local COLORS: { [StationLooks.KioskId]: Color3 } = {}
for _, kiosk in StationLooks.KIOSKS do
	COLORS[kiosk.id] = kiosk.color
end

local KioskController = {}

-- The kiosk's id on `model`, or nil (with a warning) for a model without a known one.
local function kioskOf(model: Instance): StationLooks.KioskId?
	local id = model:GetAttribute(StationLooks.KIOSK_ATTRIBUTE)
	if type(id) == "string" and KIOSK_UI[id :: StationLooks.KioskId] then
		return id :: StationLooks.KioskId
	end
	warn(`[KioskController] {model:GetFullName()} has no known kiosk id ({tostring(id)})`)
	return nil
end

local function waitForPart(model: Instance, name: string): BasePart?
	local found = model:WaitForChild(name, PART_WAIT_TIMEOUT)
	if found and found:IsA("BasePart") then
		return found
	end
	warn(`[KioskController] {model:GetFullName()} has no {name}`)
	return nil
end

function KioskController.new(dependencies: Dependencies): KioskController
	local menu = dependencies.menu
	local locale: Text.Locale = "en"

	local function watch(model: Instance)
		local id = kioskOf(model)
		if not id then
			return
		end
		local ui = KIOSK_UI[id]
		local color = COLORS[id]
		local image = Icons.ICONS[ui.icon]
		task.spawn(function()
			local plate = waitForPart(model, StationLooks.KIOSK_PLATE_NAME)
			local badge = waitForPart(model, StationLooks.KIOSK_BADGE_NAME)
			local holo = waitForPart(model, StationLooks.KIOSK_HOLO_NAME)
			if plate then
				KioskSign.plate(plate, Text.get(locale, ui.label)).Parent = plate
			end
			if badge then
				KioskSign.badge(badge, image, color).Parent = badge
			end
			if holo then
				KioskSign.hologram(holo, image, color).Parent = holo
			end

			local slot = ui.menu
			if not slot then
				return
			end
			local prompt = KioskPrompt.find(model)
			if not prompt then
				warn(`[KioskController] {model:GetFullName()} has no prompt on its counter`)
				return
			end
			prompt.ObjectText = Text.get(locale, ui.label)
			prompt.ActionText = Text.get(locale, "kiosk.open.button")
			-- Shown while the menu shows the window's tile.
			Vide.root(function(destroy)
				Vide.effect(function()
					prompt.Enabled = MenuState.isShown(menu.tile(slot))
				end)
				model.Destroying:Once(destroy)
			end)
		end)
	end

	-- A kiosk's prompt opens its window; an open one stays open.
	local function onPrompt(prompt: ProximityPrompt, player: Player)
		local model = prompt:FindFirstAncestorOfClass("Model")
		if
			player ~= Players.LocalPlayer
			or not model
			or not CollectionService:HasTag(model, StationLooks.KIOSK_TAG)
		then
			return
		end
		local id = kioskOf(model)
		local ui = id and KIOSK_UI[id]
		local slot = ui and ui.menu
		local tile = slot and menu.tile(slot)
		if not ui or not tile or not MenuState.isShown(tile) then
			return
		end
		if ui.window and dependencies.windows.slot(ui.window)() then
			return
		end
		tile.onPress()
	end

	-- A ring screen: the kiosks' names running along it, in the circle's order.
	local function watchBanner(screen: Instance)
		if not screen:IsA("BasePart") then
			warn(`[KioskController] {screen:GetFullName()} is not a part; no banner`)
			return
		end
		local items: { RingBanner.Item } = {}
		for _, kiosk in StationLooks.KIOSKS do
			local ui = KIOSK_UI[kiosk.id]
			table.insert(items, { name = Text.get(locale, ui.label), icon = Icons.ICONS[ui.icon], color = kiosk.color })
		end
		RingBanner.create(screen, items).Parent = screen
	end

	local function start()
		locale = Text.localeOf(Players.LocalPlayer)
		for _, model in CollectionService:GetTagged(StationLooks.KIOSK_TAG) do
			watch(model)
		end
		CollectionService:GetInstanceAddedSignal(StationLooks.KIOSK_TAG):Connect(watch)
		for _, screen in CollectionService:GetTagged(StationLooks.BANNER_TAG) do
			watchBanner(screen)
		end
		CollectionService:GetInstanceAddedSignal(StationLooks.BANNER_TAG):Connect(watchBanner)
		ProximityPromptService.PromptTriggered:Connect(onPrompt)
	end

	return {
		name = "KioskController",
		start = start,
	}
end

return table.freeze(KioskController)
