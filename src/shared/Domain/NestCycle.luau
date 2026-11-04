--!strict
-- The life of one nest's egg. A nest holds at most one egg in the world: while its egg is
-- carried or lies knocked out, the nest stays empty, so a guardian never has two eggs to guard.
-- The nest grows a new egg only some time after the old one is delivered to a station; an
-- egg that was never delivered (it expired, its carrier left) simply goes back to the nest.
--
--   InNest ──take──> Away ──delivered──> Regrowing ──(respawn time passed)──> InNest
--                    Away ──returned───> InNest

local NestCycle = {}

export type State =
	{ kind: "InNest" }
	| { kind: "Away" }
	-- Waiting for a new egg to grow; `growAt` is on the same clock as `now`.
	| { kind: "Regrowing", growAt: number }

function NestCycle.inNest(): State
	return { kind = "InNest" }
end

-- The egg left the nest in a thief's hands. Only an egg that is there can be taken.
function NestCycle.take(state: State): State?
	if state.kind ~= "InNest" then
		return nil
	end
	return { kind = "Away" }
end

-- The nest's egg reached a station: a new one grows after `respawnSeconds`. Ignored unless the
-- nest's egg is away (a stray egg that only claims this nest does not start a new one).
function NestCycle.delivered(state: State, now: number, respawnSeconds: number): State
	if state.kind ~= "Away" then
		return state
	end
	return { kind = "Regrowing", growAt = now + respawnSeconds }
end

-- An egg of this nest goes back into it. Refused (nil) when the nest already holds one.
function NestCycle.returned(state: State): State?
	if state.kind == "InNest" then
		return nil
	end
	return { kind = "InNest" }
end

-- Whether a new egg is due now.
function NestCycle.shouldGrow(state: State, now: number): boolean
	return state.kind == "Regrowing" and now >= state.growAt
end

return table.freeze(NestCycle)
