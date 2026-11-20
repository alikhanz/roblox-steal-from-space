--!strict
-- The rejoin before Roblox's idle kick (decision 146): when the client asks, whether the server
-- agrees, where the player goes, and what the arriving server does. Pure: times, the player's
-- state and the place are passed in (RejoinConfig has the numbers).
--
-- The client only asks; the server agrees when it too sees the player away (Domain/Activity)
-- and no rejoin started lately. The time of the last one and whether the player stood on the
-- stand are kept in the profile (`Record`): the arriving server trusts that, never teleport
-- data, which passes through the client.

local Rejoin = {}

-- In the profile (v27).
export type Record = {
	-- Server time the last rejoin started; 0: never.
	at: number,
	-- The rejoin started and its player has not arrived on a server since.
	arriving: boolean,
	-- They stood on their stand when it started: the arriving server puts them back on it.
	onStand: boolean,
}

-- What the client does at an idle time.
export type Step = "None" | "Warn" | "Request"

export type Thresholds = {
	read warnAt: number,
	read requestAt: number,
}

-- Why the server ignores a request.
export type Refusal = "Active" | "Cooldown" | "Busy"

export type Ask = {
	-- The server's own view (ActivityService): the player is away.
	isAway: boolean,
	now: number,
	record: Record,
	-- When this server last tried a rejoin for the player; nil: never.
	lastTriedAt: number?,
	cooldownSeconds: number,
	retryGapSeconds: number,
}

-- Where a teleport goes: the very server the player is on (friends and the friend bonus stay),
-- the private server they are in, or any server of the place.
export type Target = "SameServer" | "PrivateServer" | "AnyServer"

export type Place = {
	-- A private server (a reserved one is not: it has no owner to come back to).
	isPrivate: boolean,
	-- The server has an instance id to come back to (none in Studio).
	hasInstance: boolean,
	-- Other players on the server: alone, the server closes as the player leaves.
	othersHere: number,
}

-- How the arriving player comes in: back on their stand, or just spawned.
export type Arrival = "Stand" | "Free"

function Rejoin.empty(): Record
	return { at = 0, arriving = false, onStand = false }
end

-- The client's step at `idleSeconds` without input.
function Rejoin.clientStep(idleSeconds: number, thresholds: Thresholds): Step
	if idleSeconds >= thresholds.requestAt then
		return "Request"
	elseif idleSeconds >= thresholds.warnAt then
		return "Warn"
	end
	return "None"
end

-- Nil when the server agrees to a request, else why not.
function Rejoin.refusal(ask: Ask): Refusal?
	if not ask.isAway then
		return "Active"
	end
	if ask.lastTriedAt and ask.now - ask.lastTriedAt < ask.retryGapSeconds then
		return "Busy"
	end
	-- A time ahead of `now` (another server's clock) counts as just now.
	if ask.record.at > 0 and ask.now - ask.record.at < ask.cooldownSeconds then
		return "Cooldown"
	end
	return nil
end

-- The record as a rejoin starts.
function Rejoin.started(now: number, onStand: boolean): Record
	return { at = now, arriving = true, onStand = onStand }
end

-- Where the first teleport goes.
function Rejoin.firstTarget(place: Place): Target
	if place.isPrivate then
		return "PrivateServer"
	elseif place.hasInstance and place.othersHere > 0 then
		return "SameServer"
	end
	return "AnyServer"
end

-- Where to try once the teleport to `target` failed; nil: nowhere, give up.
function Rejoin.fallback(target: Target): Target?
	return if target == "AnyServer" then nil else "AnyServer"
end

-- How a player with `record` arrives; nil when they did not come from a rejoin (or it started
-- too long ago to put them back anywhere).
function Rejoin.arrival(record: Record, now: number, restoreSeconds: number): Arrival?
	if not record.arriving or now - record.at > restoreSeconds then
		return nil
	end
	return if record.onStand then "Stand" else "Free"
end

-- The record once the player arrived (or the arrival is no longer waited for).
function Rejoin.landed(record: Record): Record
	return { at = record.at, arriving = false, onStand = false }
end

return table.freeze(Rejoin)
