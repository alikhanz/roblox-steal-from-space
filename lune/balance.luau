--!strict
-- `lune run balance [days]`: when does a player first beat each guardian, and what does their
-- bay look like along the way? Simulates a day-by-day player for several spending profiles,
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
local MonetizationConfig = require("../src/shared/Config/MonetizationConfig")
local PlayReward = require("../src/shared/Domain/PlayReward")
local PlayerData = require("../src/shared/Domain/PlayerData")
local Purchases = require("../src/shared/Domain/Purchases")
local QuestConfig = require("../src/shared/Config/QuestConfig")
local SerpentConfig = require("../src/shared/Config/SerpentConfig")
local SpeedConfig = require("../src/shared/Config/SpeedConfig")
local StarEgg = require("../src/shared/Domain/StarEgg")
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
	-- The paying profiles: what the passes do comes from MonetizationConfig, as in the game; the
	-- big Robux package is hours of trainer rate a day (MonetizationConfig.TRAINING_PACK_SECONDS).
	packageHours = MonetizationConfig.TRAINING_PACK_SECONDS[2] / (60 * 60),
	-- Meteor eggs a player brings home from a shower: from a crater in the farthest zone they
	-- can handle, at a guardian they can beat (the strip runs through every zone).
	meteorEggsPerShower = 1,
	-- The share of serpent hunts a player wins the star egg in: one egg per server, so with a
	-- few players around a player gets it now and then (upper estimate). Only from a zone past
	-- the first whose middle guardian they beat: that is who catches the serpent there.
	starEggShare = 0.5,
	-- Random runs averaged per profile.
	runs = 3,
	-- Aliens with no pod the model keeps on the shelf for the next pod; it sells the rest at once.
	-- Ten: what the inventory held before decision 106, so the pace stays comparable.
	shelfKept = 10,
}

type Profile = {
	name: string,
	-- The passes owned (Purchases.passEffects turns them into the trainer rate and the caps away).
	-- Plain strings, as in the profile (Purchases.PassId values).
	passes: { string },
	packageHours: number,
	-- Takes every reward that comes with playing every day: the login gift at the start of each
	-- session, all of the day's quests at its end, the index as aliens are found.
	daily: boolean,
}

local PROFILES: { Profile } = {
	{ name = "free", passes = {}, packageHours = 0, daily = false },
	{ name = "free + daily", passes = {}, packageHours = 0, daily = true },
	{ name = "pass x2", passes = { "DoubleTraining" }, packageHours = 0, daily = false },
	{ name = "night shift", passes = { "NightShift" }, packageHours = 0, daily = false },
	{ name = "both passes", passes = { "DoubleTraining", "NightShift" }, packageHours = 0, daily = false },
	{
		name = "passes + pack",
		passes = { "DoubleTraining", "NightShift" },
		packageHours = ASSUMPTIONS.packageHours,
		daily = false,
	},
}

local DAY_SECONDS = 24 * 60 * 60
local SNAPSHOT_DAYS = { 1, 7, 30, ASSUMPTIONS.days }

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = SpeedConfig.STARTING_SPEED,
	startingPods = BayConfig.STARTING_PODS,
	startingIncubatorSlots = BayConfig.STARTING_INCUBATOR_SLOTS,
}

-- The solar storm: quiet for its gap, then the storm (EventConfig), round and round.
local STORM = EventConfig.EVENTS.Storm
local STORM_CYCLE = STORM.schedule.gapMin + STORM.schedule.activeSeconds
-- The meteor shower: its average gap, then on average half a storm cycle waiting for a storm
-- to end (EventConfig `after`), then the shower. A multiple of the step, so it is never missed.
-- The same for every event that waits for a storm.
local function afterStormCycle(event: EventConfig.Event): number
	local schedule = event.schedule
	return math.round(
		((schedule.gapMin + schedule.gapMax) / 2 + STORM_CYCLE / 2 + schedule.activeSeconds) / ASSUMPTIONS.stepSeconds
	) * ASSUMPTIONS.stepSeconds
end
local METEOR_CYCLE = afterStormCycle(EventConfig.EVENTS.Meteor)
-- The star serpent's hunt: its star egg (Domain/StarEgg) for whoever knocks it out and brings
-- it home.
local SERPENT_CYCLE = afterStormCycle(EventConfig.EVENTS.Serpent)

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
-- never count an alien the game does not have. Kinds of a grade earn the same (decision 075), so
-- its main kind stands for all of them.
local function alienIdFor(grade: number, tier: AlienConfig.TierId, variant: AlienConfig.VariantId): string
	local configured = assert(AlienConfig.GRADES[grade], `no grade {grade} in AlienConfig`)
	return configured.variants[variant][configured.kinds[1]][tier]
end
local function incomeOf(id: string): BigNum.BigNum
	return assert(AlienConfig.ALIENS[id], `unknown alien {id}`).income
end

type Snapshot = {
	speed: number,
	income: number,
	pods: number,
	-- Incubator slots and eggs waiting for one.
	slots: number,
	waiting: number,
	trainerLevel: number,
	jetpackLevel: number,
	bestPost: number,
}

type Run = {
	firstBeat: { [number]: number },
	-- When each incubator slot was bought: slot number -> time.
	slotBought: { [number]: number },
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
	local run: Run = { firstBeat = {}, slotBought = {}, snapshots = {} }
	local passEffects = Purchases.passEffects(profile.passes, MonetizationConfig.PASS_TUNING)

	local function speed(): number
		return trained * toNumber(Upgrades.jetpackMultiplier(jetpackLevel, UpgradeConfig.TUNING))
	end
	local function trainRate(): number
		return toNumber(Purchases.trainerRate(trainerLevel, passEffects.trainerMultiplier, UpgradeConfig.TUNING))
	end
	local function canBeat(post: number): boolean
		return speed() >= recommendedFor(post) * ASSUMPTIONS.escapeRatio
	end
	local function refreshIncome()
		incomeRate = toNumber(Bay.incomePerSecond(data, incomeOf))
	end
	-- The model keeps the best few with no pod on the shelf for the next pod it buys, and sells the
	-- rest on the spot (as when the inventory held ten: the numbers stay those of before decision 106).
	local function sellFloor()
		while #data.floor > ASSUMPTIONS.shelfKept do
			local alien = table.remove(data.floor) :: PlayerData.AlienRecord
			coins += toNumber(incomeOf(alien.id)) * BayConfig.SELL_INCOME_SECONDS
		end
	end

	-- A reward worth `minutes` of play (Domain/PlayReward, as the game pays it): coins at the
	-- income, and speed points at the trainer rate when `withSpeed`.
	local function payPlay(minutes: number, minimumCoins: BigNum.BigNum, withSpeed: boolean)
		local rate = if withSpeed then Upgrades.trainerRate(trainerLevel, UpgradeConfig.TUNING) else BigNum.ZERO
		local paidCoins, paidTrained = PlayReward.worth(minutes, BigNum.fromNumber(incomeRate), rate, minimumCoins)
		coins += toNumber(paidCoins)
		trained += toNumber(paidTrained)
	end

	-- Defined below: hatches the ready eggs, done whenever the player is at the bay.
	local hatch: (now: number) -> ()

	-- An egg into the incubator (or its queue), hatching after its rarity's time, as the game
	-- does it. The player brings it home, so the ready eggs are hatched first.
	local function incubate(
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		grade: number,
		now: number,
		variant: AlienConfig.VariantId?,
		luck: number?
	)
		hatch(now)
		local hatchSeconds = Hatch.duration(EggConfig.RARITIES[rarity].hatchSeconds, math.random())
		Bay.addEgg(data, rarity, size, grade, hatchSeconds, now, variant, luck)
	end

	-- An egg of `post`'s zone loot, the usual one or a meteor one, delivered now.
	local function steal(post: number, now: number, variant: AlienConfig.VariantId?)
		local zone = ZoneConfig.ZONES[ZoneConfig.zoneOfPost(post)]
		incubate(Loot.pick(zone.rarityLoot, math.random()), Loot.pick(zone.sizeLoot, math.random()), post, now, variant)
	end

	-- The serpent comes out in a random zone; its star egg is the player's if they beat that
	-- zone's middle guardian (as fast as the serpent): `farthest` is their farthest guardian.
	local function winStarEgg(farthest: number, now: number)
		local zones = SerpentConfig.ZONES
		local zone = zones[math.random(1, #zones)]
		if farthest < ZoneConfig.postIndex(zone, SerpentConfig.POWER_POST) then
			return
		end
		local egg = StarEgg.roll(zone, math.random(), math.random())
		incubate(egg.rarity, egg.size, egg.grade, now, nil, egg.luck)
	end

	-- The index: a new alien's reward and, once its guardian's set is full, the set's, taken at
	-- once.
	local function collect(alienId: string)
		if not AlienIndex.discover(data.index, alienId) then
			return
		end
		local alien = AlienConfig.ALIENS[alienId]
		AlienIndex.claim(data.index, alienId)
		payPlay(IndexConfig.REWARD_MINUTES[alien.tier], IndexConfig.MIN_REWARD_COINS, false)
		local set = IndexConfig.SETS_BY_ID[AlienIndex.setId(alien.grade, alien.variant)]
		if AlienIndex.claimSet(data.index, set) == nil then
			payPlay(IndexConfig.SET_REWARD_MINUTES, IndexConfig.MIN_REWARD_COINS, false)
		end
	end

	-- The player hatches every ready egg when at the bay: on coming online and with each
	-- delivery (the prompt is in the bay only). In between, and while away, ready eggs keep
	-- their slots and the queue waits (decision 059).
	function hatch(now: number)
		local hatched: { PlayerData.EggRecord } = {}
		for _, ready in table.clone(data.incubator) do
			local egg = if Bay.isReady(ready, now) then Bay.hatch(data, ready.uid, now) else nil
			if egg then
				table.insert(hatched, egg)
			end
		end
		if #hatched == 0 then
			return
		end
		for _, egg in hatched do
			local luck = EggConfig.luckOf(egg.rarity :: EggConfig.RarityId, egg.size :: EggConfig.SizeId, egg.luck)
			local tier = Hatch.pick(AlienConfig.HATCH_ENTRIES, luck, math.random())
			local variant = (egg.variant or "Normal") :: AlienConfig.VariantId
			local alienId = alienIdFor(egg.grade, tier, variant)
			Bay.addHatched(data, { uid = Bay.newUid(data), id = alienId })
			if profile.daily then
				collect(alienId)
			end
		end
		Bay.autoPlace(data, incomeOf)
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
	local jetpackTop = Upgrades.jetpackMaxLevel(UpgradeConfig.TUNING)
	-- Nothing to buy past the top jetpack.
	local function jetpackPrice(): number
		return if jetpackLevel < jetpackTop
			then toNumber(Upgrades.jetpackPrice(jetpackLevel, UpgradeConfig.TUNING))
			else math.huge
	end
	-- What the next jetpack level adds, as a share of the stat (0.5 for x2 -> x3).
	local function jetpackStep(): number
		if jetpackLevel >= jetpackTop then
			return 0
		end
		local now = toNumber(Upgrades.jetpackMultiplier(jetpackLevel, UpgradeConfig.TUNING))
		local nextOne = toNumber(Upgrades.jetpackMultiplier(jetpackLevel + 1, UpgradeConfig.TUNING))
		return nextOne / now - 1
	end

	local function slotPrice(): number
		return toNumber(
			Bay.slotPrice(
				data.incubatorSlots,
				BayConfig.STARTING_INCUBATOR_SLOTS,
				BayConfig.SLOT_PRICE_BASE,
				BayConfig.SLOT_PRICE_GROWTH
			)
		)
	end

	-- An incubator slot whenever an egg waits for one, a pod whenever an alien waits for one;
	-- otherwise whichever upgrade gives more speed per coin.
	local function buy(now: number)
		while true do
			local slotWanted = #data.waiting > 0 and data.incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
			if slotWanted and coins >= slotPrice() then
				coins -= slotPrice()
				data.incubatorSlots += 1
				run.slotBought[data.incubatorSlots] = now
				Bay.fillSlots(data, now)
				continue
			end
			if #data.pods < BayConfig.MAX_PODS and #data.floor > 0 and coins >= podPrice() then
				coins -= podPrice()
				table.insert(data.pods, {})
				Bay.autoPlace(data, incomeOf)
				refreshIncome()
				continue
			end
			local trainerGain = (toNumber(UpgradeConfig.TUNING.trainerRateGrowth) - 1) / trainerPrice()
			local jetpackGain = jetpackStep() / jetpackPrice()
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
			-- Online at the station: the eggs that became ready while away are hatched first.
			if inDay == 0 then
				hatch(now)
			end
			trained += trainRate() * ASSUMPTIONS.trainShare * dt
			coins += incomeRate * dt
			-- The solar storm comes round while the player is on, for everyone on the server.
			if inDay % STORM_CYCLE >= STORM_CYCLE - STORM.schedule.activeSeconds then
				Bay.advanceIncubator(data, dt * (StormConfig.HATCH_RATE - 1))
			end
			-- The meteor shower: a crater in the zone of the farthest guardian the player beats,
			-- at a random post of that zone up to that guardian.
			if inDay % METEOR_CYCLE < dt and bestPost > 0 then
				local _, inZone = ZoneConfig.zoneOfPost(bestPost)
				for _ = 1, ASSUMPTIONS.meteorEggsPerShower do
					steal(bestPost - math.random(0, inZone - 1), now, "Meteor")
				end
			end
			-- The star serpent's hunt: now and then the player wins its egg.
			if inDay % SERPENT_CYCLE < dt and bestPost > 0 and math.random() < ASSUMPTIONS.starEggShare then
				winStarEgg(bestPost, now)
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
			if away < passEffects.offlineTrainingCapSeconds then
				trained += trainRate() * UpgradeConfig.OFFLINE_TRAINING_FACTOR * dt
			end
			if away < passEffects.offlineIncomeCapSeconds then
				coins += incomeRate * dt
			end
		end
		buy(now)
		now += dt

		local day = now / DAY_SECONDS
		if day == math.floor(day) and table.find(SNAPSHOT_DAYS, day) then
			run.snapshots[day] = {
				speed = speed(),
				income = incomeRate,
				pods = #data.pods,
				slots = data.incubatorSlots,
				waiting = #data.waiting,
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

-- Average time of a run's mark (a first beat, a slot bought) over the runs; nil when any run
-- never got there.
local function averageOf(runs: { Run }, markOf: (run: Run) -> number?): number?
	local total = 0
	for _, run in runs do
		local at = markOf(run)
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
		.. `, daily = quests ({string.format("%.0f", QUEST_MINUTES_A_DAY)} min a day), the login gift and the index; a solar storm every {STORM_CYCLE}s and a meteor shower every {METEOR_CYCLE}s `
		.. `({ASSUMPTIONS.meteorEggsPerShower} egg if its guardian is beaten), a serpent hunt every {SERPENT_CYCLE}s `
		.. `(the star egg, +{SerpentConfig.STAR_EGG_LUCK} luck, in {ASSUMPTIONS.starEggShare * 100}% of them) for all`
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
		line ..= pad(
			formatTime(averageOf(runsByProfile[profile.name], function(run)
				return run.firstBeat[post]
			end)),
			COLUMN_WIDTH
		)
	end
	print(line)
end

print("")
print("Incubator slots: when each is bought (average; - = not within the days)")
header = pad("slot", POST_WIDTH) .. pad("price", SPEED_WIDTH)
for _, profile in PROFILES do
	header ..= pad(profile.name, COLUMN_WIDTH)
end
print(header)
for slots = BayConfig.STARTING_INCUBATOR_SLOTS + 1, BayConfig.MAX_INCUBATOR_SLOTS do
	local price = Bay.slotPrice(
		slots - 1,
		BayConfig.STARTING_INCUBATOR_SLOTS,
		BayConfig.SLOT_PRICE_BASE,
		BayConfig.SLOT_PRICE_GROWTH
	)
	local line = pad(tostring(slots), POST_WIDTH) .. pad(BigNum.format(price), SPEED_WIDTH)
	for _, profile in PROFILES do
		line ..= pad(
			formatTime(averageOf(runsByProfile[profile.name], function(run)
				return run.slotBought[slots]
			end)),
			COLUMN_WIDTH
		)
	end
	print(line)
end

print("")
-- The "Collect x2" tier of the free cap away at this income (decision 064): the price a player
-- of that day sees after a long time away.
local function doubleTierAway(income: number): number
	return MonetizationConfig.doubleTierOf(BigNum.fromNumber(income * BayConfig.OFFLINE_INCOME_CAP_SECONDS))
end

print(
	"Snapshots (first run): day, speed, income/s, pods, trainer level, jetpack level, best post, "
		.. "Collect x2 tier after the free cap away"
)
for _, profile in PROFILES do
	print(profile.name)
	local run = runsByProfile[profile.name][1]
	for _, day in SNAPSHOT_DAYS do
		local snapshot = run.snapshots[day]
		if snapshot then
			local levels = `trainer {snapshot.trainerLevel} jetpack {snapshot.jetpackLevel}`
			print(
				`  day {pad(tostring(day), 3)} speed {pad(formatNumber(snapshot.speed), 8)} `
					.. `income {pad(formatNumber(snapshot.income), 8)} pods {pad(tostring(snapshot.pods), 3)} slots {snapshot.slots} queue {pad(
						tostring(snapshot.waiting),
						3
					)} `
					.. `{pad(levels, 22)} post {pad(tostring(snapshot.bestPost), 3)} x2 tier {doubleTierAway(
						snapshot.income
					)}`
			)
		end
	end
end
