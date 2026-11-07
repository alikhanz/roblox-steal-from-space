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
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local UtcDay = require(ReplicatedStorage.Shared.Domain.UtcDay)

export type Notice = "GiftTaken"

-- What a taken gift paid.
export type Reward = {
	day: number,
	paid: PlayReward.Paid,
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
	-- The player brought an egg home: a brand-new player's first gift unlocks with the first
	-- one (once the profile has it as their farthest delivery, PlayerData.bestPost).
	eggDelivered: (player: Player) -> (),
	claim: (player: Player) -> Notice?,
	-- Studio command: makes the last gift `days` days old (1: the next streak day waits; 2: a
	-- day was missed). A player who has not delivered yet counts as having delivered from the
	-- first guardian: Studio profiles always start new, and the gift waits for a delivery.
	shiftDays: (player: Player, days: number) -> boolean,
}

local LoginGiftService = {}

local function today(): number
	return UtcDay.of(os.time())
end

function LoginGiftService.new(dependencies: Dependencies): LoginGiftService
	local changed = Signal.new() :: Signal.Signal<Player>
	local rewarded = Signal.new() :: Signal.Signal<Player, Reward>
	local random = Random.new()
	-- The day each online player's status was last sent for.
	local sentDay: { [Player]: number } = {}
	-- Whether the gift each online player was last told about was locked (no delivery yet).
	local sentLocked: { [Player]: boolean } = {}

	-- The player has brought an egg home at least once.
	local function hasDelivered(data: PlayerData.PlayerData): boolean
		return data.bestPost > 0
	end

	local function getStatus(player: Player): LoginGift.Status?
		local data = dependencies.getData(player)
		return if data
			then LoginGift.status(data.loginGift, today(), LoginGiftConfig.LENGTH, hasDelivered(data))
			else nil
	end

	local function send(player: Player)
		sentDay[player] = today()
		local status = getStatus(player)
		sentLocked[player] = status ~= nil and status.locked
		changed.fire(player)
	end

	local function claim(player: Player): Notice?
		local income = dependencies.getIncomePerSecond(player)
		local reward: Reward? = nil
		local eggRarity = EggConfig.RARITIES[LoginGiftConfig.EGG_RARITY]
		local hatchSeconds = Hatch.duration(eggRarity.hatchSeconds, random:NextNumber())
		dependencies.update(player, function(data)
			local day = LoginGift.claim(data.loginGift, today(), LoginGiftConfig.LENGTH, hasDelivered(data))
			if not day then
				return
			end
			local minutes = LoginGiftConfig.MINUTES[day] or 0
			local pace = { income = income, trainerLevel = data.trainerLevel, jetpackLevel = data.jetpackLevel }
			local paid = PlayReward.of(minutes, pace, LoginGiftConfig.MIN_REWARD_COINS, true, UpgradeConfig.TUNING)
			PlayReward.pay(data, paid)
			local egg = false
			if day == LoginGiftConfig.EGG_DAY then
				local grade = math.clamp(data.bestPost, 1, #AlienConfig.GRADES)
				-- The bay's clock: BayService hatches against server time. A full incubator queues it.
				local now = workspace:GetServerTimeNow()
				Bay.addEgg(data, LoginGiftConfig.EGG_RARITY, LoginGiftConfig.EGG_SIZE, grade, hatchSeconds, now)
				egg = true
			end
			reward = { day = day, paid = paid, egg = egg }
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
			data.bestPost = math.max(data.bestPost, 1)
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
			sentLocked[player] = nil
		end)
		dependencies.scheduler.every(LoginGiftConfig.DAY_CHECK_SECONDS, checkDay)
	end

	return {
		name = "LoginGiftService",
		start = start,
		changed = changed,
		rewarded = rewarded,
		getStatus = getStatus,
		eggDelivered = function(player: Player)
			local status = getStatus(player)
			if sentLocked[player] and status and not status.locked then
				send(player)
			end
		end,
		claim = claim,
		shiftDays = shiftDays,
	}
end

return table.freeze(LoginGiftService)
