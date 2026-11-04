--!strict
-- Daily quests: a few tasks a day, picked from a pool for what the player can do right now,
-- advanced by what they do in the game and claimed for a reward worth some minutes of their
-- own play (coins at their income, speed points at their trainer rate). One quest a day can be
-- swapped for another. Days are UTC. Pure: the pool, the player's situation and the random
-- numbers are passed in.

local BigNum = require("./BigNum")
local Loot = require("./Loot")

export type Kind = "DeliverEggs" | "DeliverFromZone" | "HatchAliens" | "Train" | "Crossbreed" | "KnockEgg"

-- What a quest needs from the player before it may be given.
export type Requirement = "CanCrossbreed" | "CanFight"

-- One quest of the pool.
export type Definition = {
	read kind: Kind,
	read weight: number,
	-- The target is picked between these, both included (Train counts seconds).
	read minTarget: number,
	read maxTarget: number,
	-- The reward: this many minutes of the player's income and trainer rate.
	read rewardMinutes: number,
	read requires: Requirement?,
}

-- A quest the player has today, as saved.
export type Record = {
	kind: string,
	target: number,
	progress: number,
	claimed: boolean,
	-- The zone a DeliverFromZone quest asks for.
	zone: string?,
}

-- The player's quests, as saved.
export type State = {
	-- The UTC day (days since the Unix epoch) the quests are for; 0: none given yet.
	day: number,
	-- The day's one swap is used.
	rerolled: boolean,
	list: { Record },
}

-- What the player can do right now, for picking quests.
export type Context = {
	-- The zone of the farthest guardian the player has beaten (or the first zone).
	zone: string,
	-- Three aliens of one guardian are in the bay.
	canCrossbreed: boolean,
	-- Out of the newbie protection, so PvP is open.
	canFight: boolean,
}

-- Something the player did that may advance a quest.
export type Event =
	{ kind: "Delivered", zone: string }
	| { kind: "Hatched" }
	| { kind: "Trained", seconds: number }
	| { kind: "Crossbred" }
	| { kind: "KnockedEgg" }

export type ClaimRefusal = "NoSuchQuest" | "QuestNotDone" | "QuestClaimed"
export type RerollRefusal = "NoSuchQuest" | "RerollUsed" | "QuestDone" | "NoOtherQuest"

local DAY_SECONDS = 24 * 60 * 60

local Quests = {}

Quests.DAY_SECONDS = DAY_SECONDS

-- The UTC day of a Unix time.
function Quests.dayOf(unixTime: number): number
	return math.floor(unixTime / DAY_SECONDS)
end

-- Seconds until the next UTC day begins.
function Quests.secondsLeftInDay(unixTime: number): number
	return (Quests.dayOf(unixTime) + 1) * DAY_SECONDS - unixTime
end

function Quests.empty(): State
	return { day = 0, rerolled = false, list = {} }
end

function Quests.definition(definitions: { Definition }, kind: string): Definition?
	for _, definition in definitions do
		if definition.kind == kind then
			return definition
		end
	end
	return nil
end

local function isAllowed(definition: Definition, context: Context): boolean
	if definition.requires == "CanCrossbreed" then
		return context.canCrossbreed
	elseif definition.requires == "CanFight" then
		return context.canFight
	end
	return true
end

local function newRecord(definition: Definition, context: Context, random: () -> number): Record
	local span = definition.maxTarget - definition.minTarget + 1
	local target = definition.minTarget + math.min(math.floor(random() * span), span - 1)
	return {
		kind = definition.kind,
		target = target,
		progress = 0,
		claimed = false,
		zone = if definition.kind == "DeliverFromZone" then context.zone else nil,
	}
end

-- The pool entries that may be given now and are not among `taken`.
local function candidates(definitions: { Definition }, context: Context, taken: { string }): { Loot.Entry<Definition> }
	local entries: { Loot.Entry<Definition> } = {}
	for _, definition in definitions do
		if definition.weight > 0 and isAllowed(definition, context) and not table.find(taken, definition.kind) then
			table.insert(entries, { id = definition, weight = definition.weight })
		end
	end
	return entries
end

-- Up to `count` quests of different kinds, picked by weight from those the player can do.
function Quests.roll(definitions: { Definition }, context: Context, count: number, random: () -> number): { Record }
	local list: { Record } = {}
	local taken: { string } = {}
	while #list < count do
		local entries = candidates(definitions, context, taken)
		if #entries == 0 then
			break
		end
		local definition = Loot.pick(entries, random())
		table.insert(list, newRecord(definition, context, random))
		table.insert(taken, definition.kind)
	end
	return list
end

-- Gives a fresh set when `day` is not the state's day. True when it did.
function Quests.ensureDay(
	state: State,
	day: number,
	definitions: { Definition },
	context: Context,
	count: number,
	random: () -> number
): boolean
	if state.day == day then
		return false
	end
	state.day = day
	state.rerolled = false
	state.list = Quests.roll(definitions, context, count, random)
	return true
end

function Quests.isComplete(record: Record): boolean
	return record.progress >= record.target
end

-- Swaps quest `index` for another kind, once a day; a finished quest is not swapped.
function Quests.reroll(
	state: State,
	index: number,
	definitions: { Definition },
	context: Context,
	random: () -> number
): RerollRefusal?
	local record = state.list[index]
	if not record then
		return "NoSuchQuest"
	elseif state.rerolled then
		return "RerollUsed"
	elseif record.claimed or Quests.isComplete(record) then
		return "QuestDone"
	end
	local taken: { string } = {}
	for _, other in state.list do
		table.insert(taken, other.kind)
	end
	local entries = candidates(definitions, context, taken)
	if #entries == 0 then
		return "NoOtherQuest"
	end
	state.list[index] = newRecord(Loot.pick(entries, random()), context, random)
	state.rerolled = true
	return nil
end

local function advances(record: Record, event: Event): number
	if event.kind == "Delivered" then
		if record.kind == "DeliverEggs" then
			return 1
		elseif record.kind == "DeliverFromZone" and record.zone == event.zone then
			return 1
		end
	elseif event.kind == "Hatched" then
		return if record.kind == "HatchAliens" then 1 else 0
	elseif event.kind == "Trained" then
		return if record.kind == "Train" then event.seconds else 0
	elseif event.kind == "Crossbred" then
		return if record.kind == "Crossbreed" then 1 else 0
	elseif event.kind == "KnockedEgg" then
		return if record.kind == "KnockEgg" then 1 else 0
	end
	return 0
end

-- Applies `event` to every quest it counts for. Returns the indices of quests it finished, and
-- whether anything changed at all.
function Quests.advance(state: State, event: Event): ({ number }, boolean)
	local finished: { number } = {}
	local changed = false
	for index, record in state.list do
		if record.claimed or Quests.isComplete(record) then
			continue
		end
		local step = advances(record, event)
		if step > 0 then
			record.progress = math.min(record.progress + step, record.target)
			changed = true
			if Quests.isComplete(record) then
				table.insert(finished, index)
			end
		end
	end
	return finished, changed
end

-- Marks a finished quest as claimed; the caller pays the reward in the same profile update.
function Quests.claim(state: State, index: number): ClaimRefusal?
	local record = state.list[index]
	if not record then
		return "NoSuchQuest"
	elseif record.claimed then
		return "QuestClaimed"
	elseif not Quests.isComplete(record) then
		return "QuestNotDone"
	end
	record.claimed = true
	return nil
end

-- What `minutes` of play are worth now: coins at `incomePerSecond` (never below
-- `minimumCoins`, so a player with no income yet still gets something) and speed points at
-- `trainerRate` per second.
function Quests.reward(
	minutes: number,
	incomePerSecond: BigNum.BigNum,
	trainerRate: BigNum.BigNum,
	minimumCoins: BigNum.BigNum
): (BigNum.BigNum, BigNum.BigNum)
	local seconds = BigNum.fromNumber(minutes * 60)
	local coins = BigNum.max(BigNum.mul(incomePerSecond, seconds), minimumCoins)
	return coins, BigNum.mul(trainerRate, seconds)
end

return table.freeze(Quests)
