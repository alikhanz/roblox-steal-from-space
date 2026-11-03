--!strict
-- A player's bay: pods that earn, the inventory, aliens waiting on the floor and eggs in the
-- incubator. Pure functions over the saved data that change it in place; they are meant to run
-- inside one DataService update each.

local BigNum = require("./BigNum")
local PlayerData = require("./PlayerData")

export type Location = "Pod" | "Inventory" | "Floor"
export type IncomeOf = (alienId: string) -> BigNum.BigNum

type Data = PlayerData.PlayerData
type Alien = PlayerData.AlienRecord

local Bay = {}

function Bay.newUid(data: Data): number
	local uid = data.nextUid
	data.nextUid += 1
	return uid
end

local function indexOf(list: { Alien }, uid: number): number?
	for index, record in list do
		if record.uid == uid then
			return index
		end
	end
	return nil
end

function Bay.find(data: Data, uid: number): (Alien?, Location?)
	for _, pod in data.pods do
		if pod.alien and pod.alien.uid == uid then
			return pod.alien, "Pod"
		end
	end
	local index = indexOf(data.inventory, uid)
	if index then
		return data.inventory[index], "Inventory"
	end
	index = indexOf(data.floor, uid)
	if index then
		return data.floor[index], "Floor"
	end
	return nil, nil
end

-- Takes an alien out of wherever it is. Returns nil when the player has no such alien.
function Bay.remove(data: Data, uid: number): Alien?
	for _, pod in data.pods do
		local alien = pod.alien
		if alien and alien.uid == uid then
			pod.alien = nil
			return alien
		end
	end
	for _, list in { data.inventory, data.floor } do
		local index = indexOf(list, uid)
		if index then
			return table.remove(list, index)
		end
	end
	return nil
end

function Bay.freePods(data: Data): number
	local free = 0
	for _, pod in data.pods do
		if not pod.alien then
			free += 1
		end
	end
	return free
end

-- A newly hatched (or crossbred) alien goes into the first free pod, else onto the floor.
function Bay.addHatched(data: Data, alien: Alien): Location
	for _, pod in data.pods do
		if not pod.alien then
			pod.alien = alien
			return "Pod"
		end
	end
	table.insert(data.floor, alien)
	return "Floor"
end

-- Moves an alien from the floor into the inventory. False when it is not on the floor or the
-- inventory is full.
function Bay.pickUp(data: Data, uid: number, inventorySlots: number): boolean
	local index = indexOf(data.floor, uid)
	if not index or #data.inventory >= inventorySlots then
		return false
	end
	table.insert(data.inventory, table.remove(data.floor, index) :: Alien)
	return true
end

function Bay.incomePerSecond(data: Data, incomeOf: IncomeOf): BigNum.BigNum
	local total = BigNum.ZERO
	for _, pod in data.pods do
		if pod.alien then
			total = BigNum.add(total, incomeOf(pod.alien.id))
		end
	end
	return total
end

-- Puts the best earners into the pods, the next ones into the inventory and the rest onto the
-- floor. Ties keep the older alien first, so repeating it changes nothing.
function Bay.autoPlace(data: Data, incomeOf: IncomeOf, inventorySlots: number)
	local all: { Alien } = {}
	for _, pod in data.pods do
		if pod.alien then
			table.insert(all, pod.alien)
			pod.alien = nil
		end
	end
	for _, list in { data.inventory, data.floor } do
		for _, alien in list do
			table.insert(all, alien)
		end
	end
	table.sort(all, function(left: Alien, right: Alien): boolean
		local order = BigNum.compare(incomeOf(left.id), incomeOf(right.id))
		if order ~= 0 then
			return order > 0
		end
		return left.uid < right.uid
	end)

	table.clear(data.inventory)
	table.clear(data.floor)
	for position, alien in all do
		if position <= #data.pods then
			data.pods[position].alien = alien
		elseif #data.inventory < inventorySlots then
			table.insert(data.inventory, alien)
		else
			table.insert(data.floor, alien)
		end
	end
end

-- Price of the next pod for a player who owns `ownedPods`: the first bought pod costs `base`,
-- each one after it `growth` times more.
function Bay.podPrice(
	ownedPods: number,
	startingPods: number,
	base: BigNum.BigNum,
	growth: BigNum.BigNum
): BigNum.BigNum
	local bought = math.max(0, ownedPods - startingPods)
	return BigNum.mul(base, BigNum.pow(growth, bought))
end

-- Removes and returns the eggs whose time has come, oldest first.
function Bay.takeHatched(data: Data, now: number): { PlayerData.EggRecord }
	local hatched = {}
	local waiting = {}
	for _, egg in data.incubator do
		if now >= egg.hatchAt then
			table.insert(hatched, egg)
		else
			table.insert(waiting, egg)
		end
	end
	table.sort(hatched, function(left: PlayerData.EggRecord, right: PlayerData.EggRecord): boolean
		return left.hatchAt < right.hatchAt
	end)
	table.clear(data.incubator)
	table.move(waiting, 1, #waiting, 1, data.incubator)
	return hatched
end

return table.freeze(Bay)
