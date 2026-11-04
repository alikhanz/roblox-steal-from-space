--!strict
-- `lune run balance [days]`: when does a player first beat each guardian, and what does their
-- bay look like along the way? Simulates a day-by-day player for three spending profiles,
-- driven by the real configs and domain code. Numbers that are not configs (how a player
-- spends their time) are the ASSUMPTIONS below. Run it after touching any economy config.

local process = require("@lune/process")

local AlienConfig = require("../src/shared/Config/AlienConfig")
local AlienIndex = require("../src/shared/Domain/AlienIndex")
local Bay = require("../src/shared/Domain/Bay")
local BayConfig = require("../src/shared/Config/BayConfig")
local BigNum = require("../src/shared/Domain/BigNum")
local EggConfig = require("../src/shared/Config/EggConfig")
local EventConfig = require("../src/shared/Config/EventConfig")
local GuardianConfig = require("../src/shared/Config/GuardianConfig")
local Hatch = require("../src/shared/Domain/Hatch")
local IndexConfig = require("../src/shared/Config/IndexConfig")
local LoginGiftConfig = require("../src/shared/Config/LoginGiftConfig")
local Loot = require("../src/shared/Domain/Loot")
local PlayReward = require("../src/shared/Domain/PlayReward")
local PlayerData = require("../src/shared/Domain/PlayerData")
local QuestConfig = require("../src/shared/Config/QuestConfig")
local SpeedConfig = require("../src/shared/Config/SpeedConfig")
local StormConfig = require("../src/shared/Config/StormConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")
local Upgrades = require("../src/shared/Domain/Upgrades")
local ZoneConfig = require("../src/shared/Config/ZoneConfig")

local ASSUMPTIONS = {
	-- Guardians in the whole game (AlienConfig has a grade for each).
	guardianCount = ZoneConfig.POST_COUNT,
	days = tonumber(process.args[1]) or 60,
	stepSeconds = 10,
	-- One online session a day, half of it on the trainer, the rest stealing.
	sessionHours = 2,
	trainShare = 0.5,
	-- One theft loop at the nearest guardian, plus this much per post farther out.
	theftBaseSeconds = 40,
	theftPerPostSeconds = 5,
	-- The thief gets away at this share of the recommended speed: the head start covers the rest.
	escapeRatio = 0.9,
	-- The training gamepass and the big Robux package (a day's worth of trainer rate).
	trainingPass = 2,
	packageHours = 8,
	-- Random runs averaged per profile.
	runs = 3,
}

type Profile = {
	name: string,
	pass: number,
	packageHours: number,
	-- Takes every reward that comes with playing every day: the login gift at the start of each
	-- session, all of the day's quests at its end, the index as aliens are found.
	daily: boolean,
}

local PROFILES: { Profile } = {
	{ name = "free", pass = 1, packageHours = 0, daily = false },
	{ name = "free + daily", pass = 1, packageHours = 0, daily = true },
	{ name = "pass x2", pass = ASSUMPTIONS.trainingPass, packageHours = 0, daily = false },
	{
		name = "pass + pack",
		pass = ASSUMPTIONS.trainingPass,
		packageHours = ASSUMPTIONS.packageHours,
		daily = false,
	},
}

local DAY_SECONDS = 24 * 60 * 60
local SNAPSHOT_DAYS = { 1, 7, 30, ASSUMPTIONS.days }

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = SpeedConfig.STARTING_SPEED,
	startingPods = BayConfig.STARTING_PODS,
}

-- The solar storm: quiet for its gap, then the storm (EventConfig), round and round.
local STORM = EventConfig.EVENTS.Storm
local STORM_CYCLE = STORM.schedule.gapMin + STORM.schedule.activeSeconds

-- The day's quests are worth this many minutes on average: the pool's mean reward by weight,
-- times the quests a day.
local QUEST_MINUTES_A_DAY = (function(): number
	local weighted, weights = 0, 0
	for _, definition in QuestConfig.DEFINITIONS do
		weighted += definition.rewardMinutes * definition.weight
		weights += definition.weight
	end
	return weighted / weights * QuestConfig.COUNT
end)()

local function toNumber(value: BigNum.BigNum): number
	return BigNum.toNumber(value)
end

-- The speed recommended over guardian k (the config's formula works past the configured posts).
local function recommendedFor(post: number): number
	return toNumber(GuardianConfig.recommendedFor(post))
end

-- Aliens come only from the one registry, AlienConfig: no made-up ones, so the calculator can
-- never count an alien the game does not have.
local function alienIdFor(grade: number, tier: AlienConfig.TierId): string
	local configured = assert(AlienConfig.GRADES[grade], `no grade {grade} in AlienConfig`)
	return configured.aliens[tier]
end
local function incomeOf(id: string): BigNum.BigNum
	return assert(AlienConfig.ALIENS[id], `unknown alien {id}`).income
end

type Snapshot = {
	speed: number,
	income: number,
	pods: number,
	trainerLevel: number,
	jetpackLevel: number,
	bestPost: number,
}

type Run = {
	firstBeat: { [number]: number },
	snapshots: { [number]: Snapshot },
}

local function simulate(profile: Profile, seed: number): Run
	math.randomseed(seed)
	local data = PlayerData.template(DEFAULTS)
	local coins = 0
	local trained = toNumber(DEFAULTS.startingSpeed)
	local trainerLevel = 0
	local jetpackLevel = 0
	local incomeRate = 0
	local bestPost = 0
	local nextTheftAt = 0
	local run: Run = { firstBeat = {}, snapshots = {} }

	local function speed(): number
		return trained * toNumber(Upgrades.jetpackMultiplier(jetpackLevel, UpgradeConfig.TUNING))
	end
	local function trainRate(): number
		return toNumber(Upgrades.trainerRate(trainerLevel, UpgradeConfig.TUNING)) * profile.pass
	end
	local function canBeat(post: number): boolean
		return speed() >= recommendedFor(post) * ASSUMPTIONS.escapeRatio
	end
	local function refreshIncome()
		incomeRate = toNumber(Bay.incomePerSecond(data, incomeOf))
	end
	-- Aliens with no room are sold on the spot.
	local function sellFloor()
		for _, alien in data.floor do
			coins += toNumber(incomeOf(alien.id)) * BayConfig.SELL_INCOME_SECONDS
		end
		table.clear(data.floor)
	end

	-- A reward worth `minutes` of play (Domain/PlayReward, as the game pays it): coins at the
	-- income, and speed points at the trainer rate when `withSpeed`.
	local function payPlay(minutes: number, minimumCoins: BigNum.BigNum, withSpeed: boolean)
		local rate = if withSpeed then Upgrades.trainerRate(trainerLevel, UpgradeConfig.TUNING) else BigNum.ZERO
		local paidCoins, paidTrained = PlayReward.worth(minutes, BigNum.fromNumber(incomeRate), rate, minimumCoins)
		coins += toNumber(paidCoins)
		trained += toNumber(paidTrained)
	end

	-- An egg into the incubator, hatching after its rarity's time, as the game does it.
	local function incubate(rarity: EggConfig.RarityId, size: EggConfig.SizeId, grade: number, now: number)
		local hatchAt = now + Hatch.duration(EggConfig.RARITIES[rarity].hatchSeconds, math.random())
		Bay.addEgg(data, rarity, size, grade, hatchAt)
	end

	local function steal(post: number, now: number)
		local zone = ZoneConfig.ZONES[ZoneConfig.zoneOfPost(post)]
		incubate(Loot.pick(zone.rarityLoot, math.random()), Loot.pick(zone.sizeLoot, math.random()), post, now)
	end

	-- The index: a new alien's reward and, once its guardian's set is full, the set's, taken at
	-- once.
	local function collect(alienId: string, grade: number)
		if not AlienIndex.discover(data.index, alienId) then
			return
		end
		AlienIndex.claim(data.index, alienId)
		payPlay(IndexConfig.REWARD_MINUTES[AlienConfig.ALIENS[alienId].tier], IndexConfig.MIN_REWARD_COINS, false)
		if AlienIndex.claimSet(data.index, grade, IndexConfig.SETS[grade].aliens) == nil then
			payPlay(IndexConfig.SET_REWARD_MINUTES, IndexConfig.MIN_REWARD_COINS, false)
		end
	end

	local function hatch(now: number)
		local hatched = Bay.takeHatched(data, now)
		if #hatched == 0 then
			return
		end
		for _, egg in hatched do
			local luck = EggConfig.RARITIES[egg.rarity :: EggConfig.RarityId].luck
				+ EggConfig.SIZES[egg.size :: EggConfig.SizeId].luck
			local tier = Hatch.pick(AlienConfig.HATCH_ENTRIES, luck, math.random())
			local alienId = alienIdFor(egg.grade, tier)
			Bay.addHatched(data, { uid = Bay.newUid(data), id = alienId })
			if profile.daily then
				collect(alienId, egg.grade)
			end
		end
		Bay.autoPlace(data, incomeOf, BayConfig.INVENTORY_SLOTS)
		sellFloor()
		refreshIncome()
	end

	local function podPrice(): number
		local bought = #data.pods - BayConfig.STARTING_PODS
		return toNumber(BayConfig.POD_PRICE_BASE) * toNumber(BayConfig.POD_PRICE_GROWTH) ^ bought
	end
	local function trainerPrice(): number
		return toNumber(Upgrades.trainerPrice(trainerLevel, UpgradeConfig.TUNING))
	end
	local function jetpackPrice(): number
		return toNumber(Upgrades.jetpackPrice(jetpackLevel, UpgradeConfig.TUNING))
	end

	-- A pod whenever an alien waits for one; otherwise whichever upgrade gives more speed per coin.
	local function buy()
		while true do
			if #data.pods < BayConfig.MAX_PODS and #data.inventory > 0 and coins >= podPrice() then
				coins -= podPrice()
				table.insert(data.pods, {})
				Bay.autoPlace(data, incomeOf, BayConfig.INVENTORY_SLOTS)
				refreshIncome()
				continue
			end
			local trainerGain = (toNumber(UpgradeConfig.TUNING.trainerRateGrowth) - 1) / trainerPrice()
			local jetpackGain = (toNumber(UpgradeConfig.TUNING.jetpackMultiplier) - 1) / jetpackPrice()
			if trainerGain >= jetpackGain and coins >= trainerPrice() then
				coins -= trainerPrice()
				trainerLevel += 1
			elseif coins >= jetpackPrice() then
				coins -= jetpackPrice()
				jetpackLevel += 1
			else
				return
			end
		end
	end

	local dt = ASSUMPTIONS.stepSeconds
	local sessionSeconds = ASSUMPTIONS.sessionHours * 60 * 60
	local now = 0
	local endAt = ASSUMPTIONS.days * DAY_SECONDS
	while now < endAt do
		local inDay = now % DAY_SECONDS
		if inDay == 0 and profile.packageHours > 0 then
			trained += trainRate() * profile.packageHours * 60 * 60
		end
		if inDay < sessionSeconds then
			trained += trainRate() * ASSUMPTIONS.trainShare * dt
			coins += incomeRate * dt
			-- The solar storm comes round while the player is on, for everyone on the server.
			if inDay % STORM_CYCLE >= STORM_CYCLE - STORM.schedule.activeSeconds then
				Bay.advanceIncubator(data, dt * (StormConfig.HATCH_RATE - 1))
			end
			-- The login gift, taken first thing each day: the streak never breaks here.
			if profile.daily and inDay == 0 then
				local giftDay = (now // DAY_SECONDS) % LoginGiftConfig.LENGTH + 1
				payPlay(LoginGiftConfig.MINUTES[giftDay], LoginGiftConfig.MIN_REWARD_COINS, true)
				if giftDay == LoginGiftConfig.EGG_DAY then
					incubate(LoginGiftConfig.EGG_RARITY, LoginGiftConfig.EGG_SIZE, math.max(bestPost, 1), now)
				end
			end
			-- The day's quests, claimed at the end of the session with the same formula as the game.
			if profile.daily and inDay == sessionSeconds - dt then
				payPlay(QUEST_MINUTES_A_DAY, QuestConfig.MIN_REWARD_COINS, true)
			end
			if now >= nextTheftAt then
				local target = bestPost
				if bestPost < ASSUMPTIONS.guardianCount and canBeat(bestPost + 1) then
					target = bestPost + 1
					bestPost = target
					run.firstBeat[target] = now
				end
				if target > 0 then
					steal(target, now)
					local loop = ASSUMPTIONS.theftBaseSeconds + ASSUMPTIONS.theftPerPostSeconds * (target - 1)
					nextTheftAt = now + loop / (1 - ASSUMPTIONS.trainShare)
				end
			end
		else
			local away = inDay - sessionSeconds
			if away < UpgradeConfig.OFFLINE_TRAINING_CAP_SECONDS then
				trained += trainRate() * UpgradeConfig.OFFLINE_TRAINING_FACTOR * dt
			end
			if away < BayConfig.OFFLINE_INCOME_CAP_SECONDS then
				coins += incomeRate * dt
			end
		end
		hatch(now)
		buy()
		now += dt

		local day = now / DAY_SECONDS
		if day == math.floor(day) and table.find(SNAPSHOT_DAYS, day) then
			run.snapshots[day] = {
				speed = speed(),
				income = incomeRate,
				pods = #data.pods,
				trainerLevel = trainerLevel,
				jetpackLevel = jetpackLevel,
				bestPost = bestPost,
			}
		end
	end
	return run
end

local function formatTime(seconds: number?): string
	if not seconds then
		return "-"
	elseif seconds == 0 then
		return "now"
	elseif seconds < 60 * 60 then
		return string.format("%dm", math.ceil(seconds / 60))
	elseif seconds < DAY_SECONDS then
		return string.format("%.1fh", seconds / 3600)
	end
	return string.format("%.1fd", seconds / DAY_SECONDS)
end

local function formatNumber(value: number): string
	return BigNum.format(BigNum.fromNumber(value))
end

local function pad(text: string, width: number): string
	return text .. string.rep(" ", math.max(0, width - #text))
end

-- Average first-beat time over the runs; nil when any run never got there.
local function averageFirstBeat(runs: { Run }, post: number): number?
	local total = 0
	for _, run in runs do
		local at = run.firstBeat[post]
		if not at then
			return nil
		end
		total += at
	end
	return total / #runs
end

print("Balance: first beat of each guardian (average of", ASSUMPTIONS.runs, "runs)")
print(
	`Assumptions: {ASSUMPTIONS.sessionHours}h online a day, {ASSUMPTIONS.trainShare * 100}% of it training, `
		.. `theft loop {ASSUMPTIONS.theftBaseSeconds}s + {ASSUMPTIONS.theftPerPostSeconds}s per post, `
		.. `escape at {ASSUMPTIONS.escapeRatio} of the recommended speed, pack = {ASSUMPTIONS.packageHours}h of training`
		.. `, daily = quests ({string.format("%.0f", QUEST_MINUTES_A_DAY)} min a day), the login gift and the index; a solar storm every {STORM_CYCLE}s for all`
)
print("")

local runsByProfile: { [string]: { Run } } = {}
for _, profile in PROFILES do
	local runs = {}
	for seed = 1, ASSUMPTIONS.runs do
		table.insert(runs, simulate(profile, seed))
	end
	runsByProfile[profile.name] = runs
end

local POST_WIDTH, SPEED_WIDTH, COLUMN_WIDTH = 5, 10, 15
local header = pad("post", POST_WIDTH) .. pad("recomm.", SPEED_WIDTH)
for _, profile in PROFILES do
	header ..= pad(profile.name, COLUMN_WIDTH)
end
print(header)
for post = 1, ASSUMPTIONS.guardianCount do
	local line = pad(tostring(post), POST_WIDTH) .. pad(formatNumber(recommendedFor(post)), SPEED_WIDTH)
	for _, profile in PROFILES do
		line ..= pad(formatTime(averageFirstBeat(runsByProfile[profile.name], post)), COLUMN_WIDTH)
	end
	print(line)
end

print("")
print("Snapshots (first run): day, speed, income/s, pods, trainer level, jetpack level, best post")
for _, profile in PROFILES do
	print(profile.name)
	local run = runsByProfile[profile.name][1]
	for _, day in SNAPSHOT_DAYS do
		local snapshot = run.snapshots[day]
		if snapshot then
			local levels = `trainer {snapshot.trainerLevel} jetpack {snapshot.jetpackLevel}`
			print(
				`  day {pad(tostring(day), 3)} speed {pad(formatNumber(snapshot.speed), 8)} `
					.. `income {pad(formatNumber(snapshot.income), 8)} pods {pad(tostring(snapshot.pods), 3)} `
					.. `{pad(levels, 22)} post {snapshot.bestPost}`
			)
		end
	end
end
