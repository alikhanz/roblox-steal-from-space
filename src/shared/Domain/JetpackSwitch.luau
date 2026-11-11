--!strict
-- Whether the jetpack is on (decision 096). Pure Luau.
--
-- Out in space it always is. Under a dome (the central station, the islands) a double jump
-- switches it: two taps of jump (or up, while flying) within `doubleTapSeconds`. A flyer coming
-- in from space keeps flying; it goes off on the next double tap, or on landing: feet on a floor
-- while not climbing. A flyer never sinks into a floor: near one, the descent is held to what
-- reaches it in one step (the jetpack's force would push a fast flyer through a thin platform).
--
-- Roblox lets go of the jump input for a step whenever the character starts a jump, so a held
-- jump would read as taps; a tap counts only after the input was let go for `minReleaseSeconds`.

local JetpackSwitch = {}

export type State = {
	read on: boolean,
	-- Jump (or up) held, as far as taps go: stays held through a release shorter than
	-- `minReleaseSeconds`.
	read held: boolean,
	-- Seconds since jump was let go, up to `minReleaseSeconds` (no further: it is kept in an
	-- attribute, and a value that stops changing is not written again).
	read releasedFor: number,
	-- After a first tap, the seconds still left for the second; 0 without one.
	read tapWindow: number,
}

export type Input = {
	read inSpace: boolean,
	-- Jump or up pressed now.
	read pressed: boolean,
	-- Feet on a floor, not climbing (JetpackSwitch.isLanding).
	read landed: boolean,
}

export type Tuning = {
	-- The most seconds between the two taps of a double jump.
	read doubleTapSeconds: number,
	-- The least seconds jump must be let go between two taps.
	read minReleaseSeconds: number,
	-- Landing: feet at most this far above a floor, studs ...
	read landGap: number,
	-- ... while rising no faster than this, studs per second.
	read landRiseSpeed: number,
}

-- A fresh character: walking, jump long let go.
function JetpackSwitch.initial(tuning: Tuning): State
	return { on = false, held = false, releasedFor = tuning.minReleaseSeconds, tapWindow = 0 }
end

function JetpackSwitch.step(state: State, input: Input, deltaTime: number, tuning: Tuning): State
	local releasedFor = if input.pressed then 0 else math.min(state.releasedFor + deltaTime, tuning.minReleaseSeconds)
	local held = input.pressed or (state.held and releasedFor < tuning.minReleaseSeconds)
	local tap = input.pressed and not state.held
	local window = math.max(state.tapWindow - deltaTime, 0)
	local on = state.on

	if input.inSpace then
		-- Always on out there; taps in space do not start a double jump.
		on, window = true, 0
	elseif tap then
		if window > 0 then
			on, window = not on, 0
		else
			window = tuning.doubleTapSeconds
		end
	elseif on and input.landed then
		on, window = false, 0
	end
	return { on = on, held = held, releasedFor = releasedFor, tapWindow = window }
end

-- Whether a flyer is landing: a floor `gap` studs under the feet (nil: none within reach), close
-- enough, while the body (`velocityY`) is not climbing and up is not held.
function JetpackSwitch.isLanding(gap: number?, velocityY: number, ascending: boolean, tuning: Tuning): boolean
	return gap ~= nil and gap <= tuning.landGap and velocityY <= tuning.landRiseSpeed and not ascending
end

-- How far under the feet to look for a floor, studs: the landing gap, and twice what a step falls
-- at `velocityY`, so a fast flyer sees the floor a step before it would reach it.
function JetpackSwitch.floorReach(velocityY: number, deltaTime: number, tuning: Tuning): number
	return tuning.landGap + math.max(-velocityY, 0) * deltaTime * 2
end

-- The vertical velocity a flyer may keep with a floor `gap` studs under the feet (nil: none within
-- reach): never more descent than reaches the floor in one step.
function JetpackSwitch.limitDescent(velocityY: number, gap: number?, deltaTime: number): number
	if gap == nil or deltaTime <= 0 then
		return velocityY
	end
	return math.max(velocityY, -math.max(gap, 0) / deltaTime)
end

return table.freeze(JetpackSwitch)
