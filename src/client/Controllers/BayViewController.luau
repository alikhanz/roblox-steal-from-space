--!strict
-- The client side of bays: the owner's name on the sign, a label over every alien (what it is
-- and what it earns) and a countdown over every incubator egg. Everything is keyed by the
-- instance and torn down when it goes, since bays stream and are rebuilt by the server.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local PART_WAIT_TIMEOUT = 10
local SIGN_STUDS_ABOVE = 1.2
local ALIEN_STUDS_ABOVE = 2
local EGG_STUDS_ABOVE = 1.6
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

local function alienTitle(locale: Text.Locale, alienId: string): string?
	local alien = AlienConfig.ALIENS[alienId]
	local post = alien and GuardianConfig.DEBRIS_BELT_POSTS[alien.grade]
	if not alien or not post then
		return nil
	end
	local tier = Text.get(locale, AlienConfig.TIERS[alien.tier].nameKey)
	local guardian = Text.get(locale, GuardianConfig.KINDS[post.kind].nameKey)
	return `{tier} · {guardian}`
end

function BayViewController.new(): BayViewController
	local views: { [Instance]: View } = {}
	local locale: Text.Locale = "en"

	local function remove(instance: Instance)
		local view = views[instance]
		if view then
			views[instance] = nil
			view.unmount()
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
	end

	local function watchAlien(instance: Instance)
		local alienId = instance:GetAttribute(BayConfig.ALIEN_ID_ATTRIBUTE)
		local title = if type(alienId) == "string" then alienTitle(locale, alienId) else nil
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

	local function watchEgg(instance: Instance)
		local rarity =
			EggConfig.RARITIES[instance:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE) :: EggConfig.RarityId]
		local hatchAt = instance:GetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE)
		if not rarity or type(hatchAt) ~= "number" then
			warn(`[BayViewController] {instance:GetFullName()} is not a complete egg; no label`)
			return
		end
		label(instance, nil, function(part)
			local value = Vide.source("")
			local function tick()
				local left = hatchAt - workspace:GetServerTimeNow()
				value(
					if left > 0
						then Text.get(locale, "egg.hatchIn.hint", { time = Duration.describe(locale, left) })
						else Text.get(locale, "egg.hatching.hint")
				)
			end
			tick()
			return WorldLabel({
				adornee = part,
				title = Text.get(locale, rarity.nameKey),
				value = value,
				studsAbove = EGG_STUDS_ABOVE,
				maxDistance = CONTENTS_MAX_DISTANCE,
			}),
				tick
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
		observe(BayConfig.INCUBATOR_EGG_TAG, watchEgg)

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
