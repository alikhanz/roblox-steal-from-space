--!strict
-- The star serpent's hunt for its egg (decision 055): where the star egg is, and so what the
-- serpent does. Pure Luau.
--
--   Inside(hits) ──(the hitsToDrop-th hit)──> Out       the egg flies out of the serpent
--   Out ──(it left play undelivered: lay loose too long, its carrier left)──> Inside(0)
--   Out ──(delivered to a bay)──> Delivered
--
-- With the egg inside the serpent flees whoever comes near; with the egg out it guards it like
-- a guardian (hovers over it lying loose, chases whoever carries it); once it is delivered the
-- serpent leaves and the event ends early.

local SerpentHunt = {}

export type EggPlace = "Inside" | "Out" | "Delivered"

export type State = {
	read egg: EggPlace,
	-- Hits landed on the serpent since the egg was last inside it.
	read hits: number,
}

export type Behavior = "Flee" | "Guard" | "Leave"

-- What the end of the hunt's time means for the egg.
export type Ending =
	-- Still inside: the serpent takes it away.
	"TookEgg"
	-- Lying loose: it is gone.
	| "EggLost"
	-- In a player's hands: they keep it and may bring it home in peace.
	| "EggKept"
	-- Already delivered.
	| "Delivered"

function SerpentHunt.start(): State
	return { egg = "Inside", hits = 0 }
end

-- A hit on the serpent. Returns the new state and true if this hit knocked the egg out.
function SerpentHunt.hit(state: State, hitsToDrop: number): (State, boolean)
	if state.egg ~= "Inside" then
		return state, false
	end
	local hits = state.hits + 1
	if hits >= hitsToDrop then
		return { egg = "Out", hits = hits }, true
	end
	return { egg = "Inside", hits = hits }, false
end

-- The egg left play without being delivered: it is back inside the serpent, hits from scratch.
function SerpentHunt.returned(state: State): State
	if state.egg ~= "Out" then
		return state
	end
	return SerpentHunt.start()
end

function SerpentHunt.delivered(state: State): State
	if state.egg ~= "Out" then
		return state
	end
	return { egg = "Delivered", hits = state.hits }
end

function SerpentHunt.behavior(state: State): Behavior
	if state.egg == "Inside" then
		return "Flee"
	elseif state.egg == "Out" then
		return "Guard"
	end
	return "Leave"
end

-- The hunt's time is up; `carried`: someone holds the egg right now.
function SerpentHunt.ending(state: State, carried: boolean): Ending
	if state.egg == "Inside" then
		return "TookEgg"
	elseif state.egg == "Delivered" then
		return "Delivered"
	end
	return if carried then "EggKept" else "EggLost"
end

return table.freeze(SerpentHunt)
