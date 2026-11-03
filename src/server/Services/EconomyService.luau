--!strict
-- What a player can do with their bay and coins: place and move aliens, crossbreed, sell, buy
-- pods. Every command checks the profile and the request, then applies one change; the bay is
-- rebuilt afterwards. Returns nil on success or why the command was refused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Crossbreed = require(ReplicatedStorage.Shared.Domain.Crossbreed)
local Loot = require(ReplicatedStorage.Shared.Domain.Loot)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

export type Notice =
	"NoProfile"
	| "UnknownAlien"
	| "InventoryFull"
	| "NotEnoughCoins"
	| "MaxPods"
	| "NoSuchPod"
	| "WrongCount"
	| "MixedGrades"

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- Rebuilds the player's bay after a change.
	refresh: (player: Player) -> (),
}

export type EconomyService = {
	name: string,
	autoPlace: (player: Player) -> Notice?,
	-- Puts the alien into pod `pod` (1-based); whoever stood there goes to the inventory or floor.
	moveToPod: (player: Player, uid: number, pod: number) -> Notice?,
	moveToInventory: (player: Player, uid: number) -> Notice?,
	crossbreed: (player: Player, uids: { number }) -> Notice?,
	sell: (player: Player, uid: number) -> Notice?,
	buyPod: (player: Player) -> Notice?,
	-- Fires when a crossbreed produces an alien: the player, the alien and where it went.
	crossbred: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>,
}

local EconomyService = {}

local function incomeOf(alienId: string): BigNum.BigNum
	local alien = AlienConfig.ALIENS[alienId]
	return if alien then alien.income else BigNum.ZERO
end

local function isUid(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 1
end

function EconomyService.new(dependencies: Dependencies): EconomyService
	local random = Random.new()
	local crossbred = Signal.new() :: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>

	-- Runs `check` on the live profile, then `apply` as one update, then rebuilds the bay.
	local function command(
		player: Player,
		check: (data: PlayerData.PlayerData) -> Notice?,
		apply: (data: PlayerData.PlayerData) -> ()
	): Notice?
		local data = dependencies.getData(player)
		if not data then
			return "NoProfile"
		end
		local notice = check(data)
		if notice then
			return notice
		end
		if not dependencies.update(player, apply) then
			return "NoProfile"
		end
		dependencies.refresh(player)
		return nil
	end

	local function autoPlace(player: Player): Notice?
		return command(player, function()
			return nil
		end, function(data)
			Bay.autoPlace(data, incomeOf, BayConfig.INVENTORY_SLOTS)
		end)
	end

	local function moveToPod(player: Player, uid: number, pod: number): Notice?
		return command(player, function(data)
			if not isUid(uid) or not Bay.find(data, uid) then
				return "UnknownAlien"
			end
			if not isUid(pod) or pod > #data.pods then
				return "NoSuchPod"
			end
			return nil
		end, function(data)
			local alien = Bay.remove(data, uid) :: PlayerData.AlienRecord
			local displaced = data.pods[pod].alien
			data.pods[pod].alien = alien
			if displaced then
				if #data.inventory < BayConfig.INVENTORY_SLOTS then
					table.insert(data.inventory, displaced)
				else
					table.insert(data.floor, displaced)
				end
			end
		end)
	end

	local function moveToInventory(player: Player, uid: number): Notice?
		return command(player, function(data)
			local _, location = Bay.find(data, if isUid(uid) then uid else 0)
			if not location then
				return "UnknownAlien"
			end
			if location ~= "Inventory" and #data.inventory >= BayConfig.INVENTORY_SLOTS then
				return "InventoryFull"
			end
			return nil
		end, function(data)
			local _, location = Bay.find(data, uid)
			if location ~= "Inventory" then
				table.insert(data.inventory, Bay.remove(data, uid) :: PlayerData.AlienRecord)
			end
		end)
	end

	local function crossbreed(player: Player, uids: { number }): Notice?
		local resultId: AlienConfig.AlienId? = nil
		local resultLocation: Bay.Location? = nil
		local notice = command(player, function(data)
			if #uids ~= BayConfig.CROSSBREED_COUNT then
				return "WrongCount"
			end
			local grades = {}
			local seen: { [number]: boolean } = {}
			for _, uid in uids do
				local record = if isUid(uid) and not seen[uid] then Bay.find(data, uid) else nil
				local alien = record and AlienConfig.ALIENS[record.id]
				if not alien then
					return "UnknownAlien"
				end
				seen[uid] = true
				table.insert(grades, alien.grade)
			end
			return Crossbreed.check(grades, BayConfig.CROSSBREED_COUNT)
		end, function(data)
			local positions = {}
			local grade = 0
			for _, uid in uids do
				local record = Bay.remove(data, uid) :: PlayerData.AlienRecord
				local alien = AlienConfig.ALIENS[record.id]
				grade = alien.grade
				table.insert(positions, AlienConfig.TIER_POSITIONS[alien.tier])
			end
			local entries = Crossbreed.resultEntries(AlienConfig.HATCH_ENTRIES, positions, BayConfig.CROSSBREED_LUCK)
			local tier = Loot.pick(entries, random:NextNumber())
			resultId = AlienConfig.GRADES[grade].aliens[tier]
			resultLocation = Bay.addHatched(data, { uid = Bay.newUid(data), id = resultId :: string })
		end)
		if not notice and resultId and resultLocation then
			crossbred.fire(player, resultId, resultLocation)
		end
		return notice
	end

	local function sell(player: Player, uid: number): Notice?
		return command(player, function(data)
			local record = if isUid(uid) then Bay.find(data, uid) else nil
			return if record and AlienConfig.ALIENS[record.id] then nil else "UnknownAlien"
		end, function(data)
			local record = Bay.remove(data, uid) :: PlayerData.AlienRecord
			local price = BigNum.mul(incomeOf(record.id), BigNum.fromNumber(BayConfig.SELL_INCOME_SECONDS))
			data.coins = BigNum.add(data.coins, price)
		end)
	end

	local function price(data: PlayerData.PlayerData): BigNum.BigNum
		return Bay.podPrice(#data.pods, BayConfig.STARTING_PODS, BayConfig.POD_PRICE_BASE, BayConfig.POD_PRICE_GROWTH)
	end

	local function buyPod(player: Player): Notice?
		return command(player, function(data)
			if #data.pods >= BayConfig.MAX_PODS then
				return "MaxPods"
			end
			if BigNum.lessThan(data.coins, price(data)) then
				return "NotEnoughCoins"
			end
			return nil
		end, function(data)
			-- Checked again inside the update: the profile is the one that counts.
			if #data.pods >= BayConfig.MAX_PODS or BigNum.lessThan(data.coins, price(data)) then
				return
			end
			data.coins = BigNum.sub(data.coins, price(data))
			table.insert(data.pods, {})
		end)
	end

	return {
		name = "EconomyService",
		autoPlace = autoPlace,
		moveToPod = moveToPod,
		moveToInventory = moveToInventory,
		crossbreed = crossbreed,
		sell = sell,
		buyPod = buyPod,
		crossbred = crossbred,
	}
end

return table.freeze(EconomyService)
