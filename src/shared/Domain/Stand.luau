--!strict
-- The jetpack stand (docs/design/screens/jetpack-stand.md): where a player is with it, how hard
-- it pulls them on and how big its flame burns. Pure Luau.
--
-- A player who walks into the stand's zone is "Boarding": pulled onto the platform while still
-- holding the move input they walked in with. Once that input is let go they are "On". A jump
-- or a new move input takes them off: "Left", which lasts while they are still in the zone, so
-- the stand never pulls back someone who just stepped off.

local Stand = {}

export type State = "Boarding" | "On" | "Left"

export type Input = {
	-- In the stand's zone (and allowed on it: their own stand, walking).
	read inZone: boolean,
	read moving: boolean,
	read jumping: boolean,
}

local STATES: { [string]: State } = { Boarding = "Boarding", On = "On", Left = "Left" }

-- A state from an attribute's value: nil for anything else.
function Stand.parse(value: unknown): State?
	return if type(value) == "string" then STATES[value] else nil
end

function Stand.next(state: State?, input: Input): State?
	if not input.inZone then
		return nil
	end
	if state == nil then
		return "Boarding"
	elseif state == "Left" then
		return "Left"
	elseif input.jumping then
		return "Left"
	elseif state == "Boarding" then
		return if input.moving then "Boarding" else "On"
	end
	return if input.moving then "Left" else "On"
end

-- True while the stand holds the player and they train.
function Stand.isTraining(state: State?): boolean
	return state == "Boarding" or state == "On"
end

-- The velocity that pulls a player at `position` onto `target`: there in about `seconds`, never
-- faster than `maxSpeed`.
function Stand.pullVelocity(position: Vector3, target: Vector3, seconds: number, maxSpeed: number): Vector3
	assert(seconds > 0, "pull seconds must be positive")
	local velocity = (target - position) / seconds
	if velocity.Magnitude > maxSpeed then
		return velocity.Unit * maxSpeed
	end
	return velocity
end

-- How many times bigger the flame burns at trainer `level`: 1 at level 0, `maxScale` from
-- `fullLevel` on, logarithmic in between.
function Stand.flameScale(level: number, maxScale: number, fullLevel: number): number
	assert(fullLevel > 0, "full level must be positive")
	local share = math.clamp(math.log(1 + math.max(level, 0)) / math.log(1 + fullLevel), 0, 1)
	return 1 + (maxScale - 1) * share
end

return table.freeze(Stand)
