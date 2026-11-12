--!strict
-- The hints after the tutorial (decision 110, docs/design/screens/aliens-and-hints.md): once a
-- second works out the player's facts, which tip is wanted (Domain/Coach) and whether it may show
-- yet (the pace), and tells the net service when the tip on screen changes. A tip is done for good
-- by the player's state (a pod or a jetpack bought) or by an action the other services report (a
-- quest claimed, a crossbreed, a sale); done tips are kept in the profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Coach = require(ReplicatedStorage.Shared.Domain.Coach)
local Crossbreed = require(ReplicatedStorage.Shared.Domain.Crossbreed)
local EconomyService = require(script.Parent.EconomyService)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Tutorial = require(ReplicatedStorage.Shared.Domain.Tutorial)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)

-- How often the facts are looked at.
local CHECK_SECONDS = 1
-- A new tip shows no sooner than this after the last one went away (and after the tutorial's
-- farewell line): hints never follow each other in a rush.
local PAUSE_SECONDS = 40

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	isCarrying: (player: Player) -> boolean,
	-- Tutorial progress reached (TutorialService.advanced): its end starts the pause.
	tutorialAdvanced: Signal.Signal<Player, number>,
	coinsTraded: Signal.Signal<Player, EconomyService.CoinTrade, BigNum.BigNum, BigNum.BigNum>,
	crossbred: Signal.Signal<Player, string, Bay.Location>,
	-- A daily quest's reward was taken (QuestService.rewarded).
	questClaimed: Signal.Signal<Player, PlayReward.Paid>,
}

export type CoachService = {
	name: string,
	start: () -> (),
	-- The tip on screen changed (nil: none).
	changed: Signal.Signal<Player, Coach.Tip?>,
	-- A tip appeared (analytics: each time it shows), and a tip was done for good.
	shown: Signal.Signal<Player, Coach.Tip>,
	done: Signal.Signal<Player, Coach.Tip>,
	-- The tip on screen now, or nil.
	getTip: (player: Player) -> Coach.Tip?,
	-- Studio command: the mask of done tips (0: all of them again).
	setDone: (player: Player, mask: number) -> boolean,
}

local CoachService = {}

local function incomeNumber(alienId: string): number
	local alien = AlienConfig.ALIENS[alienId]
	return if alien then BigNum.toNumber(alien.income) else 0
end

local function parentOf(alienId: string): Crossbreed.Parent?
	return AlienConfig.ALIENS[alienId]
end

local function questToClaim(quests: Quests.State): boolean
	for _, record in quests.list do
		if not record.claimed and Quests.isComplete(record) then
			return true
		end
	end
	return false
end

function CoachService.new(dependencies: Dependencies): CoachService
	local changed = Signal.new() :: Signal.Signal<Player, Coach.Tip?>
	local shown = Signal.new() :: Signal.Signal<Player, Coach.Tip>
	local done = Signal.new() :: Signal.Signal<Player, Coach.Tip>
	-- Active players and what their screen shows.
	local paces: { [Player]: Coach.Pace } = {}

	local function factsOf(player: Player, data: PlayerData.PlayerData): Coach.Facts
		local top = Upgrades.jetpackMaxLevel(UpgradeConfig.TUNING)
		local canAffordJetpack = data.jetpackLevel < top
			and not BigNum.lessThan(data.coins, Upgrades.jetpackPrice(data.jetpackLevel, UpgradeConfig.TUNING))
		return {
			tutorialDone = data.tutorialStep >= Tutorial.DONE,
			carrying = dependencies.isCarrying(player),
			freePods = Bay.freePods(data),
			boughtPods = math.max(0, #data.pods - BayConfig.STARTING_PODS),
			shelfCount = #data.floor,
			shelfSlots = BayConfig.SHELF_SLOTS,
			jetpackLevel = data.jetpackLevel,
			canAffordJetpack = canAffordJetpack,
			questToClaim = questToClaim(data.quests),
			hasTrio = #Crossbreed.trios(data.floor, parentOf, incomeNumber, BayConfig.CROSSBREED_COUNT) > 0,
		}
	end

	-- Marks `tip` done in the profile; tells the analytics once.
	local function markDone(player: Player, tip: Coach.Tip)
		local data = dependencies.getData(player)
		if not data or Coach.isDone(data.coachDone, tip) then
			return
		end
		local written = dependencies.update(player, function(current)
			current.coachDone = Coach.mark(current.coachDone, tip)
		end)
		if written then
			done.fire(player, tip)
		end
	end

	-- Works out the player's tip now and tells the client when it changed.
	local function check(player: Player)
		local pace = paces[player]
		local data = dependencies.getData(player)
		if not pace or not data then
			return
		end
		local facts = factsOf(player, data)
		local before = data.coachDone
		local after = Coach.doneByState(before, facts)
		if after ~= before then
			for _, tip in Coach.TIPS do
				if Coach.isDone(after, tip) and not Coach.isDone(before, tip) then
					markDone(player, tip)
				end
			end
		end
		-- The tip on screen (or the one an egg carried home hid) keeps its place.
		local candidate = Coach.candidate(after, facts, pace.shown or pace.last)
		local next = Coach.pace(pace, candidate, os.clock(), PAUSE_SECONDS)
		paces[player] = next
		if next.shown ~= pace.shown then
			changed.fire(player, next.shown)
			if next.shown then
				shown.fire(player, next.shown)
			end
		end
	end

	local function setDone(player: Player, mask: number): boolean
		local clamped = math.max(0, math.floor(mask))
		local written = dependencies.update(player, function(data)
			data.coachDone = clamped
		end)
		if written and paces[player] then
			-- Nothing to wait for: the next check shows what is wanted.
			local pace = paces[player]
			paces[player] = Coach.idle()
			if pace.shown then
				changed.fire(player, nil)
			end
			check(player)
		end
		return written
	end

	local function start()
		dependencies.activated.connect(function(player)
			paces[player] = Coach.idle()
			check(player)
		end)
		dependencies.tutorialAdvanced.connect(function(player, progress)
			-- The tutorial has just ended: its farewell line goes first, then the pause.
			if progress >= Tutorial.DONE and paces[player] then
				paces[player] = Coach.restFrom(os.clock())
			end
		end)
		dependencies.coinsTraded.connect(function(player, trade)
			if trade == "Sell" then
				markDone(player, "Sell")
			end
		end)
		dependencies.crossbred.connect(function(player)
			markDone(player, "Crossbreed")
		end)
		dependencies.questClaimed.connect(function(player)
			markDone(player, "Quest")
		end)
		dependencies.scheduler.every(CHECK_SECONDS, function()
			for player in paces do
				if player.Parent == Players then
					check(player)
				end
			end
		end)
		PlayerEvents.observe(function() end, function(player)
			paces[player] = nil
		end)
	end

	return {
		name = "CoachService",
		start = start,
		changed = changed,
		shown = shown,
		done = done,
		getTip = function(player: Player): Coach.Tip?
			local pace = paces[player]
			return if pace then pace.shown else nil
		end,
		setDone = setDone,
	}
end

return table.freeze(CoachService)
