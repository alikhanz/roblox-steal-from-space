--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The in-game HUD: speed and coins, oxygen bar, low-oxygen warning and, on touch devices,
-- flight buttons. Reads the local character's simulation attributes (predicted, so the HUD is
-- lag-free) and the profile copy for coins.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage.Shared.Domain.Abilities)
local AbilityChips = require(script.Parent.Parent.UI.AbilityChips)
local AbilityState = require(script.Parent.Parent.State.AbilityState)
local ActionButton = require(script.Parent.Parent.UI.ActionButton)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Crosshair = require(script.Parent.Parent.UI.Crosshair)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local FlightButtons = require(script.Parent.Parent.UI.FlightButtons)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GoalCard = require(script.Parent.Parent.UI.GoalCard)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local HitFlash = require(script.Parent.Parent.UI.HitFlash)
local Layout = require(script.Parent.Parent.UI.Layout)
local MenuState = require(script.Parent.Parent.State.MenuState)
local MenuTile = require(script.Parent.Parent.UI.MenuTile)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local Oxygen = require(ReplicatedStorage.Shared.Domain.Oxygen)
local OxygenBar = require(script.Parent.Parent.UI.OxygenBar)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local ResourcePill = require(script.Parent.Parent.UI.ResourcePill)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SpeedGoal = require(ReplicatedStorage.Shared.Domain.SpeedGoal)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local TouchBindings = require(script.Parent.Parent.Input.TouchBindings)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- What a number shows before the profile arrives.
local NOT_LOADED = "—"
-- The first resource icon sticks out this far left of its plaque; the next one sticks into the
-- gap between plaques, so the gap is wider than that.
local RESOURCE_ICON_ROOM = 14
local RESOURCE_GAP = 20
local MENU_GAP = 7

local function leftPadding(pixels: number): UIPadding
	local instance = Instance.new("UIPadding")
	instance.PaddingLeft = UDim.new(0, pixels)
	return instance
end

-- Every guardian's recommended stat, from the station outwards: the speed goals (SpeedGoal).
local RECOMMENDED = (function(): { BigNum.BigNum }
	local list = {}
	for _, post in GuardianConfig.POSTS do
		table.insert(list, post.recommended)
	end
	return list
end)()

export type Dependencies = {
	coins: () -> BigNum.BigNum,
	-- Shows a short message (grabbed, delivered or dropped egg).
	toast: (text: string, color: Color3) -> (),
	abilities: AbilityState.AbilityState,
	-- The player's speed stat.
	speed: () -> BigNum.BigNum,
	-- True once the profile arrived; numbers show a dash before that.
	loaded: () -> boolean,
	-- The windows' tiles for the menu row.
	menu: MenuState.MenuState,
	-- Opens the shop from the speed goal; nil where nothing is sold (an unpublished place).
	openStore: (() -> ())?,
}

export type HudController = {
	name: string,
	start: () -> (),
}

local HudController = {}

function HudController.new(dependencies: Dependencies): HudController
	local oxygen = source(OxygenConfig.CAPACITY)
	local inSpace = source(false)
	-- Slow mode is on (the simulation keeps it on the character).
	local slowMode = source(false)
	local speed = dependencies.speed
	local loaded = dependencies.loaded
	local stunned = source(false)
	-- What the current hit says: a guardian's catch, the serpent's or a player's strike.
	local hitToast = source("guardian.caught.toast" :: Text.Key)
	-- True while an egg carrier is in the harpoon's reach of the camera's aim.
	local harpoonLocked = source(false)
	-- Keyboard, gamepad or touch: the key hints follow it.
	local inputMode = source(UserInputService.PreferredInput)
	-- Seconds of newbie protection left, from the player attribute.
	local newbieSecondsLeft = source(0)

	-- The same cone the server checks, on what this client can see: other characters that
	-- carry an egg, and test dummies.
	local function findHarpoonTarget(player: Player): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if not character or not root or not root:IsA("BasePart") or not camera then
			return false
		end
		local origin = root.Position
		local facing = camera.CFrame.LookVector
		local function inReach(part: BasePart): boolean
			return Abilities.isInCone(
				{ x = origin.X, y = origin.Y, z = origin.Z },
				{ x = facing.X, y = facing.Y, z = facing.Z },
				{ x = part.Position.X, y = part.Position.Y, z = part.Position.Z },
				PvpConfig.HARPOON.rangeStuds,
				PvpConfig.HARPOON.halfAngleRadians
			)
		end
		for _, other in Players:GetPlayers() do
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if other ~= player and otherCharacter and otherRoot and otherRoot:IsA("BasePart") then
				if otherCharacter:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE) ~= nil and inReach(otherRoot) then
					return true
				end
			end
		end
		for _, dummy in CollectionService:GetTagged(PvpConfig.DUMMY_TAG) do
			local dummyRoot = dummy:FindFirstChild("HumanoidRootPart")
			if dummyRoot and dummyRoot:IsA("BasePart") and inReach(dummyRoot) then
				return true
			end
		end
		return false
	end
	-- Rarity of the egg in the player's hands; nil with empty hands.
	local carried = source(nil :: string?)
	local readCarried = carried :: () -> string?
	local characterConnections: { RBXScriptConnection } = {}

	local function watchCharacter(character: Model)
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)

		local function readAttributes()
			local value = character:GetAttribute(OxygenConfig.ATTRIBUTE)
			oxygen(if type(value) == "number" then value else OxygenConfig.CAPACITY)
			inSpace(character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true)
			slowMode(character:GetAttribute(FlightConfig.SLOW_MODE_ATTRIBUTE) == true)
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
		table.insert(
			characterConnections,
			character:GetAttributeChangedSignal(FlightConfig.SLOW_MODE_ATTRIBUTE):Connect(readAttributes)
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

		-- The attacks: their input action, their word and their cooldown.
		local abilities = {
			{
				kind = "Strike" :: AbilityState.Kind,
				action = FlightInputs.STRIKE,
				text = Text.get(locale, "pvp.strike.button"),
			},
			{
				kind = "Harpoon" :: AbilityState.Kind,
				action = FlightInputs.HARPOON,
				text = Text.get(locale, "pvp.harpoon.button"),
			},
			{
				kind = "Bomb" :: AbilityState.Kind,
				action = FlightInputs.BOMB,
				text = Text.get(locale, "pvp.bomb.button"),
			},
		}
		local function coolingOf(kind: AbilityState.Kind): () -> boolean
			return function()
				return dependencies.abilities.isCooling(kind)
			end
		end
		-- The key bound to an action, worded for the current input (reads the same bindings
		-- the input uses).
		local KEY_WORDS: { [string]: Text.Key } = {
			MouseLeftButton = "key.mouseLeft.hint",
			LeftControl = "key.control.hint",
			Space = "key.space.hint",
		}
		local function keyOf(actionName: string): () -> string
			return function()
				local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
				local key = if context then FlightInputs.boundKey(context, actionName, inputMode()) else nil
				if not key then
					return "?"
				end
				local word = KEY_WORDS[key.Name]
				if word then
					return Text.get(locale, word)
				end
				-- Gamepad buttons drop their "Button" prefix: ButtonR2 is "R2".
				return (string.gsub(key.Name, "^Button", ""))
			end
		end
		local function noCooldown(): string
			return ""
		end
		local function never(): boolean
			return false
		end
		local function isSlow(): boolean
			return slowMode()
		end
		local function plainChip(labelKey: Text.Key, actionName: string): AbilityChips.Chip
			return {
				label = Text.get(locale, labelKey),
				key = keyOf(actionName),
				cooldown = noCooldown,
				cooling = never,
			}
		end
		local chips: { AbilityChips.Chip } = {
			plainChip("hud.ascend.hint", FlightInputs.ASCEND),
			plainChip("hud.descend.hint", FlightInputs.DESCEND),
			plainChip("hud.grab.hint", FlightInputs.GRAB),
			{
				label = Text.get(locale, "hud.slowMode.hint"),
				key = keyOf(FlightInputs.SLOW_MODE),
				cooldown = noCooldown,
				cooling = never,
				active = isSlow,
			},
		}
		local buttons = {}
		for _, ability in abilities do
			table.insert(chips, {
				label = ability.text,
				key = keyOf(ability.action),
				cooldown = function()
					local left = dependencies.abilities.left(ability.kind)
					return if left > 0
						then Text.get(locale, "pvp.cooldown.hint", { seconds = string.format("%.1f", left) })
						else ""
				end,
				cooling = coolingOf(ability.kind),
			})
			table.insert(buttons, { action = ability.action, text = ability.text, cooling = coolingOf(ability.kind) })
		end
		local function chipsVisible(): boolean
			return inSpace() and inputMode() ~= Enum.PreferredInput.Touch
		end

		local function goal(): SpeedGoal.Goal?
			return SpeedGoal.next(speed(), RECOMMENDED)
		end

		-- One tile per menu slot, in the slots' order; a slot no window has added stays hidden.
		local function menuTiles(): { Instance }
			local tiles: { Instance } = {}
			for order, entry in dependencies.menu.slots() do
				local function added(): MenuState.Tile?
					return dependencies.menu.tile(entry.slot)
				end
				table.insert(
					tiles,
					MenuTile({
						name = entry.slot,
						icon = entry.slot,
						color = Theme.NEON.TILE[entry.slot],
						onPress = function()
							local tile = added()
							if tile then
								tile.onPress()
							end
						end,
						badge = function()
							local tile = added()
							return if tile and tile.badge then tile.badge() else 0
						end,
						keyText = function()
							return if inputMode() == Enum.PreferredInput.KeyboardAndMouse then entry.key.Name else ""
						end,
						visible = function()
							return MenuState.isShown(added())
						end,
						layoutOrder = order,
					})
				)
			end
			return tiles
		end

		-- Components are created inside mount: their reactive properties need Vide's scope.
		Vide.mount(function()
			-- A guardian comes within reach: cheer. The first reading only notes where the player is.
			local lastGoal: number? = nil
			Vide.effect(function()
				local current = goal()
				local post = if current then current.post else #RECOMMENDED + 1
				local before = lastGoal
				lastGoal = post
				if before and post > before then
					local reached: any = GuardianConfig.POSTS[post - 1].nameKey
					local name = Text.get(locale, reached)
					dependencies.toast(Text.get(locale, "speed.goalReached.toast", { name = name }), Theme.TOAST_GOOD)
				end
			end)
			local children: { Instance } = {
				Crosshair({
					visible = inSpace,
					locked = harpoonLocked,
					lockedText = Text.get(locale, "pvp.harpoonLocked.hint"),
				}),
				AbilityChips({ visible = chipsVisible, chips = chips }),
				HitFlash({
					visible = stunned,
					text = function()
						return Text.get(locale, hitToast())
					end,
				}),
				-- The left column (docs/design/screens/hud.md): the resources in a row, the speed
				-- goal under them. It starts under Roblox's top bar: the ScreenGui keeps the inset.
				create("Frame")({
					Name = "Stats",
					Position = UDim2.fromOffset(Theme.NEON.EDGE, Theme.NEON.GAP),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Layout.screenScale(),
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, Theme.NEON.GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					create("Frame")({
						Name = "Resources",
						LayoutOrder = 1,
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						-- Room for the first icon, which sticks out left of its plaque.
						leftPadding(RESOURCE_ICON_ROOM),
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, RESOURCE_GAP),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						ResourcePill({
							name = "Speed",
							icon = "Bolt",
							color = Theme.NEON.SPEED,
							value = function()
								return if loaded() then BigNum.format(speed()) else NOT_LOADED
							end,
							layoutOrder = 1,
						}),
						ResourcePill({
							name = "Coins",
							icon = "Coin",
							color = Theme.NEON.COINS,
							value = function()
								return if loaded() then BigNum.format(dependencies.coins()) else NOT_LOADED
							end,
							layoutOrder = 2,
						}),
						-- How long nobody can rob this player (and they cannot rob anyone): last in
						-- the row, as it goes away.
						ResourcePill({
							name = "Newbie",
							icon = "Shield",
							color = Theme.NEON.SHIELD,
							textSize = Theme.NEON.TEXT_SECTION,
							value = function()
								local minutes = math.ceil(newbieSecondsLeft() / 60)
								return Text.get(locale, "time.minutesShort.hint", { count = minutes })
							end,
							visible = function()
								return newbieSecondsLeft() > 0
							end,
							layoutOrder = 3,
						}),
					}),
					-- The next guardian to grow towards, how far the stat is from it, and the way to
					-- the training packs in the shop.
					GoalCard({
						title = function()
							local current = goal()
							local key: any = if current then GuardianConfig.POSTS[current.post].nameKey else nil
							return if key
								then Text.get(locale, "speed.goal.title", { name = Text.get(locale, key) })
								else ""
						end,
						value = function()
							local current = goal()
							return if current then `{BigNum.format(speed())} / {BigNum.format(current.target)}` else ""
						end,
						progress = function()
							local current = goal()
							return if current then current.progress else 1
						end,
						more = if dependencies.openStore
							then ActionButton({
								name = "MoreSpeed",
								text = Text.get(locale, "store.goal.button"),
								color = Theme.NEON.ACTION.Coins,
								size = "Small",
								onClick = dependencies.openStore,
							})
							else nil,
						layoutOrder = 2,
						visible = function()
							return loaded() and goal() ~= nil
						end,
					}),
					-- The windows' tiles in a row; a hidden one closes the gap (MenuState).
					create("Frame")({
						Name = "Menu",
						LayoutOrder = 3,
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, MENU_GAP),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						menuTiles(),
					}),
					-- The egg in hand: the thief sees their own back, so the HUD says it. Moves to
					-- the bottom centre with the oxygen bar (plan step 7).
					ResourcePill({
						name = "CarriedEgg",
						icon = "Egg",
						color = Theme.NEON.EGG,
						textSize = Theme.NEON.TEXT_SECTION,
						value = function()
							local rarity = readCarried()
							local name = if rarity then Names.egg(locale, rarity) or rarity else ""
							return `{Text.get(locale, "egg.carried.hint")}: {name}`
						end,
						visible = function()
							return readCarried() ~= nil
						end,
						layoutOrder = 4,
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
						abilities = buttons,
						slowMode = {
							action = FlightInputs.SLOW_MODE,
							text = Text.get(locale, "hud.slowMode.hint"),
							active = isSlow,
						},
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
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			inputMode(UserInputService.PreferredInput)
		end)
		local function readNewbie()
			local value = player:GetAttribute(PvpConfig.NEWBIE_ATTRIBUTE)
			newbieSecondsLeft(if type(value) == "number" then value else 0)
		end
		player:GetAttributeChangedSignal(PvpConfig.NEWBIE_ATTRIBUTE):Connect(readNewbie)
		readNewbie()
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
				hitToast(
					if by == nil or by == GuardianConfig.HIT_BY_GUARDIAN
						then "guardian.caught.toast"
						elseif by == SerpentConfig.HIT_BY then "serpent.caught.toast"
						else "pvp.struck.toast"
				)
				if by == player.Name then
					stunned(false)
				end
			end

			harpoonLocked(inSpace() and findHarpoonTarget(player))

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
			elseif inSpace() then
				-- Lost out in space without a hit: only a harpoon does that.
				dependencies.toast(Text.get(locale, "pvp.harpooned.toast"), Theme.TOAST_BAD)
			end
		end)
	end

	return {
		name = "HudController",
		start = start,
	}
end

return table.freeze(HudController)
