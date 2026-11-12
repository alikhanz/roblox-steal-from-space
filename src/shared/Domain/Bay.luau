--!strict
-- A player's bay: pods that earn, the shelf of aliens with no pod (saved as `floor`, decision
-- 092) and eggs in the incubator. Pure functions over the saved data that change it in place;
-- they are meant to run inside one DataService update each.

local BigNum = require("./BigNum")
local PlayerData = require("./PlayerData")

-- Where an alien stands: in a pod, or on the shelf ("Floor": the name it keeps in the save).
export type Location = "Pod" | "Floor"
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

-- The pod an alien stands in, by its number; nil when it is not in a pod.
local function podOf(data: Data, uid: number): number?
	for index, pod in data.pods do
		if pod.alien and pod.alien.uid == uid then
			return index
		end
	end
	return nil
end

function Bay.find(data: Data, uid: number): (Alien?, Location?)
	local pod = podOf(data, uid)
	if pod then
		return data.pods[pod].alien, "Pod"
	end
	local index = indexOf(data.floor, uid)
	if index then
		return data.floor[index], "Floor"
	end
	return nil, nil
end

-- Takes an alien out of wherever it is. Returns nil when the player has no such alien.
function Bay.remove(data: Data, uid: number): Alien?
	local pod = podOf(data, uid)
	if pod then
		local alien = data.pods[pod].alien
		data.pods[pod].alien = nil
		return alien
	end
	local index = indexOf(data.floor, uid)
	return if index then table.remove(data.floor, index) else nil
end

-- Takes out every alien of `uids`, or none: nil when a uid repeats or names no alien of the
-- player. In the order of `uids`.
function Bay.removeMany(data: Data, uids: { number }): { Alien }?
	local seen: { [number]: boolean } = {}
	for _, uid in uids do
		if seen[uid] or not Bay.find(data, uid) then
			return nil
		end
		seen[uid] = true
	end
	local removed: { Alien } = {}
	for _, uid in uids do
		table.insert(removed, Bay.remove(data, uid) :: Alien)
	end
	return removed
end

function Bay.freePods(data: { read pods: { PlayerData.Pod } }): number
	local free = 0
	for _, pod in data.pods do
		if not pod.alien then
			free += 1
		end
	end
	return free
end

-- True when a new alien has somewhere to stand: a free pod, or a free niche on a shelf of
-- `shelfSlots` (decision 110: with neither, eggs wait instead of hatching). Takes the profile or
-- the client's copy of the bay.
function Bay.hasRoom(data: { read pods: { PlayerData.Pod }, read floor: { Alien } }, shelfSlots: number): boolean
	return Bay.freePods(data) > 0 or #data.floor < shelfSlots
end

-- A newly hatched (or crossbred) alien goes into the first free pod, else onto the shelf.
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

-- Orders aliens best earner first; ties keep the older alien first, so sorting again changes
-- nothing.
local function byIncome(incomeOf: IncomeOf): (Alien, Alien) -> boolean
	return function(left: Alien, right: Alien): boolean
		local order = BigNum.compare(incomeOf(left.id), incomeOf(right.id))
		if order ~= 0 then
			return order > 0
		end
		return left.uid < right.uid
	end
end

-- The best earner on the shelf: its index there, or nil for an empty shelf.
function Bay.bestOnShelf(data: { read floor: { Alien } }, incomeOf: IncomeOf): number?
	local best: number? = nil
	local before = byIncome(incomeOf)
	for index, alien in data.floor do
		if not best or before(alien, data.floor[best]) then
			best = index
		end
	end
	return best
end

-- Puts the best earner from the shelf into pod number `pod` when it stands empty (a pod just
-- bought, "Place the best" at a free pod). Returns the alien that moved, or nil.
function Bay.fillPod(data: Data, pod: number, incomeOf: IncomeOf): Alien?
	local target = data.pods[pod]
	local best = Bay.bestOnShelf(data, incomeOf)
	if not target or target.alien or not best then
		return nil
	end
	local alien = table.remove(data.floor, best) :: Alien
	target.alien = alien
	return alien
end

-- Puts an alien into pod number `pod`. Whoever stood there swaps with it: into the pod it came
-- from, or into its place on the shelf, so the shelf never grows. False when there is no such
-- alien or pod.
function Bay.moveToPod(data: Data, uid: number, pod: number): boolean
	local target = data.pods[pod]
	local _, location = Bay.find(data, uid)
	if not target or not location then
		return false
	end
	local displaced = target.alien
	if displaced and displaced.uid == uid then
		return true
	end
	if location == "Pod" then
		local from = podOf(data, uid) :: number
		target.alien, data.pods[from].alien = data.pods[from].alien, displaced
	else
		local index = indexOf(data.floor, uid) :: number
		target.alien = data.floor[index]
		if displaced then
			data.floor[index] = displaced
		else
			table.remove(data.floor, index)
		end
	end
	return true
end

-- Moves an alien from its pod onto the shelf. False when it is not in a pod or the shelf of
-- `shelfSlots` is full.
function Bay.toShelf(data: Data, uid: number, shelfSlots: number): boolean
	local pod = podOf(data, uid)
	if not pod or #data.floor >= shelfSlots then
		return false
	end
	table.insert(data.floor, data.pods[pod].alien :: Alien)
	data.pods[pod].alien = nil
	return true
end

-- Takes anything with pods: the profile, or the client's copy of the bay.
function Bay.incomePerSecond(data: { read pods: { PlayerData.Pod } }, incomeOf: IncomeOf): BigNum.BigNum
	local total = BigNum.ZERO
	for _, pod in data.pods do
		if pod.alien then
			total = BigNum.add(total, incomeOf(pod.alien.id))
		end
	end
	return total
end

-- Puts the best earners into the pods and the rest onto the shelf, best first.
function Bay.autoPlace(data: Data, incomeOf: IncomeOf)
	local all: { Alien } = {}
	for _, pod in data.pods do
		if pod.alien then
			table.insert(all, pod.alien)
			pod.alien = nil
		end
	end
	for _, alien in data.floor do
		table.insert(all, alien)
	end
	table.sort(all, byIncome(incomeOf))

	table.clear(data.floor)
	for position, alien in all do
		if position <= #data.pods then
			data.pods[position].alien = alien
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

-- Price of the next incubator slot for an incubator of `slots`: the first bought one costs
-- `base`, each one after it `growth` times more (decision 058).
function Bay.slotPrice(slots: number, startingSlots: number, base: BigNum.BigNum, growth: BigNum.BigNum): BigNum.BigNum
	return Bay.podPrice(slots, startingSlots, base, growth)
end

-- Moves the first waiting egg into the incubator, warming from `startsAt` (server time).
local function promote(data: Data, startsAt: number)
	local first = table.remove(data.waiting, 1)
	if not first then
		return
	end
	table.insert(data.incubator, {
		uid = first.uid,
		rarity = first.rarity,
		size = first.size,
		grade = first.grade,
		hatchAt = startsAt + first.hatchSeconds,
		variant = first.variant,
		luck = first.luck,
	})
end

-- Fills every free slot with waiting eggs, warming from `now` (a slot bought, an egg arrived or
-- hatched).
function Bay.fillSlots(data: Data, now: number)
	while #data.incubator < data.incubatorSlots and #data.waiting > 0 do
		promote(data, now)
	end
end

-- Takes in an egg that hatches `hatchSeconds` after it starts warming, into an alien of
-- `variant` (nil or "Normal": the usual one): into a free slot, warming from `now`, or else to
-- the end of the queue (decision 058). The one way eggs come: delivered, given by the login
-- gift or a Studio command. Returns its uid.
function Bay.addEgg(
	data: Data,
	rarity: string,
	size: string,
	grade: number,
	hatchSeconds: number,
	now: number,
	variant: string?,
	luck: number?
): number
	local uid = Bay.newUid(data)
	table.insert(data.waiting, {
		uid = uid,
		rarity = rarity,
		size = size,
		grade = grade,
		hatchSeconds = hatchSeconds,
		-- The usual variant and no extra luck are left out of the save.
		variant = if variant == "Normal" then nil else variant,
		luck = if luck and luck > 0 then luck else nil,
	})
	Bay.fillSlots(data, now)
	return uid
end

-- Moves every egg in the incubator's slots `seconds` closer to being ready (a sped-up
-- incubator); the queue does not warm.
function Bay.advanceIncubator(data: Data, seconds: number)
	assert(seconds >= 0, "the incubator only runs forwards")
	for _, egg in data.incubator do
		egg.hatchAt -= seconds
	end
end

-- An egg in a slot whose time has come is ready: it keeps its slot until the player hatches it
-- (decision 059).
function Bay.isReady(egg: { read hatchAt: number }, now: number): boolean
	return egg.hatchAt <= now
end

-- How many eggs in the slots are ready to hatch.
function Bay.readyCount(data: { read incubator: { PlayerData.EggRecord } }, now: number): number
	local ready = 0
	for _, egg in data.incubator do
		if Bay.isReady(egg, now) then
			ready += 1
		end
	end
	return ready
end

-- The player hatches a ready egg: takes it out of its slot and returns it, and the first
-- waiting egg takes the slot, warming from `now`. Nil when there is no such egg or it is not
-- ready yet.
function Bay.hatch(data: Data, uid: number, now: number): PlayerData.EggRecord?
	for index, egg in data.incubator do
		if egg.uid == uid then
			if not Bay.isReady(egg, now) then
				return nil
			end
			table.remove(data.incubator, index)
			Bay.fillSlots(data, now)
			return egg
		end
	end
	return nil
end

-- Which capsule each egg warming in the incubator lies in, by uid (`uids` in the incubator's
-- order): an egg keeps the capsule it had (`previous`) while there are `capsules` of them, and a
-- new one takes the first free capsule. A hatch or a new egg moves no other egg (the incubator's
-- list closes up behind a hatched egg, and every egg after it used to jump one capsule round).
function Bay.capsulesFor(uids: { number }, previous: { [number]: number }, capsules: number): { [number]: number }
	local result: { [number]: number } = {}
	local taken: { [number]: boolean } = {}
	for _, uid in uids do
		local capsule = previous[uid]
		if capsule and capsule <= capsules and not taken[capsule] then
			result[uid] = capsule
			taken[capsule] = true
		end
	end
	local free = 1
	for _, uid in uids do
		if not result[uid] then
			while taken[free] do
				free += 1
			end
			result[uid] = free
			taken[free] = true
		end
	end
	return result
end

return table.freeze(Bay)
