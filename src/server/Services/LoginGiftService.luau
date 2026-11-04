--!strict
-- The login gift on the server: tells each player where their streak stands (on join and at UTC
-- midnight while online) and pays the day's gift when they take it: minutes of their own play
-- (Domain/PlayReward), and on the last streak day an egg in the incubator too, all in one
-- profile update. The streak lives in the profile (Domain/LoginGift).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local Hatch = require(ReplicatedStorage.Shared.Domain.Hatch)
local LoginGift = require(ReplicatedStorage.Shared.Domain.LoginGift)
local LoginGiftConfig = require(ReplicatedStorage.Shared.Config.LoginGiftConfig)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)

export type Notice = "GiftTaken"

-- What a taken gift paid.
export type Reward = {
	day: number,
	coins: BigNum.BigNum,
	-- Speed points as trained, and the stat they add (times the jetpack).
	trained: BigNum.BigNum,
	speed: BigNum.BigNum,
	-- The last day's egg went into the incubator.
	egg: boolean,
}

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
	getIncomePerSecond: (player: Player) -> BigNum.BigNum,
	-- Re-publishes the speed stat, and rebuilds the bay (the egg shows on the incubator).
	publishSpeed: (player: Player) -> (),
	refreshBay: (player: Player) -> (),
}

export type LoginGiftService = {
	name: string,
	start: () -> (),
	-- The player's gift status may have changed (joined, a new day, taken).
	changed: Signal.Signal<Player>,
	rewarded: Signal.Signal<Player, Reward>,
	-- Today's status for `player`, or nil without a profile.
	getStatus: (player: Player) -> LoginGift.Status?,
	claim: (player: Player) -> Notice?,
	-- Studio command: makes the last gift `days` days old (1: the next streak day waits; 2: a
	-- day was missed).
	shiftDays: (player: Player, days: number) -> boolean,
}

local LoginGiftService = {}

local function today(): number
	return Quests.dayOf(os.time())
end

function LoginGiftService.new(dependencies: Dependencies): LoginGiftService
	local changed = Signal.new() :: Signal.Signal<Player>
	local rewarded = Signal.new() :: Signal.Signal<Player, Reward>
	local random = Random.new()
	-- The day each online player's status was last sent for.
	local sentDay: { [Player]: number } = {}

	local function getStatus(player: Player): LoginGift.Status?
		local data = dependencies.getData(player)
		return if data then LoginGift.status(data.loginGift, today(), LoginGiftConfig.LENGTH) else nil
	end

	local function send(player: Player)
		sentDay[player] = today()
		changed.fire(player)
	end

	local function claim(player: Player): Notice?
		local income = dependencies.getIncomePerSecond(player)
		local reward: Reward? = nil
		local eggRarity = EggConfig.RARITIES[LoginGiftConfig.EGG_RARITY]
		local hatchSeconds = Hatch.duration(eggRarity.hatchSeconds, random:NextNumber())
		dependencies.update(player, function(data)
			local day = LoginGift.claim(data.loginGift, today(), LoginGiftConfig.LENGTH)
			if not day then
				return
			end
			local rate = Upgrades.trainerRate(data.trainerLevel, UpgradeConfig.TUNING)
			local minutes = LoginGiftConfig.MINUTES[day] or 0
			local coins, trained = PlayReward.worth(minutes, income, rate, LoginGiftConfig.MIN_REWARD_COINS)
			Wallet.earn(data, coins)
			data.trained = BigNum.add(data.trained, trained)
			local egg = false
			if day == LoginGiftConfig.EGG_DAY then
				local grade = math.clamp(data.bestPost, 1, #AlienConfig.GRADES)
				table.insert(data.incubator, {
					uid = Bay.newUid(data),
					rarity = LoginGiftConfig.EGG_RARITY,
					size = LoginGiftConfig.EGG_SIZE,
					grade = grade,
					-- The bay's clock (BayService hatches against server time).
					hatchAt = workspace:GetServerTimeNow() + hatchSeconds,
				})
				egg = true
			end
			reward = {
				day = day,
				coins = coins,
				trained = trained,
				speed = BigNum.mul(trained, Upgrades.jetpackMultiplier(data.jetpackLevel, UpgradeConfig.TUNING)),
				egg = egg,
			}
		end)
		if not reward then
			return "GiftTaken"
		end
		dependencies.publishSpeed(player)
		if reward.egg then
			dependencies.refreshBay(player)
		end
		send(player)
		rewarded.fire(player, reward)
		return nil
	end

	local function shiftDays(player: Player, days: number): boolean
		local written = dependencies.update(player, function(data)
			-- From today, not from the stored day, so calling it twice does not skip a day.
			if data.loginGift.lastDay > 0 then
				data.loginGift.lastDay = math.max(today() - days, 1)
			end
		end)
		if written then
			send(player)
		end
		return written
	end

	-- At UTC midnight online players' gifts come back.
	local function checkDay()
		local day = today()
		for player, sent in sentDay do
			if sent ~= day then
				send(player)
			end
		end
	end

	local function start()
		dependencies.activated.connect(send)
		PlayerEvents.observe(function() end, function(player)
			sentDay[player] = nil
		end)
		dependencies.scheduler.every(LoginGiftConfig.DAY_CHECK_SECONDS, checkDay)
	end

	return {
		name = "LoginGiftService",
		start = start,
		changed = changed,
		rewarded = rewarded,
		getStatus = getStatus,
		claim = claim,
		shiftDays = shiftDays,
	}
end

return table.freeze(LoginGiftService)
