--!strict
-- A low-poly pet's outfit (decision 118): each pet rolls its pieces from its tier's pools, a head
-- piece, an aura and from rare up a back piece, so two pets of one kind and tier can look apart while
-- the colours (the tier's) still tell the tier. Nothing is saved: the roll is a hash of the owner's
-- UserId and the alien's uid, so the pet looks the same after a rejoin, on every place, to every
-- player. Mirrors assets/blender/lowpoly/lowpoly_dress.py (roll, POOLS); a test keeps them in step.
-- Pure Luau.

local AlienOutfit = {}

export type Picks = {
	read head: string?,
	read aura: string?,
	read back: string?,
}

export type Slot = "head" | "aura" | "back"

-- A pool by tier (0 Common … 4 Legendary) and slot; false is "nothing in this slot". A roll is an
-- index into a pool, so a changed pool would change pets already hatched: only ever add at the end,
-- and then keep the old length for the old pets (or save the picks with the alien).
local HEAD: { string | false } = { "horns", "crest", "feelers" }
local AURA_LOW: { string | false } = { "halo", "shards" }
local AURA: { string | false } = { "halo", "shards", "rings" }
local WINGS: { string | false } = { "butterfly", "angel", "dragon", "crystal", "sail" }
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

-- 32-bit FNV-1a with a final mix (MurmurHash3's): without the mix, neighbouring uids differ only in
-- the low bits and roll the same pieces.
function AlienOutfit.hash(text: string): number
	local value = 0x811C9DC5
	for index = 1, #text do
		value = mul32(bit32.bxor(value, string.byte(text, index)), 0x01000193)
	end
	value = bit32.bxor(value, bit32.rshift(value, 16))
	value = mul32(value, 0x85EBCA6B)
	value = bit32.bxor(value, bit32.rshift(value, 13))
	value = mul32(value, 0xC2B2AE35)
	return bit32.bxor(value, bit32.rshift(value, 16))
end

local function pick(pools: { [Slot]: { string | false } }, value: number): Picks
	local picks: { [string]: string } = {}
	for index, slot in AlienOutfit.SLOTS do
		local pool = pools[slot]
		if pool then
			local piece = pool[bit32.rshift(value, (index - 1) * 8) % #pool + 1]
			if piece then
				picks[slot] = piece
			end
		end
	end
	return picks :: Picks
end

-- The pieces of an alien of `tier` (1 Common … 5 Legendary, AlienConfig.TIER_POSITIONS) owned by
-- `ownerId` with `uid`.
function AlienOutfit.roll(ownerId: number, uid: number, tier: number): Picks
	local pools = assert(POOLS[tier], `No outfit pools for tier {tier}`)
	return pick(pools, AlienOutfit.hash(`{ownerId}:{uid}`))
end

-- The first piece of every pool of `tier`: what a pet's room on the island is measured with.
function AlienOutfit.first(tier: number): Picks
	return pick(assert(POOLS[tier], `No outfit pools for tier {tier}`), 0)
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
