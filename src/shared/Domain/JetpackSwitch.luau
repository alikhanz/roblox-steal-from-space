--!strict
-- Whether the jetpack is on (decision 096). Pure Luau.
--
-- Out in space it always is. Under a dome (the central station, the islands) a double jump
-- switches it: two taps of jump (or up, while flying) within `doubleTapSeconds`. A flyer coming
-- in from space keeps flying; it goes off on the next double tap, or on landing: pushing down
-- while the floor holds the body up.
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
	-- Pushing down onto a floor (JetpackSwitch.isLanding).
	read landed: boolean,
}

export type Tuning = {
	-- The most seconds between the two taps of a double jump.
	read doubleTapSeconds: number,
	-- The least seconds jump must be let go between two taps.
	read minReleaseSeconds: number,
	-- Landing: pushing down at least this fast (studs per second) ...
	read landPushSpeed: number,
	-- ... while the body falls slower than this (the floor holds it).
	read landStillSpeed: number,
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

-- Whether a flyer is landing: holding down, the jetpack pushing down at least `landPushSpeed`
-- (`pushY`, the velocity it was told to keep), yet the body (`velocityY`) barely falling — a
-- floor is in the way.
function JetpackSwitch.isLanding(descending: boolean, pushY: number, velocityY: number, tuning: Tuning): boolean
	return descending and pushY <= -tuning.landPushSpeed and velocityY > -tuning.landStillSpeed
end

return table.freeze(JetpackSwitch)
