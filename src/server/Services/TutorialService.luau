--!strict
-- The tutorial (decision 065): moves the player's milestones on from what other services report
-- (an egg delivered, an alien hatched, the speed stat reaching the stronger guardian) and tells
-- the net service the hint to show whenever it changes. Domain/Tutorial decides; this only
-- listens and keeps the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CarryService = require(script.Parent.CarryService)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Tutorial = require(ReplicatedStorage.Shared.Domain.Tutorial)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

-- How often the training step looks at the speed stat (it grows from the trainer, purchases,
-- quests and the jetpack alike).
local SPEED_CHECK_SECONDS = 1

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	getSpeed: (player: Player) -> BigNum.BigNum,
	isCarrying: (player: Player) -> boolean,
	eggGrabbed: Signal.Signal<Player, CarryService.Carried, CarryService.GrabSource>,
	eggDelivered: Signal.Signal<Player, CarryService.Carried>,
	eggLost: Signal.Signal<Player, CarryService.Carried, CarryService.LossReason>,
	hatched: Signal.Signal<Player, string, Bay.Location, number>,
}

export type TutorialService = {
	name: string,
	start: () -> (),
	-- The hint the player should see now changed (sent on activation too).
	changed: Signal.Signal<Player, Tutorial.Hint>,
	-- A milestone was passed: the new progress (the analytics funnel).
	advanced: Signal.Signal<Player, number>,
	-- The hint for `player` now, or nil without a profile.
	getHint: (player: Player) -> Tutorial.Hint?,
	-- Studio command: sets the progress (0 starts over).
	setProgress: (player: Player, progress: number) -> boolean,
}

local TutorialService = {}

function TutorialService.new(dependencies: Dependencies): TutorialService
	local changed = Signal.new() :: Signal.Signal<Player, Tutorial.Hint>
	local advanced = Signal.new() :: Signal.Signal<Player, number>
	-- The last hint sent to each player, so an unchanged one is not sent again.
	local sent: { [Player]: Tutorial.Hint } = {}

	local function getHint(player: Player): Tutorial.Hint?
		local data = dependencies.getData(player)
		if not data then
			return nil
		end
		return Tutorial.hint(data.tutorialStep, dependencies.isCarrying(player))
	end

	local function publish(player: Player)
		local hint = getHint(player)
		if hint and hint ~= sent[player] then
			sent[player] = hint
			changed.fire(player, hint)
		end
	end

	local function speedReached(player: Player): boolean
		return not BigNum.lessThan(dependencies.getSpeed(player), TutorialConfig.TRAINING_TARGET)
	end

	-- Applies `step` to the progress; tells the funnel and the client about the change.
	local function advance(player: Player, step: (progress: number) -> number)
		local data = dependencies.getData(player)
		if not data or data.tutorialStep >= Tutorial.DONE then
			return
		end
		local before = data.tutorialStep
		local after = step(before)
		-- Training done before the hatch (a returning player, a training pack): passed at once.
		if after == Tutorial.HATCHED then
			after = Tutorial.afterSpeed(after, speedReached(player))
		end
		if after ~= before then
			local written = dependencies.update(player, function(current)
				current.tutorialStep = after
			end)
			if written then
				for progress = before + 1, after do
					advanced.fire(player, progress)
				end
			end
		end
		publish(player)
	end

	local function setProgress(player: Player, progress: number): boolean
		local clamped = math.clamp(math.floor(progress), Tutorial.NOT_STARTED, Tutorial.DONE)
		local written = dependencies.update(player, function(data)
			data.tutorialStep = clamped
		end)
		if written then
			sent[player] = nil
			publish(player)
		end
		return written
	end

	local function start()
		dependencies.activated.connect(function(player)
			local data = dependencies.getData(player)
			if data and data.tutorialStep == Tutorial.NOT_STARTED then
				advanced.fire(player, Tutorial.NOT_STARTED)
			end
			publish(player)
		end)
		dependencies.eggGrabbed.connect(function(player)
			publish(player)
		end)
		dependencies.eggLost.connect(function(player)
			publish(player)
		end)
		dependencies.eggDelivered.connect(function(player, egg)
			advance(player, function(progress)
				-- An egg with no guardian (grade nil) counts as the first delivery only.
				return Tutorial.afterDelivery(progress, egg.grade or 0, TutorialConfig.STRONGER_GRADE)
			end)
		end)
		dependencies.hatched.connect(function(player)
			advance(player, Tutorial.afterHatch)
		end)
		dependencies.scheduler.every(SPEED_CHECK_SECONDS, function()
			for player in sent do
				local data = dependencies.getData(player)
				if data and data.tutorialStep == Tutorial.HATCHED and speedReached(player) then
					advance(player, function(progress)
						return Tutorial.afterSpeed(progress, true)
					end)
				end
			end
		end)
		PlayerEvents.observe(function() end, function(player)
			sent[player] = nil
		end)
	end

	return {
		name = "TutorialService",
		start = start,
		changed = changed,
		advanced = advanced,
		getHint = getHint,
		setProgress = setProgress,
	}
end

return table.freeze(TutorialService)
