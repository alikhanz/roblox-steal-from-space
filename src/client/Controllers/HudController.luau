--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The in-game HUD: speed and coins, oxygen bar, low-oxygen warning and, on touch devices,
-- flight buttons. Reads the local character's simulation attributes (predicted, so the HUD is
-- lag-free) and the profile copy for coins.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local FlightButtons = require(script.Parent.Parent.UI.FlightButtons)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local HitFlash = require(script.Parent.Parent.UI.HitFlash)
local Oxygen = require(ReplicatedStorage.Shared.Domain.Oxygen)
local OxygenBar = require(script.Parent.Parent.UI.OxygenBar)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local StatBadge = require(script.Parent.Parent.UI.StatBadge)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local TouchBindings = require(script.Parent.Parent.Input.TouchBindings)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
local STAT_GAP = 8

export type Dependencies = {
	coins: () -> BigNum.BigNum,
}

export type HudController = {
	name: string,
	start: () -> (),
}

local HudController = {}

function HudController.new(dependencies: Dependencies): HudController
	local oxygen = source(OxygenConfig.CAPACITY)
	local inSpace = source(false)
	local speed = source(SpeedConfig.STARTING_SPEED)
	local stunned = source(false)
	local characterConnections: { RBXScriptConnection } = {}

	local function readSpeed(player: Player)
		local mantissa = player:GetAttribute(SpeedConfig.MANTISSA_ATTRIBUTE)
		local exponent = player:GetAttribute(SpeedConfig.EXPONENT_ATTRIBUTE)
		local value = BigNum.fromSaved({ mantissa = mantissa, exponent = exponent })
		speed(value or SpeedConfig.STARTING_SPEED)
	end

	local function watchCharacter(character: Model)
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)

		local function readAttributes()
			local value = character:GetAttribute(OxygenConfig.ATTRIBUTE)
			oxygen(if type(value) == "number" then value else OxygenConfig.CAPACITY)
			inSpace(character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true)
		end
		readAttributes()
		table.insert(
			characterConnections,
			character:GetAttributeChangedSignal(OxygenConfig.ATTRIBUTE):Connect(readAttributes)
		)
		table.insert(
			characterConnections,
			character:GetAttributeChangedSignal(FlightConfig.IN_SPACE_ATTRIBUTE):Connect(readAttributes)
		)
	end

	local function start()
		local player = Players.LocalPlayer
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)

		local function fraction(): number
			return Oxygen.fraction(oxygen(), OxygenConfig.CAPACITY)
		end
		local function isLow(): boolean
			return inSpace() and fraction() < OxygenConfig.LOW_FRACTION
		end
		local function isOxygenVisible(): boolean
			return inSpace() or fraction() < 1
		end

		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[HudController] PlayerGui did not appear")

		-- Components are created inside mount: their reactive properties need Vide's scope.
		Vide.mount(function()
			local children: { Instance } = {
				HitFlash({
					visible = stunned,
					text = Text.get(locale, "guardian.caught.toast"),
				}),
				create("Frame")({
					Name = "Stats",
					Position = UDim2.fromOffset(Theme.MARGIN, Theme.MARGIN),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, STAT_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					StatBadge({
						name = "SpeedBadge",
						title = Text.get(locale, "speed.stat.title"),
						icon = "⚡",
						color = Theme.SPEED,
						value = function()
							return BigNum.format(speed())
						end,
						layoutOrder = 1,
					}),
					StatBadge({
						name = "CoinsBadge",
						title = Text.get(locale, "coins.stat.title"),
						icon = "●",
						color = Theme.COINS,
						value = function()
							return BigNum.format(dependencies.coins())
						end,
						layoutOrder = 2,
					}),
				}),
				OxygenBar({
					fraction = fraction,
					isLow = isLow,
					visible = isOxygenVisible,
					warningText = Text.get(locale, "oxygen.low.toast"),
				}),
			}
			if UserInputService.TouchEnabled then
				table.insert(
					children,
					FlightButtons({
						visible = inSpace,
						ascendAction = FlightInputs.ASCEND,
						descendAction = FlightInputs.DESCEND,
						onButton = function(actionName, button)
							task.spawn(TouchBindings.bind, player, actionName, button)
						end,
					})
				)
			end

			return create("ScreenGui")({
				Name = "Hud",
				ResetOnSpawn = false,
				children,
			})
		end, playerGui)

		player.CharacterAdded:Connect(watchCharacter)
		if player.Character then
			watchCharacter(player.Character)
		end
		-- The hit is written by the server onto the predicted character: changed signals do not
		-- fire for that on the client, so it is polled (see CLAUDE.md, Studio notes).
		RunService.Heartbeat:Connect(function()
			local character = player.Character
			stunned(character ~= nil and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) ~= nil)
		end)
		-- Mantissa and exponent arrive separately; reading both on either change is harmless.
		player:GetAttributeChangedSignal(SpeedConfig.MANTISSA_ATTRIBUTE):Connect(function()
			readSpeed(player)
		end)
		player:GetAttributeChangedSignal(SpeedConfig.EXPONENT_ATTRIBUTE):Connect(function()
			readSpeed(player)
		end)
		readSpeed(player)
	end

	return {
		name = "HudController",
		start = start,
	}
end

return table.freeze(HudController)
