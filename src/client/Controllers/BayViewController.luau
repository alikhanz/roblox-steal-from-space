--!strict
-- The client side of bays: the owner's name on the sign, a label over every alien (what it is
-- and what it earns), one countdown over the incubator and the trainer's sign. Everything is
-- keyed by the instance and torn down when it goes, since bays stream and are rebuilt by the
-- server.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local PART_WAIT_TIMEOUT = 10
local SIGN_STUDS_ABOVE = 1.2
-- Over the head of whoever stands on the pad.
local TRAINER_STUDS_ABOVE = 5
local ALIEN_STUDS_ABOVE = 2
local INCUBATOR_STUDS_ABOVE = 4
-- The owner's name reads from across the platform; what stands in the bay only up close, or
-- the labels pile up on each other.
local SIGN_MAX_DISTANCE = 120
local CONTENTS_MAX_DISTANCE = 35
-- Countdowns are whole seconds: once a second is enough.
local COUNTDOWN_INTERVAL = 1

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

function BayViewController.new(): BayViewController
	local views: { [Instance]: View } = {}
	local locale: Text.Locale = "en"

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
	local function label(instance: Instance, partName: string?, build: (BasePart) -> (BillboardGui, (() -> ())?))
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
			local unmount = Vide.mount(function()
				local gui, tick = build(part)
				countdown = tick
				return gui
			end, instance)
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
				local level = Vide.source(0)
				local function readLevel()
					local value = instance:GetAttribute(BayConfig.TRAINER_LEVEL_ATTRIBUTE)
					level(if type(value) == "number" then value else 0)
				end
				readLevel()
				local connection =
					instance:GetAttributeChangedSignal(BayConfig.TRAINER_LEVEL_ATTRIBUTE):Connect(readLevel)
				Vide.cleanup(function()
					connection:Disconnect()
				end)
				return WorldLabel({
					adornee = part,
					title = function()
						return Text.get(locale, "trainer.level.hint", { level = level() })
					end,
					value = function()
						local rate = Upgrades.trainerRate(level(), UpgradeConfig.TUNING)
						return Text.get(locale, "trainer.stand.hint", { rate = BigNum.format(rate) })
					end,
					valueColor = Theme.SPEED,
					studsAbove = TRAINER_STUDS_ABOVE,
					maxDistance = CONTENTS_MAX_DISTANCE,
				}),
					nil
			end)
		end)
	end

	local function watchAlien(instance: Instance)
		local alienId = instance:GetAttribute(BayConfig.ALIEN_ID_ATTRIBUTE)
		local title = if type(alienId) == "string" then Names.alien(locale, alienId) else nil
		if not title or type(alienId) ~= "string" then
			warn(`[BayViewController] {instance:GetFullName()} has no known alien; no label`)
			return
		end
		local income = BigNum.format(AlienConfig.ALIENS[alienId].income)
		label(instance, "Body", function(part)
			return WorldLabel({
				adornee = part,
				title = title,
				value = Text.get(locale, "alien.income.hint", { income = income }),
				valueColor = Theme.SPEED,
				studsAbove = ALIEN_STUDS_ABOVE,
				maxDistance = CONTENTS_MAX_DISTANCE,
			}),
				nil
		end)
	end

	-- One sign for the whole incubator (a sign per egg piles up once there are dozens): how
	-- many eggs lie in it and when the next one hatches, from the incubator's attributes.
	function watchIncubator(bay: Instance)
		task.spawn(function()
			local incubator = bay:WaitForChild(BayConfig.INCUBATOR_NAME, PART_WAIT_TIMEOUT)
			if not incubator or not bay:IsDescendantOf(workspace) then
				return
			end
			label(incubator, nil, function(part)
				local count = Vide.source(0)
				local value = Vide.source("")
				local function tick()
					local eggs = incubator:GetAttribute(BayConfig.INCUBATOR_COUNT_ATTRIBUTE)
					local nextHatchAt = incubator:GetAttribute(BayConfig.INCUBATOR_NEXT_HATCH_ATTRIBUTE)
					count(if type(eggs) == "number" then eggs else 0)
					if type(nextHatchAt) ~= "number" or count() == 0 then
						value(Text.get(locale, "bay.incubatorIdle.hint"))
						return
					end
					local left = nextHatchAt - workspace:GetServerTimeNow()
					value(
						if left > 0
							then Text.get(locale, "egg.hatchIn.hint", { time = Duration.describe(locale, left) })
							else Text.get(locale, "egg.hatching.hint")
					)
				end
				tick()
				local connection =
					incubator:GetAttributeChangedSignal(BayConfig.INCUBATOR_COUNT_ATTRIBUTE):Connect(tick)
				Vide.cleanup(function()
					connection:Disconnect()
				end)
				return WorldLabel({
					adornee = part,
					title = function()
						return Text.get(locale, "bay.incubatorSign.title", { count = count() })
					end,
					value = value,
					valueColor = Theme.SPEED,
					studsAbove = INCUBATOR_STUDS_ABOVE,
					maxDistance = CONTENTS_MAX_DISTANCE,
				}),
					tick
			end)
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
		observe(BayConfig.TAG, watchBay)
		observe(BayConfig.ALIEN_TAG, watchAlien)

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
