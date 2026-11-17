--!strict
-- The odds window on the client (decision 127, docs/design/screens/egg-odds.md): opened from the
-- odds row under an egg in the player's incubator, before "Hatch for R$". It lists every alien
-- the egg can hatch into with its chance, worked out from the same table the server hatches with
-- (Domain/HatchOdds), so what a player reads is what they get. Each opening builds the window anew
-- for that egg; it stays until closed (the egg may hatch meanwhile: these were its odds).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienIcons = require(ReplicatedStorage.Shared.Config.AlienIcons)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local HatchOdds = require(ReplicatedStorage.Shared.Domain.HatchOdds)
local Mount = require(script.Parent.Parent.UI.Mount)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local OddsWindow = require(script.Parent.Parent.UI.OddsWindow)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)
local WindowView = require(script.Parent.Parent.State.WindowView)

local create = Vide.create

local PLAYER_GUI_WAIT_TIMEOUT = 30

-- The size's word in the line about the egg.
local SIZE_KEYS: { [string]: Text.Key } = {
	Small = "egg.sizeSmall.hint",
	Medium = "egg.sizeMedium.hint",
	Large = "egg.sizeLarge.hint",
}

export type Dependencies = {
	profile: ProfileState.ProfileState,
	windows: WindowState.WindowState,
}

export type OddsController = {
	name: string,
	start: () -> (),
	-- Opens the window with the odds of `egg`.
	open: (egg: HatchOdds.Egg) -> (),
}

local OddsController = {}

-- What the window shows for `egg` in `locale`; nil for an egg this build cannot hatch.
local function contentOf(locale: Text.Locale, egg: HatchOdds.Egg): OddsWindow.Content?
	local draw = HatchOdds.of(egg)
	if not draw then
		return nil
	end
	local rounded = false
	local function percent(chance: number): string
		local text, wasRounded = HatchOdds.percentText(chance)
		rounded = rounded or wasRounded
		return text
	end

	local columns: { OddsWindow.Column } = {}
	for _, tier in HatchOdds.list(draw) do
		local color = AlienLooks.TIERS[tier.tier].color
		local rows: { OddsWindow.Row } = {}
		local tierName: string? = nil
		for _, outcome in tier.outcomes do
			local tierPart, kindPart = Names.alienParts(locale, outcome.alien)
			tierName = tierName or tierPart
			table.insert(rows, {
				icon = AlienIcons.iconOf(outcome.alien),
				color = color,
				name = kindPart or outcome.kind,
				chance = Text.get(locale, "egg.oddsChance.hint", { chance = percent(outcome.chance) }),
			})
		end
		table.insert(columns, {
			color = color,
			head = Text.get(locale, "odds.tier.hint", { tier = tierName or tier.tier, chance = percent(tier.chance) }),
			rows = rows,
		})
	end

	local income = HatchOdds.income()
	local notes = {
		Text.get(locale, "odds.income.hint", {
			min = tostring(income.min),
			max = tostring(income.max),
			chance = percent(income.chance),
		}),
		Text.get(locale, "odds.outfit.hint"),
	}
	if rounded then
		table.insert(notes, Text.get(locale, "odds.rounded.hint"))
	end

	-- A lucky egg (the star egg) hatches as a large one whatever its size: its star says so, and
	-- its own size would only mislead.
	local lucky = egg.luck ~= nil and egg.luck > 0
	local sizeKey = if lucky then nil else SIZE_KEYS[egg.size]
	local eggLine = Names.eggWithGuardian(locale, egg)
	return {
		egg = if sizeKey then `{eggLine} · {Text.get(locale, sizeKey)}` else eggLine,
		columns = columns,
		notes = notes,
	}
end

function OddsController.new(dependencies: Dependencies): OddsController
	local player = Players.LocalPlayer
	local isOpen = dependencies.windows.slot("Odds")
	local shownCoins = WindowView.of(isOpen, dependencies.profile.coins)
	local locale: Text.Locale = "en"
	local screen: ScreenGui? = nil
	-- Takes down the window of the last egg opened.
	local unmount: (() -> ())? = nil

	local function open(egg: HatchOdds.Egg)
		local content = contentOf(locale, egg)
		local parent = screen
		if not content or not parent then
			return
		end
		if unmount then
			unmount()
		end
		unmount = Mount.instance(function()
			return OddsWindow({
				visible = function()
					return isOpen()
				end,
				title = Text.get(locale, "odds.window.title"),
				coins = function()
					return BigNum.format(shownCoins())
				end,
				content = content,
				onClose = function()
					isOpen(false)
				end,
			})
		end, parent)
		isOpen(true)
	end

	local function start()
		locale = Text.localeOf(player)
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[OddsController] PlayerGui did not appear")
		screen = create("ScreenGui")({
			Name = "OddsUi",
			ResetOnSpawn = false,
			-- Over the HUD, like the other windows.
			DisplayOrder = 10,
			Parent = playerGui,
		}) :: ScreenGui
	end

	return {
		name = "OddsController",
		start = start,
		open = open,
	}
end

return table.freeze(OddsController)
