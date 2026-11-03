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
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local FlightButtons = require(script.Parent.Parent.UI.FlightButtons)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local HitFlash = require(script.Parent.Parent.UI.HitFlash)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
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
	-- Shows a short message (grabbed, delivered or dropped egg).
	toast: (text: string, color: Color3) -> (),
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
	-- True while the current hit came from a guardian (the words differ for a player's strike).
	local hitByGuardian = source(true)
	-- Rarity of the egg in the player's hands; nil with empty hands.
	local carried = source(nil :: string?)
	local readCarried = carried :: () -> string?
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
					text = function()
						return Text.get(locale, if hitByGuardian() then "guardian.caught.toast" else "pvp.struck.toast")
					end,
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
					-- The egg in hand: the thief sees their own back, so the HUD says it.
					StatBadge({
						name = "EggBadge",
						title = Text.get(locale, "egg.carried.hint"),
						icon = "🥚",
						color = Theme.TEXT,
						value = function()
							local rarity = readCarried()
							return if rarity then Names.egg(locale, rarity) or rarity else ""
						end,
						visible = function()
							return readCarried() ~= nil
						end,
						layoutOrder = 3,
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
						strikeAction = FlightInputs.STRIKE,
						strikeText = Text.get(locale, "pvp.strike.button"),
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
		-- The hit and the carried egg are written by the server onto the predicted character:
		-- changed signals do not fire for that on the client, so they are polled (see CLAUDE.md,
		-- Studio notes). Taking an egg and dropping it are announced here; a delivery is
		-- announced by the bay window, which sees the egg land in the incubator (a grab on the
		-- platform is delivered the same instant, before this poll could see it).
		local lastCharacter: Model? = nil
		RunService.Heartbeat:Connect(function()
			local character = player.Character
			local isStunned = character ~= nil and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) ~= nil
			stunned(isStunned)
			if isStunned and character then
				local by = character:GetAttribute(GuardianConfig.HIT_BY_ATTRIBUTE)
				-- Hitting oneself is the strike's own miss stall: no words for that.
				hitByGuardian(by == nil or by == GuardianConfig.HIT_BY_GUARDIAN)
				if by == player.Name then
					stunned(false)
				end
			end

			local rarity = character and character:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE)
			local now = if type(rarity) == "string" then rarity else nil
			local before = readCarried()
			local sameCharacter = character == lastCharacter
			lastCharacter = character
			if now == before then
				return
			end
			carried(now)
			if not sameCharacter then
				return
			end
			if now then
				dependencies.toast(Text.get(locale, "egg.grabbed.toast"), Theme.TOAST_GOOD)
			elseif isStunned then
				dependencies.toast(Text.get(locale, "egg.dropped.toast"), Theme.TOAST_BAD)
			end
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
