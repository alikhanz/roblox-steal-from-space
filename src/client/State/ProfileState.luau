--!strict
-- The client's copy of its own profile, as Vide sources the UI reads. Filled only by the
-- server (a snapshot, then the section that changed); nothing here writes back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

-- The shapes come from the network contract (net/remotes.zap), so client and server can never
-- disagree on them.
export type Alien = Remotes.Alien
export type Pod = Remotes.Pod
export type Egg = Remotes.Egg
export type WaitingEgg = Remotes.WaitingEgg
export type Bay = Remotes.Bay
export type Upgrades = Remotes.Upgrades
export type Notice = Remotes.Notice
export type AbilityKind = Remotes.AbilityKind
export type QuestKind = Remotes.QuestKind
export type Quest = Remotes.Quest
-- Today's quests: the UTC day, whether the day's swap is used, the list.
export type Quests = Remotes.Quests
-- Where the login gift streak stands today: the streak day, whether its gift waits, whether a
-- missed day started the streak over.
export type LoginGift = Remotes.LoginGift
-- The alien index: alien id -> its reward is taken (present: found); grades whose set is taken.
export type Index = Remotes.Index
export type Location = "Pod" | "Inventory" | "Floor"
-- What a taken gift paid (speed as the stat shows it).
export type GiftReward = { day: number, coins: BigNum.BigNum, speed: BigNum.BigNum, egg: boolean }

export type ProfileState = {
	name: string,
	start: () -> (),
	coins: Vide.Source<BigNum.BigNum>,
	bay: Vide.Source<Bay>,
	upgrades: Vide.Source<Upgrades>,
	quests: Vide.Source<Quests>,
	loginGift: Vide.Source<LoginGift>,
	index: Vide.Source<Index>,
	-- True once the first snapshot arrived.
	loaded: Vide.Source<boolean>,
	-- The trainer paid out: speed points gained this tick.
	trained: Signal.Signal<BigNum.BigNum>,
	-- Paid on login for the time away: coins earned, speed gained, the seconds away, the eggs
	-- ready to hatch and the "Collect x2" tier that pays it once more (0: nothing to pay).
	offlineReward: Signal.Signal<BigNum.BigNum, BigNum.BigNum, number, number, number>,
	-- The player hatched an egg: the alien and where it went.
	hatched: Signal.Signal<string, Location>,
	-- Three aliens were crossbred into this one.
	crossbred: Signal.Signal<string, Location>,
	notice: Signal.Signal<Notice>,
	-- An ability resolved: which, did it hit, did an egg come loose.
	abilityResult: Signal.Signal<AbilityKind, boolean, boolean>,
	-- A claimed quest paid out: coins and the speed stat gained.
	questRewarded: Signal.Signal<BigNum.BigNum, BigNum.BigNum>,
	giftRewarded: Signal.Signal<GiftReward>,
	-- An index reward was taken: the coins it paid.
	indexRewarded: Signal.Signal<BigNum.BigNum>,
}

local ProfileState = {}

local function emptyBay(): Bay
	return { pods = {}, inventory = {}, floor = {}, incubator = {}, incubatorSlots = 2, waiting = {} }
end

function ProfileState.new(): ProfileState
	local coins = source(BigNum.ZERO)
	local bay = source(emptyBay())
	local upgrades = source({ trainerLevel = 0, jetpackLevel = 0 } :: Upgrades)
	local quests = source({ day = 0, rerolled = false, list = {} } :: Quests)
	local loginGift = source({ day = 1, available = false, reset = false, locked = true } :: LoginGift)
	local giftRewarded = Signal.new() :: Signal.Signal<GiftReward>
	local index = source({ found = {}, sets = {} } :: Index)
	local indexRewarded = Signal.new() :: Signal.Signal<BigNum.BigNum>
	local loaded = source(false)
	local trained = Signal.new() :: Signal.Signal<BigNum.BigNum>
	local offlineReward = Signal.new() :: Signal.Signal<BigNum.BigNum, BigNum.BigNum, number, number, number>
	local hatched = Signal.new() :: Signal.Signal<string, Location>
	local crossbred = Signal.new() :: Signal.Signal<string, Location>
	local notice = Signal.new() :: Signal.Signal<Notice>
	local abilityResult = Signal.new() :: Signal.Signal<AbilityKind, boolean, boolean>
	local questRewarded = Signal.new() :: Signal.Signal<BigNum.BigNum, BigNum.BigNum>

	local function readCoins(value: { mantissa: number, exponent: number })
		local restored = BigNum.fromSaved(value)
		if restored then
			coins(restored)
		else
			warn("[ProfileState] Coins arrived in an unknown shape; kept the old value")
		end
	end

	local function start()
		Remotes.ProfileSnapshot.SetCallback(function(snapshot)
			readCoins(snapshot.coins)
			bay(snapshot.bay)
			upgrades(snapshot.upgrades)
			quests(snapshot.quests)
			loginGift(snapshot.loginGift)
			index(snapshot.index)
			loaded(true)
		end)
		Remotes.IndexChanged.SetCallback(function(value)
			index(value)
		end)
		Remotes.IndexRewarded.SetCallback(function(value)
			local paid = BigNum.fromSaved(value)
			if paid then
				indexRewarded.fire(paid)
			end
		end)
		Remotes.LoginGiftChanged.SetCallback(function(value)
			loginGift(value)
		end)
		Remotes.LoginGiftRewarded.SetCallback(function(reward)
			local paid = BigNum.fromSaved(reward.coins)
			local gained = BigNum.fromSaved(reward.speed)
			if paid and gained then
				giftRewarded.fire({ day = reward.day, coins = paid, speed = gained, egg = reward.egg })
			end
		end)
		Remotes.QuestsChanged.SetCallback(function(value)
			quests(value)
		end)
		Remotes.QuestRewarded.SetCallback(function(reward)
			local paid = BigNum.fromSaved(reward.coins)
			local gained = BigNum.fromSaved(reward.speed)
			if paid and gained then
				questRewarded.fire(paid, gained)
			end
		end)
		Remotes.CoinsChanged.SetCallback(readCoins)
		Remotes.UpgradesChanged.SetCallback(function(value)
			upgrades(value)
		end)
		Remotes.Trained.SetCallback(function(value)
			local gain = BigNum.fromSaved(value)
			if gain then
				trained.fire(gain)
			end
		end)
		Remotes.BayChanged.SetCallback(function(value)
			bay(value)
		end)
		Remotes.OfflineReward.SetCallback(function(reward)
			local earned = BigNum.fromSaved(reward.coins)
			local gained = BigNum.fromSaved(reward.speed)
			if earned and gained then
				offlineReward.fire(earned, gained, reward.seconds, reward.readyEggs, reward.doubleTier)
			end
		end)
		Remotes.Hatched.SetCallback(function(event)
			hatched.fire(event.alienId, event.location)
		end)
		Remotes.Crossbred.SetCallback(function(event)
			crossbred.fire(event.alienId, event.location)
		end)
		Remotes.NoticeSent.SetCallback(function(value)
			notice.fire(value)
		end)
		Remotes.AbilityResult.SetCallback(function(result)
			abilityResult.fire(result.kind, result.hit, result.droppedEgg)
		end)
		-- The profile may have activated before these callbacks were set.
		Remotes.RequestSnapshot.Fire()
	end

	return {
		name = "ProfileState",
		start = start,
		coins = coins,
		bay = bay,
		upgrades = upgrades,
		quests = quests,
		loginGift = loginGift,
		index = index,
		loaded = loaded,
		trained = trained,
		offlineReward = offlineReward,
		hatched = hatched,
		crossbred = crossbred,
		notice = notice,
		abilityResult = abilityResult,
		questRewarded = questRewarded,
		giftRewarded = giftRewarded,
		indexRewarded = indexRewarded,
	}
end

return table.freeze(ProfileState)
