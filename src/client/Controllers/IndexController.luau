--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The alien index on the client: the HUD menu tile with how many rewards wait, the index window
-- and the toasts for a new find and a taken reward. The window shows one section (the usual
-- aliens, the meteor ones), one zone and one guardian's set at a time; it opens where a reward
-- waits, else at the farthest guardian the player has aliens of (AlienIndex.openingSet). Rows
-- are built from the one alien registry (AlienConfig through IndexConfig.SETS) and the profile
-- copy; rewards shown use the formula the server pays with (Pace).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienIcons = require(ReplicatedStorage.Shared.Config.AlienIcons)
local AlienIndex = require(ReplicatedStorage.Shared.Domain.AlienIndex)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local IndexConfig = require(ReplicatedStorage.Shared.Config.IndexConfig)
local IndexWindow = require(script.Parent.Parent.UI.IndexWindow)
local MenuState = require(script.Parent.Parent.State.MenuState)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local Pace = require(script.Parent.Parent.State.Pace)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local ToastState = require(script.Parent.Parent.State.ToastState)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30

-- The index sections, one per alien variant, with their switch texts.
local SECTION_KEYS: { [AlienConfig.VariantId]: Text.Key } = {
	Normal = "index.normal.button",
	Meteor = "index.meteor.button",
}

-- Each section's sets, in IndexConfig.SETS order (by grade, so from the station outwards).
local SECTION_SETS: { [string]: { AlienIndex.Set } } = {}
for _, variant in AlienConfig.VARIANT_ORDER do
	SECTION_SETS[variant] = {}
end
for _, set in IndexConfig.SETS do
	table.insert(SECTION_SETS[set.variant], set)
end

local function zoneOf(set: AlienIndex.Set): ZoneConfig.ZoneId
	return AlienConfig.GRADES[set.grade].zone
end

-- The sets of one zone in one section.
local function zoneSets(variant: string, zone: ZoneConfig.ZoneId): { AlienIndex.Set }
	local result: { AlienIndex.Set } = {}
	for _, set in SECTION_SETS[variant] do
		if zoneOf(set) == zone then
			table.insert(result, set)
		end
	end
	return result
end

export type Dependencies = {
	profile: ProfileState.ProfileState,
	toasts: ToastState.ToastState,
	windows: WindowState.WindowState,
	menu: MenuState.MenuState,
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
	local zone = source(ZoneConfig.ZONE_ORDER[1])
	-- The picked guardian: its place among the zone's guardians, from the station outwards.
	local pick = source(1)
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
			color = AlienLooks.TIERS[alien.tier].color,
			icon = AlienIcons.iconOf(alienId),
		}
	end

	-- The picked zone's guardians in the open section, from the station outwards.
	local function guardians(): { IndexWindow.Guardian }
		local index = profile.index()
		local result: { IndexWindow.Guardian } = {}
		for position, set in zoneSets(section(), zone()) do
			table.insert(result, {
				title = Names.guardian(locale, set.grade) or "?",
				count = `{AlienIndex.foundOf(index, set.aliens)}/{#set.aliens}`,
				waiting = AlienIndex.waiting(index, { set }) > 0,
				done = AlienIndex.isSetClaimed(index, set),
				selected = position == pick(),
			})
		end
		return result
	end

	-- The picked guardian's set: a row per kind (IndexConfig lists a set's aliens kind by kind,
	-- each lowest tier first), and the set's state.
	local function setView(): IndexWindow.SetView?
		local set = zoneSets(section(), zone())[pick()]
		if not set then
			return nil
		end
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
		local tierCount = #AlienConfig.TIER_ORDER
		local kinds: { IndexWindow.KindRow } = {}
		for position, kindId in AlienConfig.GRADES[set.grade].kinds do
			local cells = {}
			for tier = 1, tierCount do
				table.insert(cells, cellOf(set.aliens[(position - 1) * tierCount + tier]))
			end
			table.insert(kinds, { title = nameOf(AlienConfig.KINDS[kindId].nameKey), cells = cells })
		end
		return { setId = set.id, kinds = kinds, setState = setState, setText = setText }
	end

	-- The guardian to show in a zone: the first with a reward waiting, else the nearest.
	local function firstWaiting(zoneId: ZoneConfig.ZoneId): number
		for position, set in zoneSets(section(), zoneId) do
			if AlienIndex.waiting(profile.index(), { set }) > 0 then
				return position
			end
		end
		return 1
	end

	local function zones(): { IndexWindow.Zone }
		local index = profile.index()
		local result: { IndexWindow.Zone } = {}
		for _, zoneId in ZoneConfig.ZONE_ORDER do
			local sets = zoneSets(section(), zoneId)
			local found, total = 0, 0
			for _, set in sets do
				found += AlienIndex.foundOf(index, set.aliens)
				total += #set.aliens
			end
			table.insert(result, {
				name = nameOf(ZoneConfig.ZONES[zoneId].nameKey),
				count = `{found}/{total}`,
				share = found / math.max(total, 1),
				waiting = AlienIndex.waiting(index, sets) > 0,
				selected = zone() == zoneId,
			})
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
		local count = 0
		for _, set in SECTION_SETS[section()] do
			count += #set.aliens
		end
		return count
	end

	-- The line under the count: where the rewards are, or where meteor aliens come from.
	local function hint(): string
		if waitingIn(section()) > 0 then
			return text("index.tap.hint")
		elseif section() == "Meteor" and foundCount() == 0 then
			return text("index.meteorSource.hint")
		end
		return ""
	end

	local function sections(): { IndexWindow.Section }
		local result: { IndexWindow.Section } = {}
		for _, variant in AlienConfig.VARIANT_ORDER do
			table.insert(result, {
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

	local function tiers(): { IndexWindow.Tier }
		local result: { IndexWindow.Tier } = {}
		for _, tier in AlienConfig.TIER_ORDER do
			table.insert(result, {
				name = nameOf(AlienConfig.TIERS[tier].shortKey),
				color = AlienLooks.TIERS[tier].color,
			})
		end
		return result
	end

	-- Where the window opens: a waiting reward first, else the farthest usual guardian with a
	-- find, else the nearest zone of the usual aliens. Picked once per opening, so the window
	-- does not jump while the player looks at it.
	local function pickOpening()
		local set = AlienIndex.openingSet(profile.index(), IndexConfig.SETS, SECTION_SETS.Normal)
		if set then
			section(set.variant :: AlienConfig.VariantId)
			zone(zoneOf(set))
			pick(table.find(zoneSets(set.variant, zoneOf(set)), set) or 1)
		else
			section("Normal")
			zone(ZoneConfig.ZONE_ORDER[1])
			pick(1)
		end
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
		toast(message, "Alien")
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
			local wasOpen = false
			Vide.effect(function()
				local open = isOpen()
				if open and not wasOpen then
					Vide.untrack(pickOpening)
				end
				wasOpen = open
			end)
			return create("ScreenGui")({
				Name = "IndexUi",
				ResetOnSpawn = false,
				DisplayOrder = 10,

				IndexWindow({
					visible = function()
						return isOpen()
					end,
					coins = function()
						return BigNum.format(profile.coins())
					end,
					texts = {
						title = text("index.window.title"),
						setDone = text("index.setDone.hint"),
						claimAll = text("index.claimAll.button"),
						found = function()
							return text("index.found.hint", { count = foundCount(), total = sectionSize() })
						end,
						hint = hint,
					},
					sections = sections(),
					zones = zones,
					tiers = tiers(),
					guardians = guardians,
					set = setView,
					onZone = function(position)
						local zoneId = ZoneConfig.ZONE_ORDER[position]
						zone(zoneId)
						pick(firstWaiting(zoneId))
					end,
					onGuardian = function(position)
						pick(position)
					end,
					onClaimAlien = function(alienId)
						Remotes.ClaimIndexAlien.Fire(alienId)
					end,
					onClaimSet = function(setId)
						Remotes.ClaimIndexSet.Fire(setId)
					end,
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
		locale = Text.localeOf(Players.LocalPlayer)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[IndexController] PlayerGui did not appear")
		mountUi(playerGui)
		-- The tile in the HUD menu row, with how many rewards wait; its key is answered by
		-- MenuState.
		dependencies.menu.add({
			slot = "Index",
			badge = waiting,
			onPress = function()
				isOpen(not isOpen())
			end,
		})

		profile.indexRewarded.connect(function(coins)
			toast(text("index.rewarded.toast", { coins = BigNum.format(coins) }), "Coins")
		end)
	end

	return {
		name = "IndexController",
		start = start,
	}
end

return table.freeze(IndexController)
