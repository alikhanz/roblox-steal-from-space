--!strict
-- The client side of bays: the owner's name on the sign, a label over every alien (what it is
-- and what it earns), the incubator's sign with its slots, a countdown over every egg warming
-- (and "waiting" over the queued ones) and the trainer's sign. Everything is
-- keyed by the instance and torn down when it goes, since bays stream and are rebuilt by the
-- server.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Mount = require(script.Parent.Parent.UI.Mount)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WorldChip = require(script.Parent.Parent.UI.WorldChip)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local PART_WAIT_TIMEOUT = 10
local PLAYER_GUI_WAIT_TIMEOUT = 30
local SIGN_STUDS_ABOVE = 1.2
-- Over the head of whoever stands on the pad.
local TRAINER_STUDS_ABOVE = 5
local PODS_SIGN_STUDS_ABOVE = 0.5
local ALIEN_STUDS_ABOVE = 2
local INCUBATOR_STUDS_ABOVE = 4
-- Each egg's countdown, just over it.
local EGG_STUDS_ABOVE = 1.6
-- The owner's name reads from across the platform; the upgrade signs with the camera pulled
-- back; what stands in the bay only up close, or the labels pile up on each other.
local SIGN_MAX_DISTANCE = 120
local UPGRADE_SIGN_MAX_DISTANCE = 80
local CONTENTS_MAX_DISTANCE = 35
-- Countdowns are whole seconds: once a second is enough.
local COUNTDOWN_INTERVAL = 1

export type Dependencies = {
	-- The owner's own data: the buy buttons on their bay's signs need the coins and the pods.
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
		build: (BasePart) -> (BillboardGui, (() -> ())?),
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

	-- Defined below; a bay's sign and its incubator's sign are set up together.
	local watchIncubator: (bay: Instance) -> ()

	local function watchBay(instance: Instance)
		label(instance, BayConfig.SIGN_NAME, function(part)
			local owner = instance:GetAttribute(BayConfig.OWNER_NAME_ATTRIBUTE)
			return WorldLabel({
				adornee = part,
				title = Text.get(locale, "bay.owner.title", { name = tostring(owner or "?") }),
				value = "",
				studsAbove = SIGN_STUDS_ABOVE,
				maxDistance = SIGN_MAX_DISTANCE,
			}),
				nil
		end)

		watchIncubator(instance)

		-- The trainer pad's own sign: the level and the rate, following the bay's attribute.
		task.spawn(function()
			local pad = instance:WaitForChild(BayConfig.TRAINER_NAME, PART_WAIT_TIMEOUT)
			if not pad or not instance:IsDescendantOf(workspace) then
				return
			end
			label(pad, nil, function(part)
				local level = attributeSource(instance, BayConfig.TRAINER_LEVEL_ATTRIBUTE)
				local function price(): BigNum.BigNum
					return Upgrades.trainerPrice(level(), UpgradeConfig.TUNING)
				end
				local own = isOwn(instance)
				-- The rate the stat really grows at: the trainer's speed points with the owner's
				-- passes, times the owner's jetpack (the owner's own copy for them, the owner's
				-- player attributes for others).
				local ownerId = instance:GetAttribute(BayConfig.OWNER_ID_ATTRIBUTE)
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
				return WorldLabel({
					adornee = part,
					title = function()
						return Text.get(locale, "trainer.level.hint", { level = level() })
					end,
					value = function()
						local rate = BigNum.mul(
							Purchases.trainerRate(level(), math.max(passMultiplier(), 1), UpgradeConfig.TUNING),
							Upgrades.jetpackMultiplier(jetpackLevel(), UpgradeConfig.TUNING)
						)
						return Text.get(locale, "trainer.stand.hint", { rate = BigNum.format(rate) })
					end,
					valueColor = Theme.SPEED,
					studsAbove = TRAINER_STUDS_ABOVE,
					maxDistance = UPGRADE_SIGN_MAX_DISTANCE,
					-- The owner buys the next level right here.
					button = if own
						then {
							text = function()
								return Text.get(locale, "trainer.upgrade.button", { price = BigNum.format(price()) })
							end,
							enabled = function()
								return canAfford(price())
							end,
							visible = function()
								return true
							end,
							onClick = function()
								Remotes.UpgradeTrainer.Fire()
							end,
						}
						else nil,
				}),
					nil
			end, isOwn(instance))
		end)

		-- The pods' sign between the rows: how many, and for the owner a button for the next.
		task.spawn(function()
			local anchor = instance:WaitForChild(BayConfig.PODS_SIGN_NAME, PART_WAIT_TIMEOUT)
			if not anchor or not instance:IsDescendantOf(workspace) then
				return
			end
			label(anchor, nil, function(part)
				local count = attributeSource(instance, BayConfig.POD_COUNT_ATTRIBUTE)
				local function price(): BigNum.BigNum
					return Bay.podPrice(
						count(),
						BayConfig.STARTING_PODS,
						BayConfig.POD_PRICE_BASE,
						BayConfig.POD_PRICE_GROWTH
					)
				end
				local function hasRoom(): boolean
					return count() < BayConfig.MAX_PODS
				end
				local own = isOwn(instance)
				return WorldLabel({
					adornee = part,
					title = function()
						return Text.get(locale, "bay.podsSign.title", { count = count(), max = BayConfig.MAX_PODS })
					end,
					value = function()
						return Text.get(locale, if hasRoom() then "bay.podsSign.hint" else "bay.podsFull.hint")
					end,
					studsAbove = PODS_SIGN_STUDS_ABOVE,
					maxDistance = UPGRADE_SIGN_MAX_DISTANCE,
					button = if own
						then {
							text = function()
								return Text.get(locale, "bay.buyPodSign.button", { price = BigNum.format(price()) })
							end,
							enabled = function()
								return hasRoom() and canAfford(price())
							end,
							visible = hasRoom,
							onClick = function()
								Remotes.BuyPod.Fire()
							end,
						}
						else nil,
				}),
					nil
			end, isOwn(instance))
		end)
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
		-- A short chip: the tier's colour and the income; the full name is in the bay window.
		label(instance, "Body", function(part)
			return WorldChip({
				adornee = part,
				dot = AlienLooks.TIERS[alien.tier].color,
				text = Text.get(locale, "alien.income.hint", { income = income }),
				studsAbove = ALIEN_STUDS_ABOVE,
				maxDistance = CONTENTS_MAX_DISTANCE,
			}),
				nil
		end)
	end

	-- The incubator's sign (decision 058): eggs warming of its slots, whether one is free or how
	-- many wait, and for the owner a button for one more slot. The countdowns are over the eggs.
	function watchIncubator(bay: Instance)
		task.spawn(function()
			local incubator = bay:WaitForChild(BayConfig.INCUBATOR_NAME, PART_WAIT_TIMEOUT)
			if not incubator or not bay:IsDescendantOf(workspace) then
				return
			end
			label(incubator, nil, function(part)
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
				local function hasRoom(): boolean
					return slots() < BayConfig.MAX_INCUBATOR_SLOTS
				end
				local own = isOwn(bay)
				return WorldLabel({
					adornee = part,
					title = function()
						return Text.get(locale, "bay.incubatorSlots.title", { count = count(), slots = slots() })
					end,
					value = function()
						if waiting() > 0 then
							return Text.get(locale, "bay.incubatorWaiting.hint", { count = waiting() })
						end
						return Text.get(
							locale,
							if count() < slots() then "bay.incubatorFree.hint" else "bay.incubatorFull.hint"
						)
					end,
					valueColor = Theme.SPEED,
					studsAbove = INCUBATOR_STUDS_ABOVE,
					maxDistance = UPGRADE_SIGN_MAX_DISTANCE,
					button = if own
						then {
							text = function()
								return Text.get(locale, "bay.buySlot.button", { price = BigNum.format(price()) })
							end,
							enabled = function()
								return hasRoom() and canAfford(price())
							end,
							visible = hasRoom,
							onClick = function()
								Remotes.BuyIncubatorSlot.Fire()
							end,
						}
						else nil,
				}),
					nil
			end, isOwn(bay))
		end)
	end

	-- Every egg warming in a slot shows its own countdown, then that it is ready to hatch; an egg
	-- in the queue says it waits.
	local function watchIncubatorEgg(instance: Instance)
		label(instance, nil, function(part)
			local remaining = Vide.source("")
			local function tick()
				local hatchAt = part:GetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE)
				local left = if type(hatchAt) == "number" then hatchAt - workspace:GetServerTimeNow() else 0
				remaining(if left > 0 then Duration.clock(left) else Text.get(locale, "egg.ready.hint"))
			end
			tick()
			local color = eggColor(part)
			return WorldChip({
				adornee = part,
				icon = "Egg",
				iconColor = color,
				text = remaining,
				color = color,
				studsAbove = EGG_STUDS_ABOVE,
				maxDistance = CONTENTS_MAX_DISTANCE,
			}),
				tick
		end)
	end

	local function watchWaitingEgg(instance: Instance)
		label(instance, nil, function(part)
			return WorldChip({
				adornee = part,
				icon = "Egg",
				iconColor = eggColor(part),
				text = Text.get(locale, "egg.waiting.hint"),
				color = Theme.NEON.MUTED,
				studsAbove = EGG_STUDS_ABOVE,
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
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		observe(BayConfig.TAG, watchBay)
		observe(BayConfig.ALIEN_TAG, watchAlien)
		observe(BayConfig.INCUBATOR_EGG_TAG, watchIncubatorEgg)
		observe(BayConfig.WAITING_EGG_TAG, watchWaitingEgg)

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
