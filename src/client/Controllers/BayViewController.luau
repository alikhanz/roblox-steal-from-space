--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The client side of bays: the owner's name on their sign board, the screens of the island's
-- terminals (places, incubator, trainer: docs/design/screens/terminals.md), a chip over every
-- alien (what it earns), a countdown over every egg warming (and "waiting" over the queued ones),
-- the shelf's count, and for the owner a free place's mark and an egg that cannot hatch (decision
-- 110, docs/design/screens/aliens-and-hints.md).
-- Everything is keyed by the instance and torn down when it goes, since bays stream and are
-- rebuilt by the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggIcon = require(script.Parent.Parent.UI.EggIcon)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local Incubator = require(ReplicatedStorage.Shared.Domain.Incubator)
local IncubatorShape = require(ReplicatedStorage.Shared.Config.IncubatorShape)
local Layout = require(script.Parent.Parent.UI.Layout)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Mount = require(script.Parent.Parent.UI.Mount)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local TerminalScreen = require(script.Parent.Parent.UI.TerminalScreen)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WorldChip = require(script.Parent.Parent.UI.WorldChip)

local create = Vide.create

local PART_WAIT_TIMEOUT = 10
local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The owner's name on their sign board: its text's resolution and the room round it (the
-- board is 28 studs wide: half the old resolution keeps the letters as sharp, at a quarter of the
-- texture).
local BOARD_PIXELS_PER_STUD = 25
local BOARD_PADDING = 8
-- Over the top of the alien's head.
local ALIEN_STUDS_ABOVE = 1
-- A waiting egg's chip, just over its top (eggs come in three sizes). An egg in a capsule hangs
-- its chip over the capsule's petals (Domain/Incubator.chipAbove).
local EGG_STUDS_ABOVE_TOP = BayLooks.EGG_CHIP_OVER_EGG
-- The owner's name reads from well outside the island (docs/design/screens/markers.md); what
-- stands on it only up close, or the labels pile up on each other.
local SIGN_MAX_DISTANCE = 400
local CONTENTS_MAX_DISTANCE = 35
-- A grown alien's chip reads from farther, this many studs more per stud of its height.
local CONTENTS_DISTANCE_PER_HEIGHT = 2
-- On the shelf (docs/design/screens/storage-shelf.md) 24 chips over each other read as a mess: an
-- alien there shows its chip only up close, just over its head (under the board above).
local SHELF_CHIP_MAX_DISTANCE = 12
local SHELF_CHIP_STUDS_ABOVE = 0.3
-- Countdowns are whole seconds: once a second is enough.
local COUNTDOWN_INTERVAL = 1
-- The shelf's count reads from across the island; a free place's mark from near it.
local SHELF_COUNT_MAX_DISTANCE = 120
local FREE_PLACE_MAX_DISTANCE = 60
local FREE_PLACE_STUDS_ABOVE = 2.5
-- A free place's ring breathes: its transparency swings to this, one beat this long.
local FREE_RING_FADE = 0.75
local FREE_RING_SECONDS = 0.8

export type Dependencies = {
	-- The owner's own data: the buttons on their terminals need the coins and the jetpack.
	profile: ProfileState.ProfileState,
}

export type BayViewController = {
	name: string,
	start: () -> (),
}

type View = {
	unmount: () -> (),
	-- Incubator eggs refresh their countdown; nil for the rest.
	countdown: (() -> ())?,
}

local BayViewController = {}

function BayViewController.new(dependencies: Dependencies): BayViewController
	local views: { [Instance]: View } = {}
	local locale: Text.Locale = "en"
	local profile = dependencies.profile

	local function isOwn(bay: Instance): boolean
		return bay:GetAttribute(BayConfig.OWNER_ID_ATTRIBUTE) == Players.LocalPlayer.UserId
	end

	-- True when `instance` stands in the local player's own bay.
	local function inOwnBay(instance: Instance): boolean
		local current = instance.Parent
		while current and current ~= workspace do
			if CollectionService:HasTag(current, BayConfig.TAG) then
				return isOwn(current)
			end
			current = current.Parent
		end
		return false
	end

	-- The owner's bay has no free place and a full shelf: ready eggs wait (decision 110).
	local function ownBayFull(): boolean
		return not Bay.hasRoom(profile.bay(), BayConfig.SHELF_SLOTS)
	end

	local function canAfford(price: BigNum.BigNum): boolean
		return not BigNum.lessThan(profile.coins(), price)
	end

	-- A number attribute of `instance` as a source that follows it; the connection goes with
	-- the mount scope.
	local function attributeSource(instance: Instance, name: string): () -> number
		local value = Vide.source(0)
		local function read()
			local raw = instance:GetAttribute(name)
			value(if type(raw) == "number" then raw else 0)
		end
		read()
		local connection = instance:GetAttributeChangedSignal(name):Connect(read)
		Vide.cleanup(function()
			connection:Disconnect()
		end)
		return value
	end

	-- Drops the view of `instance` and of anything labelled inside it (a bay's trainer pad).
	local function remove(instance: Instance)
		for key, view in views do
			if key == instance or key:IsDescendantOf(instance) then
				views[key] = nil
				view.unmount()
			end
		end
	end

	-- Mounts a label once the part is there; the server builds models part by part.
	-- Signs with buttons mount here: a BillboardGui takes clicks only from inside PlayerGui.
	local playerGui: Instance? = nil

	-- An egg's rarity colour for its chip (EggLooks), the egg's colour when unknown.
	local function eggColor(part: BasePart): Color3
		local rarity = part:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE)
		local look = if type(rarity) == "string" then (EggLooks.RARITIES :: any)[rarity] else nil
		return if look then look.color else Theme.NEON.EGG
	end

	-- Mounts a label once the part is there; the server builds models part by part. `clickable`
	-- puts the sign into PlayerGui (adorned to the part) so its button works.
	local function label(
		instance: Instance,
		partName: string?,
		build: (BasePart) -> (Instance, (() -> ())?),
		clickable: boolean?
	)
		task.spawn(function()
			local part: Instance? = if partName then instance:WaitForChild(partName, PART_WAIT_TIMEOUT) else instance
			if views[instance] or not instance:IsDescendantOf(workspace) then
				return
			end
			if not part or not part:IsA("BasePart") then
				warn(`[BayViewController] {instance:GetFullName()} has no {partName or "part"}; no label`)
				return
			end
			local countdown: (() -> ())? = nil
			local parent: Instance = if clickable and playerGui then playerGui else instance
			local unmount = Mount.instance(function()
				local gui, tick = build(part)
				countdown = tick
				return gui
			end, parent)
			views[instance] = { unmount = unmount, countdown = countdown }
		end)
	end

	-- The owner's name on their sign board, on both faces: read from inside the island and by
	-- whoever flies up to it.
	local function ownerBoard(part: BasePart, text: string): Instance
		local faces = Instance.new("Folder")
		faces.Name = "OwnerBoard"
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = create("SurfaceGui")({
				Name = face.Name,
				Adornee = part,
				Face = face,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = BOARD_PIXELS_PER_STUD,
				MaxDistance = SIGN_MAX_DISTANCE,
				LightInfluence = 0,
				create("TextLabel")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = Theme.NEON.FONT,
					TextScaled = true,
					TextColor3 = Theme.NEON.TEXT,
					Text = text,
					Layout.padding(BOARD_PADDING, BOARD_PADDING),
				}),
			})
			gui.Parent = faces
		end
		return faces
	end

	-- A terminal's screen once the terminal is there; only the owner's screen takes clicks.
	local function terminal(bay: Instance, name: string, build: (screen: BasePart) -> SurfaceGui)
		task.spawn(function()
			local model = bay:WaitForChild(name, PART_WAIT_TIMEOUT)
			if not model or not bay:IsDescendantOf(workspace) then
				return
			end
			label(model, BayConfig.TERMINAL_SCREEN_NAME, function(part)
				return build(part), nil
			end, isOwn(bay))
		end)
	end

	-- The places' terminal: how many of the bought places have an alien (as every bay counter:
	-- taken of bought, no maximum), and for the owner one more place.
	local function watchPlacesTerminal(bay: Instance)
		terminal(bay, BayConfig.PLACES_TERMINAL_NAME, function(screen)
			local count = attributeSource(bay, BayConfig.POD_COUNT_ATTRIBUTE)
			local taken = attributeSource(bay, BayConfig.TAKEN_POD_COUNT_ATTRIBUTE)
			local function price(): BigNum.BigNum
				return Bay.podPrice(
					count(),
					BayConfig.STARTING_PODS,
					BayConfig.POD_PRICE_BASE,
					BayConfig.POD_PRICE_GROWTH
				)
			end
			local function full(): boolean
				return count() >= BayConfig.MAX_PODS
			end
			-- What the spots earn (decision 110), or the old hint while nothing earns yet.
			local income = Vide.source("")
			local function readIncome()
				local raw = bay:GetAttribute(BayConfig.INCOME_ATTRIBUTE)
				income(if type(raw) == "string" then raw else "")
			end
			readIncome()
			local connection = bay:GetAttributeChangedSignal(BayConfig.INCOME_ATTRIBUTE):Connect(readIncome)
			Vide.cleanup(function()
				connection:Disconnect()
			end)
			return TerminalScreen({
				adornee = screen,
				color = BayLooks.PLACES_COLOR,
				title = Text.get(locale, "terminal.places.title"),
				value = function()
					return Text.get(locale, "terminal.count.title", { count = taken(), max = count() })
				end,
				hint = function()
					local earned = income()
					return if earned ~= ""
						then Text.get(locale, "terminal.placesIncome.hint", { income = earned })
						else Text.get(locale, "terminal.places.hint")
				end,
				button = if isOwn(bay)
					then {
						text = function()
							return Text.get(locale, "terminal.price.button", { price = BigNum.format(price()) })
						end,
						enabled = function()
							return not full() and canAfford(price())
						end,
						onClick = function()
							Remotes.BuyPod.Fire()
						end,
					}
					else nil,
				done = full,
				doneText = Text.get(locale, "terminal.maxed.hint"),
			})
		end)
	end

	-- The incubator's terminal (decision 058): eggs warming of its slots, whether one is free or
	-- how many wait, and for the owner one more slot. The countdowns are over the eggs.
	local function watchIncubatorTerminal(bay: Instance)
		task.spawn(function()
			local incubator = bay:WaitForChild(BayConfig.INCUBATOR_NAME, PART_WAIT_TIMEOUT)
			if not incubator or not bay:IsDescendantOf(workspace) then
				return
			end
			terminal(bay, BayConfig.INCUBATOR_TERMINAL_NAME, function(screen)
				local count = attributeSource(incubator, BayConfig.INCUBATOR_COUNT_ATTRIBUTE)
				local slots = attributeSource(incubator, BayConfig.INCUBATOR_SLOTS_ATTRIBUTE)
				local waiting = attributeSource(incubator, BayConfig.INCUBATOR_WAITING_ATTRIBUTE)
				local function price(): BigNum.BigNum
					return Bay.slotPrice(
						slots(),
						BayConfig.STARTING_INCUBATOR_SLOTS,
						BayConfig.SLOT_PRICE_BASE,
						BayConfig.SLOT_PRICE_GROWTH
					)
				end
				local function full(): boolean
					return slots() >= BayConfig.MAX_INCUBATOR_SLOTS
				end
				return TerminalScreen({
					adornee = screen,
					color = BayLooks.INCUBATOR_COLOR,
					title = Text.get(locale, "terminal.incubator.title"),
					value = function()
						return Text.get(locale, "terminal.count.title", { count = count(), max = slots() })
					end,
					hint = function()
						if waiting() > 0 then
							return Text.get(locale, "bay.incubatorWaiting.hint", { count = waiting() })
						end
						return Text.get(
							locale,
							if count() < slots() then "bay.incubatorFree.hint" else "bay.incubatorFull.hint"
						)
					end,
					button = if isOwn(bay)
						then {
							text = function()
								return Text.get(locale, "terminal.price.button", { price = BigNum.format(price()) })
							end,
							enabled = function()
								return not full() and canAfford(price())
							end,
							onClick = function()
								Remotes.BuyIncubatorSlot.Fire()
							end,
						}
						else nil,
					done = full,
					doneText = Text.get(locale, "terminal.maxed.hint"),
				})
			end)
		end)
	end

	-- The trainer's terminal: its level and the rate the stat really grows at on it, and for the
	-- owner the next level.
	local function watchTrainerTerminal(bay: Instance)
		terminal(bay, BayConfig.TRAINER_TERMINAL_NAME, function(screen)
			local level = attributeSource(bay, BayConfig.TRAINER_LEVEL_ATTRIBUTE)
			local function price(): BigNum.BigNum
				return Upgrades.trainerPrice(level(), UpgradeConfig.TUNING)
			end
			local own = isOwn(bay)
			-- The trainer's speed points with the owner's passes, times the owner's jetpack (the
			-- owner's own copy for them, the owner's player attributes for others).
			local ownerId = bay:GetAttribute(BayConfig.OWNER_ID_ATTRIBUTE)
			local owner = if own
				then Players.LocalPlayer
				elseif type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId)
				else nil
			local jetpackLevel: () -> number
			if own then
				jetpackLevel = function()
					return profile.upgrades().jetpackLevel
				end
			else
				jetpackLevel = if owner
					then attributeSource(owner, UpgradeConfig.JETPACK_LEVEL_ATTRIBUTE)
					else function()
						return 0
					end
			end
			-- 0 until the server writes it: no passes known yet.
			local passMultiplier = if owner
				then attributeSource(owner, MonetizationConfig.TRAINER_MULTIPLIER_ATTRIBUTE)
				else function()
					return 0
				end
			return TerminalScreen({
				adornee = screen,
				color = BayLooks.TRAINER_RING_COLOR,
				title = Text.get(locale, "terminal.trainer.title"),
				value = function()
					return Text.get(locale, "terminal.level.title", { level = level() })
				end,
				hint = function()
					local rate = BigNum.mul(
						Purchases.trainerRate(level(), math.max(passMultiplier(), 1), UpgradeConfig.TUNING),
						Upgrades.jetpackMultiplier(jetpackLevel(), UpgradeConfig.TUNING)
					)
					return Text.get(locale, "terminal.trainerRate.hint", { rate = BigNum.format(rate) })
				end,
				hintColor = Theme.NEON.SPEED,
				button = if own
					then {
						text = function()
							return Text.get(locale, "terminal.price.button", { price = BigNum.format(price()) })
						end,
						enabled = function()
							return canAfford(price())
						end,
						onClick = function()
							Remotes.UpgradeTrainer.Fire()
						end,
					}
					else nil,
			})
		end)
	end

	-- The shelf's count over its crown, "12/24": red with its glow once full (decision 110).
	local function watchShelf(bay: Instance)
		task.spawn(function()
			local shelf = bay:WaitForChild(BayConfig.SHELF_NAME, PART_WAIT_TIMEOUT)
			if not shelf or not bay:IsDescendantOf(workspace) then
				return
			end
			label(shelf, BayConfig.SHELF_COUNTER_NAME, function(part)
				local count = attributeSource(bay, BayConfig.SHELF_COUNT_ATTRIBUTE)
				local function full(): boolean
					return count() >= BayConfig.SHELF_SLOTS
				end
				local glow = shelf:FindFirstChild("Glow")
				Vide.effect(function()
					if glow and glow:IsA("BasePart") then
						glow.Color = if full() then BayLooks.SHELF_FULL_COLOR else BayLooks.SHELF_COLOR
					end
				end)
				return WorldChip({
					adornee = part,
					icon = "Bay",
					iconColor = BayLooks.SHELF_COLOR,
					text = function()
						return Text.get(
							locale,
							"terminal.count.title",
							{ count = count(), max = BayConfig.SHELF_SLOTS }
						)
					end,
					color = function()
						return if full() then BayLooks.SHELF_FULL_COLOR else Theme.NEON.TEXT
					end,
					studsAbove = 0,
					maxDistance = SHELF_COUNT_MAX_DISTANCE,
				}),
					nil
			end)
		end)
	end

	-- A free place of the owner's: "Free place" over it and its ring breathing, while it is free.
	local function watchPlace(instance: Instance)
		if not inOwnBay(instance) then
			return
		end
		label(instance, "Pad", function(part)
			local empty = Vide.source(instance:GetAttribute(BayConfig.PLACE_EMPTY_ATTRIBUTE) == true)
			local connection = instance:GetAttributeChangedSignal(BayConfig.PLACE_EMPTY_ATTRIBUTE):Connect(function()
				empty(instance:GetAttribute(BayConfig.PLACE_EMPTY_ATTRIBUTE) == true)
			end)
			local ring = instance:FindFirstChild("Ring")
			local tween = if ring and ring:IsA("BasePart")
				then TweenService:Create(
					ring,
					TweenInfo.new(FREE_RING_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Transparency = FREE_RING_FADE }
				)
				else nil
			Vide.effect(function()
				if not tween then
					return
				end
				if empty() then
					tween:Play()
				else
					tween:Cancel();
					(ring :: BasePart).Transparency = 0
				end
			end)
			Vide.cleanup(function()
				connection:Disconnect()
				if tween then
					tween:Cancel()
				end
			end)
			local chip = WorldChip({
				adornee = part,
				text = Text.get(locale, "place.free.hint"),
				color = BayLooks.PLACES_COLOR,
				studsAbove = FREE_PLACE_STUDS_ABOVE,
				maxDistance = FREE_PLACE_MAX_DISTANCE,
			})
			Vide.effect(function()
				chip.Enabled = empty()
			end)
			return chip, nil
		end)
	end

	local function watchBay(instance: Instance)
		label(instance, BayConfig.SIGN_NAME, function(part)
			local owner = instance:GetAttribute(BayConfig.OWNER_NAME_ATTRIBUTE)
			return ownerBoard(part, Text.get(locale, "bay.owner.title", { name = tostring(owner or "?") })), nil
		end)
		watchShelf(instance)
		watchPlacesTerminal(instance)
		watchIncubatorTerminal(instance)
		watchTrainerTerminal(instance)
	end

	local function watchAlien(instance: Instance)
		local alienId = instance:GetAttribute(BayConfig.ALIEN_ID_ATTRIBUTE)
		local title = if type(alienId) == "string" then Names.alien(locale, alienId) else nil
		if not title or type(alienId) ~= "string" then
			warn(`[BayViewController] {instance:GetFullName()} has no known alien; no label`)
			return
		end
		local alien = AlienConfig.ALIENS[alienId]
		local income = BigNum.format(alien.income)
		local onShelf = instance:GetAttribute(BayConfig.ALIEN_PLAIN_ATTRIBUTE) == true
		-- A short chip: the tier's colour and the income; the full name is in the bay window.
		label(instance, "Body", function(part)
			return WorldChip({
				adornee = part,
				dot = AlienLooks.TIERS[alien.tier].color,
				text = Text.get(locale, "alien.income.hint", { income = income }),
				-- Over the head: aliens grow with every guardian (decision 068).
				studsAbove = part.Size.Y / 2 + (if onShelf then SHELF_CHIP_STUDS_ABOVE else ALIEN_STUDS_ABOVE),
				maxDistance = if onShelf
					then SHELF_CHIP_MAX_DISTANCE
					else CONTENTS_MAX_DISTANCE + part.Size.Y * CONTENTS_DISTANCE_PER_HEIGHT,
			}),
				nil
		end)
	end

	-- Every egg warming in a slot shows its own countdown, then that it is ready to hatch (in the
	-- owner's bay: or that the shelf is full and it cannot, decision 110); an egg in the queue
	-- says it waits.
	local function watchIncubatorEgg(instance: Instance)
		local own = inOwnBay(instance)
		label(instance, nil, function(part)
			local remaining = Vide.source("")
			local stuck = Vide.source(false)
			local function tick()
				local hatchAt = part:GetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE)
				local left = if type(hatchAt) == "number" then hatchAt - workspace:GetServerTimeNow() else 0
				local blocked = left <= 0 and own and ownBayFull()
				stuck(blocked)
				remaining(
					if left > 0
						then Duration.clock(left)
						elseif blocked then Text.get(locale, "egg.shelfFull.hint")
						else Text.get(locale, "egg.ready.hint")
				)
			end
			tick()
			local color = eggColor(part)
			return WorldChip({
				adornee = part,
				icon = EggIcon.ofPart(part),
				iconColor = color,
				text = remaining,
				color = function()
					return if stuck() then BayLooks.SHELF_FULL_COLOR else color
				end,
				studsAbove = Incubator.chipAbove(
					part.Size.Y,
					IncubatorShape,
					BayLooks.EGG_CHIP_OVER_POD,
					BayLooks.EGG_CHIP_OVER_EGG
				),
				maxDistance = CONTENTS_MAX_DISTANCE,
			}),
				tick
		end)
	end

	local function watchWaitingEgg(instance: Instance)
		label(instance, nil, function(part)
			return WorldChip({
				adornee = part,
				icon = EggIcon.ofPart(part),
				iconColor = eggColor(part),
				text = Text.get(locale, "egg.waiting.hint"),
				color = Theme.NEON.MUTED,
				studsAbove = part.Size.Y / 2 + EGG_STUDS_ABOVE_TOP,
				maxDistance = CONTENTS_MAX_DISTANCE,
			}),
				nil
		end)
	end

	local function observe(tag: string, watch: (Instance) -> ())
		for _, instance in CollectionService:GetTagged(tag) do
			watch(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	end

	local function start()
		locale = Text.localeOf(Players.LocalPlayer)
		playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		observe(BayConfig.TAG, watchBay)
		observe(BayConfig.ALIEN_TAG, watchAlien)
		observe(BayConfig.INCUBATOR_EGG_TAG, watchIncubatorEgg)
		observe(BayConfig.WAITING_EGG_TAG, watchWaitingEgg)
		observe(BayConfig.PLACE_TAG, watchPlace)

		local sinceCountdown = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			sinceCountdown += deltaTime
			if sinceCountdown < COUNTDOWN_INTERVAL then
				return
			end
			sinceCountdown = 0
			for _, view in views do
				if view.countdown then
					view.countdown()
				end
			end
		end)
	end

	return {
		name = "BayViewController",
		start = start,
	}
end

return table.freeze(BayViewController)
