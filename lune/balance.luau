--!strict
-- `lune run balance [days]`: when does a player first beat each guardian, and what does their
-- bay look like along the way? Simulates a day-by-day player for three spending profiles,
-- driven by the real configs and domain code. Numbers that are not configs (how a player
-- spends their time) are the ASSUMPTIONS below. Run it after touching any economy config.

local process = require("@lune/process")

local AlienConfig = require("../src/shared/Config/AlienConfig")
local Bay = require("../src/shared/Domain/Bay")
local BayConfig = require("../src/shared/Config/BayConfig")
local BigNum = require("../src/shared/Domain/BigNum")
local EggConfig = require("../src/shared/Config/EggConfig")
local GuardianConfig = require("../src/shared/Config/GuardianConfig")
local Hatch = require("../src/shared/Domain/Hatch")
local Loot = require("../src/shared/Domain/Loot")
local PlayerData = require("../src/shared/Domain/PlayerData")
local SpeedConfig = require("../src/shared/Config/SpeedConfig")
local UpgradeConfig = require("../src/shared/Config/UpgradeConfig")

local ASSUMPTIONS = {
	-- Guardians in the whole game (GAME_DESIGN); posts past the configured ones keep the growth.
	guardianCount = 24,
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
}

local PROFILES: { Profile } = {
	{ name = "free", pass = 1, packageHours = 0 },
	{ name = "pass x2", pass = ASSUMPTIONS.trainingPass, packageHours = 0 },
	{ name = "pass + pack", pass = ASSUMPTIONS.trainingPass, packageHours = ASSUMPTIONS.packageHours },
}

local DAY_SECONDS = 24 * 60 * 60
local SNAPSHOT_DAYS = { 1, 7, 30, ASSUMPTIONS.days }

local DEFAULTS: PlayerData.Defaults = {
	startingSpeed = SpeedConfig.STARTING_SPEED,
	startingPods = BayConfig.STARTING_PODS,
}

local function toNumber(value: BigNum.BigNum): number
	return BigNum.toNumber(value)
end

-- The speed recommended over guardian k, from the configured posts or extrapolated past them.
local function recommendedFor(post: number): number
	return toNumber(GuardianConfig.FIRST_RECOMMENDED) * toNumber(GuardianConfig.RECOMMENDED_GROWTH) ^ (post - 1)
end

-- Income of every alien by id: the configured ones, plus synthetic ids for grades past the
-- configured posts (same growth).
local incomes: { [string]: BigNum.BigNum } = {}
for id, alien in AlienConfig.ALIENS do
	incomes[id] = alien.income
end
local function alienIdFor(grade: number, tier: AlienConfig.TierId): string
	local configured = AlienConfig.GRADES[grade]
	if configured then
		return configured.aliens[tier]
	end
	local id = `Grade{grade}.{tier}`
	if not incomes[id] then
		local base = BigNum.mul(AlienConfig.INCOME_BASE, BigNum.pow(AlienConfig.INCOME_GROWTH, grade - 1))
		incomes[id] = BigNum.mul(base, BigNum.fromNumber(AlienConfig.TIERS[tier].incomeFactor))
	end
	return id
end
local function incomeOf(id: string): BigNum.BigNum
	return assert(incomes[id], `unknown alien {id}`)
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
		return trained * toNumber(UpgradeConfig.JETPACK_MULTIPLIER) ^ jetpackLevel
	end
	local function trainRate(): number
		return toNumber(UpgradeConfig.TRAINER_BASE_RATE)
			* toNumber(UpgradeConfig.TRAINER_RATE_GROWTH) ^ trainerLevel
			* profile.pass
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

	local function steal(post: number, now: number)
		local rarity = Loot.pick(EggConfig.DEBRIS_BELT_LOOT, math.random())
		local size = Loot.pick(EggConfig.DEBRIS_BELT_SIZE_LOOT, math.random())
		table.insert(data.incubator, {
			uid = Bay.newUid(data),
			rarity = rarity,
			size = size,
			grade = post,
			hatchAt = now + Hatch.duration(EggConfig.RARITIES[rarity].hatchSeconds, math.random()),
		})
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
			Bay.addHatched(data, { uid = Bay.newUid(data), id = alienIdFor(egg.grade, tier) })
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
		return toNumber(UpgradeConfig.TRAINER_COST_BASE) * toNumber(UpgradeConfig.TRAINER_COST_GROWTH) ^ trainerLevel
	end
	local function jetpackPrice(): number
		return toNumber(UpgradeConfig.JETPACK_COST_BASE) * toNumber(UpgradeConfig.JETPACK_COST_GROWTH) ^ jetpackLevel
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
			local trainerGain = (toNumber(UpgradeConfig.TRAINER_RATE_GROWTH) - 1) / trainerPrice()
			local jetpackGain = (toNumber(UpgradeConfig.JETPACK_MULTIPLIER) - 1) / jetpackPrice()
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

local POST_WIDTH, SPEED_WIDTH, COLUMN_WIDTH = 5, 10, 13
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
