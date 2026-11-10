--!strict
-- The jetpack stand (docs/design/screens/jetpack-stand.md): where a player is with it, how hard
-- it pulls them on and how big its flame burns. Pure Luau.
--
-- A player who walks into the stand's zone is "Boarding": pulled onto the platform while still
-- holding the move input they walked in with. Once that input is let go they are "On". Someone
-- jumping onto it is taken once they land, not in the air (caught mid-fall, they floated down
-- in the training pose). A jump or a new move input takes them off: "Left", which lasts while
-- they are still in the zone, so the stand never pulls back someone who just stepped off — until
-- they stand still on the platform itself again, and it takes them back on.

local Stand = {}

export type State = "Boarding" | "On" | "Left"

export type Input = {
	-- In the stand's zone (and allowed on it: their own stand, walking).
	read inZone: boolean,
	-- On the platform itself: the zone without its tolerance ring.
	read onPlatform: boolean,
	-- Standing on a floor, not in the air.
	read grounded: boolean,
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
		return if input.grounded and not input.jumping then "Boarding" else nil
	elseif state == "Left" then
		local settled = input.onPlatform and input.grounded and not input.moving and not input.jumping
		return if settled then "Boarding" else "Left"
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

-- Which look of the stand trainer `level` has (decision 091): the index of the last tier in
-- `tierStarts` (the level each tier starts at, ascending, the first 0) that the level has
-- reached. Levels have no end; past the last start the stand stays on the last tier, the top.
function Stand.tier(level: number, tierStarts: { number }): number
	assert(#tierStarts > 0 and tierStarts[1] == 0, "the first tier starts at level 0")
	local tier = 1
	for index, start in tierStarts do
		assert(index == 1 or start > tierStarts[index - 1], "tiers start in ascending order")
		if level >= start then
			tier = index
		end
	end
	return tier
end

-- How many of the dial's `lamps` burn at trainer `level`: one a level, all of them from `lamps` on.
function Stand.dialLit(level: number, lamps: number): number
	return math.clamp(math.floor(level), 0, lamps)
end

return table.freeze(Stand)
