--!strict
-- A low-poly pet's outfit (decisions 118, 121): a head piece, an aura and from rare up a back piece,
-- drawn from its tier's pools, so two pets of one kind and tier can look apart while the colours
-- (the tier's) still tell the tier. The outfit is drawn once, when the alien comes to be (hatched,
-- crossbred, given), and saved with it (PlayerData.AlienRecord.outfit) by its pieces' ids: a
-- changed pool only changes what new aliens draw. A piece taken out of the game is replaced at load
-- (`repair`). The pools mirror assets/blender/lowpoly/lowpoly_dress.py (POOLS). Pure Luau: the
-- randomness comes in as `NextInteger` (the server's Random; a fixed `sequence` in tests).

local AlienConfig = require("../Config/AlienConfig")

local AlienOutfit = {}

export type Picks = {
	head: string?,
	aura: string?,
	back: string?,
}

export type Slot = "head" | "aura" | "back"

-- A random whole number from `min` to `max`, both included (Random:NextInteger).
export type NextInteger = (min: number, max: number) -> number

-- A pool by tier (0 Common … 4 Legendary) and slot; false is "nothing in this slot". Pieces are
-- named by the ids an outfit is saved with: never rename one (add a new id and replace the old at
-- load instead); order and new entries are free.
local HEAD: { string | false } = { "horns", "crest", "feelers" }
local AURA_LOW: { string | false } = { "halo", "shards" }
local AURA: { string | false } = { "halo", "shards", "rings" }
local WINGS: { string | false } = { "butterfly", "angel", "dragon", "crystal", "fairy" }
local POOLS: { { [Slot]: { string | false } } } = {
	{ head = { "horns", "crest", "feelers", false } },
	{ head = HEAD, aura = AURA_LOW },
	{ head = HEAD, aura = AURA, back = { "jetpack", "angelSmall", "butterflySmall" } },
	{ head = HEAD, aura = AURA, back = WINGS },
	{ head = { "crown" }, aura = { "halo", "shards", "rings", "star" }, back = WINGS },
}
AlienOutfit.SLOTS = table.freeze({ "head", "aura", "back" } :: { Slot })
AlienOutfit.TIERS = #POOLS

local TWO_32 = 4294967296

-- (a * b) mod 2^32 for 32-bit a and b, exact in doubles (each product stays under 2^53).
local function mul32(a: number, b: number): number
	local low, high = a % 65536, a // 65536
	return (low * b + ((high * b) % 65536) * 65536) % TWO_32
end

-- A fixed stream of random whole numbers from `seed` (a 32-bit LCG): the same draws every run, for
-- tests and for loading data where no server Random is given.
function AlienOutfit.sequence(seed: number): NextInteger
	local state = math.floor(seed) % TWO_32
	return function(min: number, max: number): number
		state = (mul32(state, 1664525) + 1013904223) % TWO_32
		return min + (state // 256) % (max - min + 1)
	end
end

local function poolsOf(tier: number): { [Slot]: { string | false } }
	return assert(POOLS[tier], `No outfit pools for tier {tier}`)
end

-- One draw from `pool`: a piece, or nil for "nothing".
local function drawFrom(pool: { string | false }, nextInteger: NextInteger): string?
	local piece = pool[nextInteger(1, #pool)]
	return if piece then piece else nil
end

-- A new outfit for an alien of `tier` (1 Common … 5 Legendary, AlienConfig.TIER_POSITIONS).
function AlienOutfit.draw(tier: number, nextInteger: NextInteger): Picks
	local pools = poolsOf(tier)
	local picks: { [string]: string } = {}
	for _, slot in AlienOutfit.SLOTS do
		local pool = pools[slot]
		local piece = if pool then drawFrom(pool, nextInteger) else nil
		if piece then
			picks[slot] = piece
		end
	end
	return picks :: Picks
end

-- The tier position of an alien, or nil for an id the game doesn't know.
local function tierOf(alienId: string): number?
	local alien = AlienConfig.ALIENS[alienId]
	return if alien then AlienConfig.TIER_POSITIONS[alien.tier] else nil
end

-- A new outfit for the alien `alienId`; nil for an id the game doesn't know (nothing to dress).
function AlienOutfit.forAlien(alienId: string, nextInteger: NextInteger): Picks?
	local tier = tierOf(alienId)
	return if tier then AlienOutfit.draw(tier, nextInteger) else nil
end

local KNOWN: { [Slot]: { [string]: boolean } } = { head = {}, aura = {}, back = {} }
for _, pools in POOLS do
	for slot, pool in pools do
		for _, piece in pool do
			if piece then
				KNOWN[slot][piece] = true
			end
		end
	end
end

-- Whether `piece` is a piece of `slot` the game has.
function AlienOutfit.isPiece(slot: Slot, piece: string): boolean
	return KNOWN[slot][piece] == true
end

-- A saved outfit made safe to wear (at load): a piece the game no longer has is replaced by a new
-- draw for its slot from the alien's tier's pools, and a slot its tier has no pool for is emptied.
-- Pieces the game has stay, even ones the tier's pools no longer offer. Returns whether it changed.
function AlienOutfit.repair(outfit: Picks, alienId: string, nextInteger: NextInteger): boolean
	local tier = tierOf(alienId)
	if not tier then
		return false
	end
	local pools = poolsOf(tier)
	local slots = outfit :: { [string]: string? }
	local changed = false
	for _, slot in AlienOutfit.SLOTS do
		local piece = slots[slot]
		if piece ~= nil and not AlienOutfit.isPiece(slot, piece) then
			local pool = pools[slot]
			slots[slot] = if pool then drawFrom(pool, nextInteger) else nil
			changed = true
		end
	end
	return changed
end

-- The first piece of every pool of `tier`: what a pet's room on the island is measured with.
function AlienOutfit.first(tier: number): Picks
	local picks: { [string]: string } = {}
	for slot, pool in poolsOf(tier) do
		local piece = drawFrom(pool, function(min: number): number
			return min
		end)
		if piece then
			picks[slot] = piece
		end
	end
	return picks :: Picks
end

-- A short text naming the picks (a cache key).
function AlienOutfit.key(picks: Picks): string
	return `{picks.head or "-"}/{picks.aura or "-"}/{picks.back or "-"}`
end

-- Every piece any pool may roll, by slot.
function AlienOutfit.pieces(slot: Slot): { string }
	local seen: { [string]: boolean } = {}
	local list: { string } = {}
	for _, pools in POOLS do
		for _, piece in pools[slot] or {} do
			if piece and not seen[piece] then
				seen[piece] = true
				table.insert(list, piece)
			end
		end
	end
	return list
end

return table.freeze(AlienOutfit)
