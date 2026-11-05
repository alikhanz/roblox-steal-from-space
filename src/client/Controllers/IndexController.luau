--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The alien index on the client: the HUD button with how many rewards wait, the index window
-- and the toasts for a new find and a taken reward. Rows are built from the one alien registry
-- (AlienConfig through IndexConfig.SETS) and the profile copy; rewards shown use the formula the
-- server pays with (Pace).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienIndex = require(ReplicatedStorage.Shared.Domain.AlienIndex)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Button = require(script.Parent.Parent.UI.Button)
local IndexConfig = require(ReplicatedStorage.Shared.Config.IndexConfig)
local IndexWindow = require(script.Parent.Parent.UI.IndexWindow)
local Layout = require(script.Parent.Parent.UI.Layout)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local Pace = require(script.Parent.Parent.State.Pace)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30

-- The index sections, one per alien variant, with their tab texts.
local SECTION_KEYS: { [AlienConfig.VariantId]: Text.Key } = {
	Normal = "index.normal.button",
	Meteor = "index.meteor.button",
}

-- Each section's sets, in IndexConfig.SETS order.
local SECTION_SETS: { [string]: { AlienIndex.Set } } = {}
for _, variant in AlienConfig.VARIANT_ORDER do
	SECTION_SETS[variant] = {}
end
for _, set in IndexConfig.SETS do
	table.insert(SECTION_SETS[set.variant], set)
end

export type Dependencies = {
	profile: ProfileState.ProfileState,
	toasts: ToastState.ToastState,
	windows: WindowState.WindowState,
}

export type IndexController = {
	name: string,
	start: () -> (),
}

local IndexController = {}

function IndexController.new(dependencies: Dependencies): IndexController
	local profile = dependencies.profile
	local toast = dependencies.toasts.push
	local isOpen = dependencies.windows.slot("Index")
	local section = source("Normal" :: AlienConfig.VariantId)
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	-- Keys from the configs are checked where they are defined; they pass through `any` because
	-- the union of every string key is too much for the type checker here.
	local function nameOf(key: any): string
		return text(key)
	end

	local function cellOf(alienId: string): IndexWindow.Cell
		local alien = AlienConfig.ALIENS[alienId]
		local taken = profile.index().found[alienId]
		local state: IndexWindow.CellState = if taken == nil then "Unknown" elseif taken then "Found" else "New"
		return {
			alienId = alienId,
			state = state,
			label = nameOf(AlienConfig.TIERS[alien.tier].nameKey),
			color = AlienLooks.TIERS[alien.tier].color,
		}
	end

	local function guardianRow(set: AlienIndex.Set): IndexWindow.Row
		local index = profile.index()
		local found = AlienIndex.foundOf(index, set.aliens)
		local setState: IndexWindow.SetState = if AlienIndex.isSetClaimed(index, set)
			then "Done"
			elseif found == #set.aliens then "Ready"
			else "Collecting"
		local setText = `{found}/{#set.aliens}`
		if setState == "Ready" then
			local coins = Pace.reward(profile, IndexConfig.SET_REWARD_MINUTES, IndexConfig.MIN_REWARD_COINS, false)
			setText = text("index.setClaim.button", { coins = BigNum.format(coins) })
		end
		local cells = {}
		for _, alienId in set.aliens do
			table.insert(cells, cellOf(alienId))
		end
		return {
			kind = "Guardian",
			title = Names.guardian(locale, set.grade) or "?",
			setId = set.id,
			cells = cells,
			setText = setText,
			setState = setState,
		}
	end

	-- The open section's zone headers and guardian rows, from the station outwards.
	local function rows(): { IndexWindow.Row }
		local result: { IndexWindow.Row } = {}
		local zone: string? = nil
		for _, set in SECTION_SETS[section()] do
			local grade = AlienConfig.GRADES[set.grade]
			if grade.zone ~= zone then
				zone = grade.zone
				local header: IndexWindow.Row = {
					kind = "Zone",
					title = nameOf(ZoneConfig.ZONES[grade.zone].nameKey),
					setId = "",
					cells = {},
					setText = "",
					setState = "Collecting",
				}
				table.insert(result, header)
			end
			table.insert(result, guardianRow(set))
		end
		return result
	end

	local function waiting(): number
		return AlienIndex.waiting(profile.index(), IndexConfig.SETS)
	end

	local function waitingIn(variant: AlienConfig.VariantId): number
		return AlienIndex.waiting(profile.index(), SECTION_SETS[variant])
	end

	-- Found aliens of the open section, and how many it has.
	local function foundCount(): number
		local index = profile.index()
		local count = 0
		for _, set in SECTION_SETS[section()] do
			count += AlienIndex.foundOf(index, set.aliens)
		end
		return count
	end

	local function sectionSize(): number
		return #SECTION_SETS[section()] * #AlienConfig.TIER_ORDER
	end

	local function tabs(): { IndexWindow.Tab }
		local result: { IndexWindow.Tab } = {}
		for _, variant in AlienConfig.VARIANT_ORDER do
			table.insert(result, {
				name = `{variant}Tab`,
				text = text(SECTION_KEYS[variant]),
				active = function()
					return section() == variant
				end,
				badge = function()
					return waitingIn(variant)
				end,
				onClick = function()
					section(variant)
				end,
			})
		end
		return result
	end

	-- New aliens in the index since the last update: cheer, once for a batch arriving together
	-- (several eggs hatching on one tick). The first snapshot only sets what is known.
	local known: { [string]: boolean }? = nil
	local pendingFinds = 0
	local function announceFinds()
		local count = pendingFinds
		pendingFinds = 0
		local message = if count == 1
			then text("index.discovered.toast")
			else text("index.discoveredMany.toast", { count = count })
		toast(message, Theme.TOAST_GOOD)
	end
	local function watchFinds()
		local found = profile.index().found
		if not profile.loaded() then
			return
		end
		local previous = known
		known = table.clone(found)
		if not previous then
			return
		end
		for alienId in found do
			if previous[alienId] == nil then
				pendingFinds += 1
				if pendingFinds == 1 then
					task.defer(announceFinds)
				end
			end
		end
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			Vide.effect(watchFinds)
			return create("ScreenGui")({
				Name = "IndexUi",
				ResetOnSpawn = false,
				DisplayOrder = 10,

				Layout.placeInMenu(
					Button({
						name = "OpenIndex",
						text = text("index.open.button"),
						badge = waiting,
						onClick = function()
							isOpen(not isOpen())
						end,
					}),
					"Index"
				),

				IndexWindow({
					visible = function()
						return isOpen()
					end,
					title = text("index.window.title"),
					hints = {
						function()
							return text("index.found.hint", { count = foundCount(), total = sectionSize() })
						end,
						text("index.tap.hint"),
					},
					tabs = tabs(),
					rows = rows,
					setDone = text("index.setDone.hint"),
					onClaimAlien = function(alienId)
						Remotes.ClaimIndexAlien.Fire(alienId)
					end,
					onClaimSet = function(setId)
						Remotes.ClaimIndexSet.Fire(setId)
					end,
					claimAllText = text("index.claimAll.button"),
					canClaimAll = function()
						return waiting() > 0
					end,
					onClaimAll = function()
						Remotes.ClaimIndexAll.Fire()
					end,
					onClose = function()
						isOpen(false)
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[IndexController] PlayerGui did not appear")
		mountUi(playerGui)

		profile.indexRewarded.connect(function(coins)
			toast(text("index.rewarded.toast", { coins = BigNum.format(coins) }), Theme.TOAST_GOOD)
		end)
	end

	return {
		name = "IndexController",
		start = start,
	}
end

return table.freeze(IndexController)
