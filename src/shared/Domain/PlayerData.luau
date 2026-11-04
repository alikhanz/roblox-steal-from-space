--!strict
-- Saved player data: its shape, defaults, migrations and safe loading.
--
-- To change the shape: bump SCHEMA_VERSION, add MIGRATIONS[old version], update the template
-- and `validate`, and cover the migration with a test on old saved data.

local BigNum = require("./BigNum")
local Migrations = require("./Migrations")
local Tables = require("../Runtime/Tables")

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
	incubator: { EggRecord },
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
}

-- Starting values that come from configs; the domain never reads configs itself.
export type Defaults = {
	-- Trained speed of a new player (their whole stat, with no jetpack level yet).
	read startingSpeed: BigNum.BigNum,
	read startingPods: number,
}

export type LoadFailure = "NewerVersion" | "Corrupted"
export type LoadOutcome = { ok: true, data: PlayerData } | { ok: false, reason: LoadFailure, detail: string }

local PlayerData = {}

PlayerData.SCHEMA_VERSION = 6

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
		nextUid = 1,
		lastSeenAt = 0,
		playSeconds = 0,
		onboardingSteps = 0,
		bestPost = 0,
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

local function validateEgg(record: any, seen: Uids): string?
	if type(record) ~= "table" then
		return "egg is not a table"
	end
	if type(record.rarity) ~= "string" or type(record.size) ~= "string" then
		return "egg rarity or size is invalid"
	end
	if not isInteger(record.grade) or record.grade < 1 then
		return "egg grade is invalid"
	end
	if not isFinite(record.hatchAt) then
		return "egg hatch time is invalid"
	end
	return validateUid(record, seen)
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
	if problem then
		return problem
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
	return nil
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
