--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The controls window on the client (decision 105, docs/design/screens/controls.md): what each
-- flight button does. It opens by itself once a session for a new player (the tutorial's first
-- step: nothing delivered yet), and again from its "?" tile in the HUD menu or the H key. "Don't
-- show again" asks the server to keep the choice in the profile; the server's answer, an
-- attribute on the player, hides the tile and the window on joining for good. H still opens it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ControlsWindow = require(script.Parent.Parent.UI.ControlsWindow)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local Icons = require(script.Parent.Parent.UI.Icons)
local KeyNames = require(script.Parent.Parent.UI.KeyNames)
local MenuState = require(script.Parent.Parent.State.MenuState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The tutorial's first step (Domain/Tutorial: steal an egg): a new player who has delivered
-- nothing yet. The window opens by itself only then.
local FIRST_TUTORIAL_STEP = 1

export type Dependencies = {
	windows: WindowState.WindowState,
	menu: MenuState.MenuState,
	-- The tutorial hint's step (TutorialController.step; reactive).
	tutorialStep: () -> number?,
}

export type ControlsController = {
	name: string,
	start: () -> (),
}

-- A row of the window: the flight action it explains (its key and its button), and its texts.
type RowSpec = {
	name: string,
	-- The input action; nil for flying itself (the stick, or the movement keys).
	action: string?,
	icon: Icons.Name,
	color: Color3,
	title: Text.Key,
	hint: Text.Key,
	-- Flying itself says "the stick" on a touch screen.
	touchHint: Text.Key?,
}

local FLIGHT = Theme.NEON.FLIGHT

-- Flight down the left column, the egg and the attacks down the right.
local ROWS: { RowSpec } = {
	{
		name = "Fly",
		icon = "Jetpack",
		color = FLIGHT.Vertical,
		title = "controls.fly.title",
		hint = "controls.flyKeys.hint",
		touchHint = "controls.flyTouch.hint",
	},
	{
		name = "Up",
		action = FlightInputs.ASCEND,
		icon = "Up",
		color = FLIGHT.Vertical,
		title = "controls.up.title",
		hint = "controls.up.hint",
	},
	{
		name = "Down",
		action = FlightInputs.DESCEND,
		icon = "Down",
		color = FLIGHT.Vertical,
		title = "controls.down.title",
		hint = "controls.down.hint",
	},
	{
		name = "SlowMode",
		action = FlightInputs.SLOW_MODE,
		icon = "SlowMode",
		color = FLIGHT.SlowMode,
		title = "controls.slowMode.title",
		hint = "controls.slowMode.hint",
	},
	{
		name = "Grab",
		action = FlightInputs.GRAB,
		icon = "Egg",
		color = Theme.NEON.EGG,
		title = "controls.grab.title",
		hint = "controls.grab.hint",
	},
	{
		name = "Strike",
		action = FlightInputs.STRIKE,
		icon = "Strike",
		color = FLIGHT.Strike,
		title = "controls.strike.title",
		hint = "controls.strike.hint",
	},
	{
		name = "Harpoon",
		action = FlightInputs.HARPOON,
		icon = "Harpoon",
		color = FLIGHT.Harpoon,
		title = "controls.harpoon.title",
		hint = "controls.harpoon.hint",
	},
	{
		name = "Bomb",
		action = FlightInputs.BOMB,
		icon = "Bomb",
		color = FLIGHT.Bomb,
		title = "controls.bomb.title",
		hint = "controls.bomb.hint",
	},
}

local ControlsController = {}

function ControlsController.new(dependencies: Dependencies): ControlsController
	local player = Players.LocalPlayer
	local isOpen = dependencies.windows.slot("Controls")
	-- "Don't show again" as the server keeps it; nil until the profile has loaded.
	local hidden = source(nil :: boolean?)
	local readHidden = hidden :: () -> boolean?
	local inputMode = source(UserInputService.PreferredInput)
	local locale: Text.Locale = "en"

	local function text(key: Text.Key): string
		return Text.get(locale, key)
	end

	local function rowsOf(): { ControlsWindow.Row }
		local rows = {}
		for _, spec in ROWS do
			local action = spec.action
			table.insert(rows, {
				name = spec.name,
				icon = spec.icon,
				color = spec.color,
				title = text(spec.title),
				hint = function()
					local touch = inputMode() == Enum.PreferredInput.Touch
					return text(if touch and spec.touchHint then spec.touchHint else spec.hint)
				end,
				key = function()
					local mode = inputMode()
					if mode == Enum.PreferredInput.Touch then
						return ""
					elseif action then
						return KeyNames.forAction(player, locale, action, mode)
					end
					-- Flying itself: the movement keys; a gamepad's stick has no key to show.
					return if mode == Enum.PreferredInput.KeyboardAndMouse then text("key.move.hint") else ""
				end,
			})
		end
		return rows
	end

	local function toggleHidden()
		local now = Vide.untrack(readHidden) ~= true
		-- At once on screen; the server's attribute confirms it.
		hidden(now)
		Remotes.SetControlsHidden.Fire(now)
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			-- Opens by itself once a session for a new player, as soon as nothing else is open.
			local opened = false
			Vide.effect(function()
				if
					not opened
					and readHidden() == false
					and dependencies.tutorialStep() == FIRST_TUTORIAL_STEP
					and dependencies.windows.current() == nil
				then
					opened = true
					isOpen(true)
				end
			end)
			return create("ScreenGui")({
				Name = "ControlsUi",
				ResetOnSpawn = false,
				-- Over the HUD, like the other windows.
				DisplayOrder = 10,
				ControlsWindow({
					visible = function()
						return isOpen()
					end,
					texts = {
						title = text("controls.window.title"),
						hide = text("controls.hide.hint"),
						ok = text("controls.ok.button"),
					},
					rows = rowsOf(),
					hidden = function()
						return readHidden() == true
					end,
					onToggleHidden = toggleHidden,
					onClose = function()
						isOpen(false)
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		locale = Text.localeOf(player)
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[ControlsController] PlayerGui did not appear")

		local function readAttribute()
			local value = player:GetAttribute(TutorialConfig.CONTROLS_HIDDEN_ATTRIBUTE)
			hidden(if type(value) == "boolean" then value else nil)
		end
		player:GetAttributeChangedSignal(TutorialConfig.CONTROLS_HIDDEN_ATTRIBUTE):Connect(readAttribute)
		readAttribute()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			inputMode(UserInputService.PreferredInput)
		end)

		mountUi(playerGui)
		dependencies.menu.add({
			slot = "Controls",
			visible = function()
				return readHidden() == false
			end,
			-- Hidden for good, the window is still one key away on a keyboard (to change one's mind).
			keyWhenHidden = true,
			onPress = function()
				isOpen(not isOpen())
			end,
		})
	end

	return {
		name = "ControlsController",
		start = start,
	}
end

return table.freeze(ControlsController)
