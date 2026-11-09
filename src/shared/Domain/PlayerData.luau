--!strict
-- Saved player data: its shape, defaults, migrations and safe loading.
--
-- To change the shape: bump SCHEMA_VERSION, add MIGRATIONS[old version], update the template
-- and `validate`, and cover the migration with a test on old saved data.

local AlienIndex = require("./AlienIndex")
local BigNum = require("./BigNum")
local LoginGift = require("./LoginGift")
local Migrations = require("./Migrations")
local Quests = require("./Quests")
local Tables = require("../Runtime/Tables")
local Tutorial = require("./Tutorial")

-- An alien the player owns. `uid` is unique within the profile and never reused: it is how
-- commands and the client refer to one alien.
export type AlienRecord = {
	uid: number,
	id: string,
}

-- An egg hatching in the incubator; hatches once server time passes `hatchAt`.
export type EggRecord = {
	uid: number,
	rarity: string,
	size: string,
	grade: number,
	hatchAt: number,
	-- The alien variant it hatches into (AlienConfig.VariantId); nil: the usual one.
	variant: string?,
	-- Luck it was given on top of its rarity's and size's (EggConfig.luckOf); nil: none.
	luck: number?,
}

-- An egg waiting for a slot in the incubator (decision 058): it does not warm, and takes
-- `hatchSeconds` to hatch once in a slot.
export type WaitingEgg = {
	uid: number,
	rarity: string,
	size: string,
	grade: number,
	hatchSeconds: number,
	variant: string?,
	luck: number?,
}

export type Pod = {
	alien: AlienRecord?,
}

export type PlayerData = {
	schemaVersion: number,
	coins: BigNum.BigNum,
	-- Coins earned all time; spending does not lower it. The coin board ranks by it (Domain/Wallet
	-- is the only place that adds coins). Never below `coins`.
	coinsEarned: BigNum.BigNum,
	-- Speed points earned on the trainer. The stat the player sees is this times the jetpack
	-- multiplier (Domain/Upgrades).
	trained: BigNum.BigNum,
	trainerLevel: number,
	jetpackLevel: number,
	-- Pods the player owns, earning when they hold an alien.
	pods: { Pod },
	inventory: { AlienRecord },
	-- Hatched aliens with no pod and no inventory room, waiting on the bay floor.
	floor: { AlienRecord },
	-- Eggs in the incubator's slots, all warming at once (no more of them than slots).
	incubator: { EggRecord },
	-- Slots the incubator has (Domain/Bay, BayConfig).
	incubatorSlots: number,
	-- Eggs that came with every slot taken, first delivered first; the first moves into a slot
	-- as one frees.
	waiting: { WaitingEgg },
	-- Next alien or egg uid.
	nextUid: number,
	-- Unix time the player was last seen; offline progress is paid from here. 0: never.
	lastSeenAt: number,
	-- Seconds spent in the game, all sessions together; the newbie protection runs on it.
	playSeconds: number,
	-- The new player's funnel steps already logged, as a bit mask (Domain/Onboarding).
	onboardingSteps: number,
	-- The highest guardian post an egg was delivered from; 0: none yet (analytics progression).
	bestPost: number,
	-- Tutorial milestones passed (Domain/Tutorial: 0 not started ... Tutorial.DONE).
	tutorialStep: number,
	-- Today's daily quests (Domain/Quests).
	quests: Quests.State,
	-- The login gift streak (Domain/LoginGift).
	loginGift: LoginGift.State,
	-- Every alien the player has ever had, and which rewards are taken (Domain/AlienIndex).
	index: AlienIndex.State,
	-- The last Robux receipts granted (their PurchaseId), so none is granted twice
	-- (Domain/Purchases, CONVENTIONS section 7).
	purchaseIds: { string },
	-- Passes the player owns (Purchases.PassId): a copy for when Roblox's check fails.
	passes: { string },
	-- What the last time away paid, for "Collect x2"; zeros: nothing to collect again.
	pendingDouble: PendingDouble,
}

export type PendingDouble = {
	coins: BigNum.BigNum,
	trained: BigNum.BigNum,
}

-- Starting values that come from configs; the domain never reads configs itself.
export type Defaults = {
	-- Trained speed of a new player (their whole stat, with no jetpack level yet).
	read startingSpeed: BigNum.BigNum,
	read startingPods: number,
	read startingIncubatorSlots: number,
}

export type LoadFailure = "NewerVersion" | "Corrupted"
export type LoadOutcome = { ok: true, data: PlayerData } | { ok: false, reason: LoadFailure, detail: string }

local PlayerData = {}

PlayerData.SCHEMA_VERSION = 16

-- v16: every guardian has three kinds of alien (decision 075) and an alien's id names its kind
-- ("DebrisBelt2.Rare" became "DebrisBelt2.crabDrone.Rare"). An alien from before is its
-- guardian's main kind. Fixed: the main kinds when v16 came, by the id's guardian part.
local MAIN_KINDS_V16: { [string]: string } = {
	DebrisBelt1 = "slimeWarden",
	DebrisBelt2 = "crabDrone",
	DebrisBelt3 = "violetCrab",
	DebrisBelt4 = "acidSlime",
	DebrisBelt5 = "rustyCrab",
	DebrisBelt6 = "slimeKing",
	IceRings1 = "iceWorm",
	IceRings2 = "snowCrab",
	IceRings3 = "frostSlime",
	IceRings4 = "crystalWorm",
	IceRings5 = "iceRay",
	IceRings6 = "wormMother",
	RedNebula1 = "devourerSwarm",
	RedNebula2 = "starRay",
	RedNebula3 = "fireSlime",
	RedNebula4 = "redSwarm",
	RedNebula5 = "lightningRay",
	RedNebula6 = "devourerQueen",
	EventHorizon1 = "shadowWorm",
	EventHorizon2 = "blackRay",
	EventHorizon3 = "voidSwarm",
	EventHorizon4 = "gravityCrab",
	EventHorizon5 = "whaleCalf",
	EventHorizon6 = "spaceWhale",
}

-- A v15 alien id with its guardian's main kind put in; any other id as it was.
local function withMainKind(id: string): string
	local guardian, rest = string.match(id, "^(%a+%d+)%.(.+)$")
	local kind = guardian and MAIN_KINDS_V16[guardian]
	-- A v16 id already names its kind (the step may run twice): its second part is not a tier.
	if not kind or not rest or not string.match(rest, "^%u") then
		return id
	end
	return `{guardian}.{kind}.{rest}`
end

-- MIGRATIONS[N] upgrades version N to N + 1.
PlayerData.MIGRATIONS = {
	-- v1 held only coins; everything v2 adds is filled from the template by reconcile.
	[1] = function(_data: { [string]: any }) end,
	-- v2's `speed` was the whole stat with no jetpack yet, so it is the trained part of v3;
	-- the levels are filled from the template.
	[2] = function(data: { [string]: any })
		data.trained = data.speed
		data.speed = nil
	end,
	-- v4 adds playSeconds, filled from the template. A player from before counts as a newbie
	-- for one more protection period; that is the safer side.
	[3] = function(_data: { [string]: any }) end,
	-- v5 adds onboardingSteps and bestPost (analytics), filled from the template: a player from
	-- before is counted in the funnel and the progression again from where they are.
	[4] = function(_data: { [string]: any }) end,
	-- v6 adds coinsEarned. What a player from before spent is unknown, so the count starts from
	-- the balance they have.
	[5] = function(data: { [string]: any })
		data.coinsEarned = data.coins
	end,
	-- v7 adds quests, filled from the template: the first day's quests come on the next join.
	[6] = function(_data: { [string]: any }) end,
	-- v8 adds loginGift, filled from the template: everyone starts a streak at day 1.
	[7] = function(_data: { [string]: any }) end,
	-- v9 adds the alien index: the aliens a player has now are found, with their rewards taken
	-- (the index pays for new finds, not for the past).
	[8] = function(data: { [string]: any })
		local index = AlienIndex.empty()
		local owned: { string } = {}
		for _, pod in if type(data.pods) == "table" then data.pods else {} do
			if type(pod) == "table" and type(pod.alien) == "table" and type(pod.alien.id) == "string" then
				table.insert(owned, pod.alien.id)
			end
		end
		for _, field in { "inventory", "floor" } do
			for _, alien in if type(data[field]) == "table" then data[field] else {} do
				if type(alien) == "table" and type(alien.id) == "string" then
					table.insert(owned, alien.id)
				end
			end
		end
		AlienIndex.seed(index, owned)
		data.index = index
	end,
	-- v10: aliens come in variants (meteor ones), so index sets are named by id ("3",
	-- "3.Meteor") instead of a bare grade; eggs may carry a variant (none before).
	[9] = function(data: { [string]: any })
		local index = data.index
		if type(index) == "table" and type(index.sets) == "table" then
			local ids = {}
			for _, grade in index.sets do
				table.insert(ids, if type(grade) == "number" then AlienIndex.setId(grade, "Normal") else grade)
			end
			index.sets = ids
		end
	end,
	-- v11: eggs may carry extra luck (delivered during the star serpent's hunt); none before.
	[10] = function(_data: { [string]: any }) end,
	-- v12: jetpacks come in two marks (x2, x3, x4, x6...) up to Infinity x2048 (decision 056).
	-- Level L used to multiply by 2^L: the same multiplier is now level 2L - 1, and nothing
	-- goes past level 21 (x2048). Fixed numbers: this is how v11 and v12 were.
	[11] = function(data: { [string]: any })
		local level = data.jetpackLevel
		if type(level) == "number" and level > 0 then
			data.jetpackLevel = math.min(2 * level - 1, 21)
		end
	end,
	-- v13: the incubator has slots and a queue (decision 058). The game is not live yet, so a
	-- saved incubator is not fitted to the slots: the eggs in it hatch as they are.
	[12] = function(data: { [string]: any })
		data.incubatorSlots = 2
		data.waiting = {}
	end,
	-- v14 adds Robux purchases (decision 061): receipts, passes and the time away to collect
	-- again, all empty, filled from the template.
	[13] = function(_data: { [string]: any }) end,
	-- v15 adds the tutorial (decision 065): a player who has delivered from guardian 2 or farther
	-- has done what it teaches. Fixed number: the stronger guardian when v15 came.
	[14] = function(data: { [string]: any })
		local bestPost = if type(data.bestPost) == "number" then data.bestPost else 0
		data.tutorialStep = Tutorial.fromBestPost(bestPost, 2)
	end,
	-- v16: alien ids name their kind; an alien from before is its guardian's main kind, in the
	-- bay, the inventory, on the floor and in the index.
	[15] = function(data: { [string]: any })
		local function fix(record: any)
			if type(record) == "table" and type(record.id) == "string" then
				record.id = withMainKind(record.id)
			end
		end
		for _, pod in if type(data.pods) == "table" then data.pods else {} do
			if type(pod) == "table" then
				fix(pod.alien)
			end
		end
		for _, field in { "inventory", "floor" } do
			for _, alien in if type(data[field]) == "table" then data[field] else {} do
				fix(alien)
			end
		end
		local index = data.index
		if type(index) == "table" and type(index.found) == "table" then
			local found = {}
			for alienId, taken in index.found do
				found[if type(alienId) == "string" then withMainKind(alienId) else alienId] = taken
			end
			index.found = found
		end
	end,
} :: { [number]: Migrations.Step }

-- Data a brand-new player starts with. Also the template ProfileStore creates profiles from.
function PlayerData.template(defaults: Defaults): PlayerData
	local pods: { Pod } = {}
	for _ = 1, defaults.startingPods do
		table.insert(pods, {})
	end
	return {
		schemaVersion = PlayerData.SCHEMA_VERSION,
		coins = BigNum.ZERO,
		coinsEarned = BigNum.ZERO,
		trained = defaults.startingSpeed,
		trainerLevel = 0,
		jetpackLevel = 0,
		pods = pods,
		inventory = {},
		floor = {},
		incubator = {},
		incubatorSlots = defaults.startingIncubatorSlots,
		waiting = {},
		nextUid = 1,
		lastSeenAt = 0,
		playSeconds = 0,
		onboardingSteps = 0,
		bestPost = 0,
		tutorialStep = Tutorial.NOT_STARTED,
		quests = Quests.empty(),
		loginGift = LoginGift.empty(),
		index = AlienIndex.empty(),
		purchaseIds = {},
		passes = {},
		pendingDouble = { coins = BigNum.ZERO, trained = BigNum.ZERO },
	}
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

type Uids = { [number]: boolean }

local function validateUid(record: { [string]: any }, seen: Uids): string?
	if not isInteger(record.uid) or record.uid < 1 then
		return "uid is invalid"
	end
	if seen[record.uid] then
		return `uid {record.uid} repeats`
	end
	seen[record.uid] = true
	return nil
end

local function validateAlien(record: any, seen: Uids): string?
	if type(record) ~= "table" then
		return "alien is not a table"
	end
	if type(record.id) ~= "string" or record.id == "" then
		return "alien id is invalid"
	end
	return validateUid(record, seen)
end

-- What every egg has, in the incubator or waiting for a slot.
local function validateEggFields(record: any, seen: Uids): string?
	if type(record) ~= "table" then
		return "egg is not a table"
	end
	if type(record.rarity) ~= "string" or type(record.size) ~= "string" then
		return "egg rarity or size is invalid"
	end
	if not isInteger(record.grade) or record.grade < 1 then
		return "egg grade is invalid"
	end
	if record.variant ~= nil and (type(record.variant) ~= "string" or record.variant == "") then
		return "egg variant is invalid"
	end
	if record.luck ~= nil and (not isFinite(record.luck) or record.luck < 0) then
		return "egg luck is invalid"
	end
	return validateUid(record, seen)
end

local function validateEgg(record: any, seen: Uids): string?
	if type(record) == "table" and not isFinite(record.hatchAt) then
		return "egg hatch time is invalid"
	end
	return validateEggFields(record, seen)
end

local function validateWaitingEgg(record: any, seen: Uids): string?
	if type(record) == "table" and (not isFinite(record.hatchSeconds) or record.hatchSeconds < 0) then
		return "waiting egg hatch seconds are invalid"
	end
	return validateEggFields(record, seen)
end

local function validatePod(record: any, seen: Uids): string?
	if type(record) ~= "table" then
		return "pod is not a table"
	end
	if record.alien ~= nil then
		return validateAlien(record.alien, seen)
	end
	return nil
end

-- A proper array (no holes, no other keys) whose every item passes `check`.
local function validateList(list: any, name: string, check: (any, Uids) -> string?, seen: Uids): string?
	if type(list) ~= "table" then
		return `{name} is not a list`
	end
	local count = 0
	for key, record in list do
		if not isInteger(key) or key < 1 or key > #list then
			return `{name} is not a proper list`
		end
		local problem = check(record, seen)
		if problem then
			return `{name}: {problem}`
		end
		count += 1
	end
	if count ~= #list then
		return `{name} is not a proper list`
	end
	return nil
end

local function validateQuest(record: any, _seen: Uids): string?
	if type(record) ~= "table" then
		return "quest is not a table"
	end
	if type(record.kind) ~= "string" or record.kind == "" then
		return "quest kind is invalid"
	end
	if not isInteger(record.target) or record.target < 1 then
		return "quest target is invalid"
	end
	if not isFinite(record.progress) or record.progress < 0 then
		return "quest progress is invalid"
	end
	if type(record.claimed) ~= "boolean" then
		return "quest claimed is invalid"
	end
	if record.zone ~= nil and type(record.zone) ~= "string" then
		return "quest zone is invalid"
	end
	return nil
end

local function validateQuests(quests: any): string?
	if type(quests) ~= "table" then
		return "quests is not a table"
	end
	if not isInteger(quests.day) or quests.day < 0 then
		return "quests day is invalid"
	end
	if type(quests.rerolled) ~= "boolean" then
		return "quests rerolled is invalid"
	end
	-- Quests carry no uids: a set of their own, so they never clash with aliens and eggs.
	return validateList(quests.list, "quests", validateQuest, {})
end

local function validateIndex(index: any): string?
	if type(index) ~= "table" or type(index.found) ~= "table" or type(index.sets) ~= "table" then
		return "index is not a table"
	end
	for alienId, taken in index.found do
		if type(alienId) ~= "string" or type(taken) ~= "boolean" then
			return "index found is invalid"
		end
	end
	local count = 0
	for key, setId in index.sets do
		if not isInteger(key) or key < 1 or key > #index.sets or type(setId) ~= "string" or setId == "" then
			return "index sets is invalid"
		end
		count += 1
	end
	if count ~= #index.sets then
		return "index sets is invalid"
	end
	return nil
end

-- A proper array of non-empty strings.
local function validateStrings(list: any, name: string): string?
	if type(list) ~= "table" then
		return `{name} is not a list`
	end
	local count = 0
	for key, value in list do
		if not isInteger(key) or key < 1 or key > #list or type(value) ~= "string" or value == "" then
			return `{name} is invalid`
		end
		count += 1
	end
	return if count == #list then nil else `{name} is invalid`
end

local function validatePurchases(data: { [string]: any }): string?
	local problem = validateStrings(data.purchaseIds, "purchaseIds") or validateStrings(data.passes, "passes")
	if problem then
		return problem
	end
	local pending = data.pendingDouble
	if type(pending) ~= "table" then
		return "pendingDouble is not a table"
	end
	for _, field in { "coins", "trained" } do
		local value = BigNum.fromSaved(pending[field])
		if not value or BigNum.isNegative(value) then
			return `pendingDouble {field} is invalid`
		end
		pending[field] = value
	end
	return nil
end

-- Checks a migrated, reconciled copy and converts saved values into their runtime form in place.
local function validate(data: { [string]: any }): string?
	for _, field in { "coins", "coinsEarned", "trained" } do
		local value = BigNum.fromSaved(data[field])
		if not value then
			return `{field} is not a valid BigNum`
		end
		data[field] = value
	end
	if BigNum.isNegative(data.coinsEarned) then
		return "coinsEarned is negative"
	end
	-- Every coin held was earned, whatever happened to the counter.
	data.coinsEarned = BigNum.max(data.coinsEarned, data.coins)
	for _, field in { "trainerLevel", "jetpackLevel" } do
		if not isInteger(data[field]) or data[field] < 0 then
			return `{field} is invalid`
		end
	end

	local seen: Uids = {}
	local problem = validateList(data.pods, "pods", validatePod, seen)
		or validateList(data.inventory, "inventory", validateAlien, seen)
		or validateList(data.floor, "floor", validateAlien, seen)
		or validateList(data.incubator, "incubator", validateEgg, seen)
		or validateList(data.waiting, "waiting", validateWaitingEgg, seen)
	if problem then
		return problem
	end
	if not isInteger(data.incubatorSlots) or data.incubatorSlots < 1 then
		return "incubatorSlots is invalid"
	end
	if #data.pods < 1 then
		return "no pods"
	end

	if not isInteger(data.nextUid) or data.nextUid < 1 then
		return "nextUid is invalid"
	end
	-- A uid is never handed out twice, whatever happened to the counter.
	for uid in seen do
		data.nextUid = math.max(data.nextUid, uid + 1)
	end
	if not isFinite(data.lastSeenAt) or data.lastSeenAt < 0 then
		return "lastSeenAt is invalid"
	end
	if not isFinite(data.playSeconds) or data.playSeconds < 0 then
		return "playSeconds is invalid"
	end
	for _, field in { "onboardingSteps", "bestPost" } do
		if not isInteger(data[field]) or data[field] < 0 then
			return `{field} is invalid`
		end
	end
	if not isInteger(data.tutorialStep) or data.tutorialStep < 0 or data.tutorialStep > Tutorial.DONE then
		return "tutorialStep is invalid"
	end
	local questProblem = validateQuests(data.quests)
	if questProblem then
		return questProblem
	end
	local gift = data.loginGift
	if type(gift) ~= "table" then
		return "loginGift is not a table"
	end
	for _, field in { "lastDay", "streak" } do
		if not isInteger(gift[field]) or gift[field] < 0 then
			return `loginGift {field} is invalid`
		end
	end
	local indexProblem = validateIndex(data.index)
	if indexProblem then
		return indexProblem
	end
	return validatePurchases(data)
end

-- Loads saved data without touching it: all work happens on a copy, which is returned on success.
-- On failure the caller must not write the profile, so the stored data stays as it was.
function PlayerData.load(saved: unknown, defaults: Defaults): LoadOutcome
	if type(saved) ~= "table" then
		return { ok = false, reason = "Corrupted", detail = `saved data is a {type(saved)}` }
	end
	local copy = Tables.deepCopy(saved) :: { [string]: any }

	local status, detail = Migrations.run(copy, PlayerData.MIGRATIONS, PlayerData.SCHEMA_VERSION)
	if status == "NewerVersion" then
		return { ok = false, reason = "NewerVersion", detail = detail or "" }
	elseif status ~= "Ok" then
		return { ok = false, reason = "Corrupted", detail = `{status}: {detail}` }
	end

	Tables.reconcile(copy, PlayerData.template(defaults) :: any)
	local problem = validate(copy)
	if problem then
		return { ok = false, reason = "Corrupted", detail = problem }
	end
	return { ok = true, data = copy :: any }
end

return table.freeze(PlayerData)
