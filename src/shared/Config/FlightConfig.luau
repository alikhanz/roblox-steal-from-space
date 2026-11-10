--!strict
-- Jetpack flight tuning and the instance and attribute names the flight code shares.

local Flight = require("../Domain/Flight")
local JetpackSwitch = require("../Domain/JetpackSwitch")

-- Top speed comes from the speed stat (SpeedConfig.FLIGHT), not from here.
local TUNING: Flight.Tuning = {
	response = 4,
	driftRetentionPerSecond = 0.6,
}

-- The jetpack under a dome (decision 096): a double jump switches it, landing switches it off.
local SWITCH: JetpackSwitch.Tuning = {
	doubleTapSeconds = 0.4,
	minReleaseSeconds = 0.05,
	landPushSpeed = 4,
	landStillSpeed = 1,
}

return table.freeze({
	TUNING = table.freeze(TUNING),
	SWITCH = table.freeze(SWITCH),
	-- Force budget for the velocity and orientation constraints; large enough to cancel gravity.
	MAX_FORCE = 1e6,
	ALIGN_RESPONSIVENESS = 40,

	-- Instance names under HumanoidRootPart.
	ATTACHMENT_NAME = "JetpackAttachment",
	VELOCITY_NAME = "JetpackVelocity",
	ALIGN_NAME = "JetpackAlign",

	-- Character attribute: true while outside the dome (read by the HUD).
	IN_SPACE_ATTRIBUTE = "InSpace",
	-- Character attribute: true while the jetpack is on, in space and flying under a dome
	-- (decision 096). Flight, its pose, the flame and the flight buttons follow it.
	JETPACK_ON_ATTRIBUTE = "JetpackOn",
	-- Character attributes of the double jump that switches it (Domain/JetpackSwitch): jump held,
	-- seconds since it was let go, seconds left for the second tap.
	JUMP_HELD_ATTRIBUTE = "JumpHeld",
	JUMP_RELEASED_ATTRIBUTE = "JumpReleasedFor",
	JUMP_TAP_WINDOW_ATTRIBUTE = "JumpTapWindow",
	-- Player attribute: has flown under a dome (from the profile); until then the client shows
	-- the double-jump hint on spawning. Nil until the profile is loaded.
	DOME_FLIGHT_LEARNED_ATTRIBUTE = "DomeFlightLearned",
	-- Character attributes of slow mode (the simulation toggles it on each press of its key):
	-- on or off, and whether the key was down last step.
	SLOW_MODE_ATTRIBUTE = "SlowMode",
	SLOW_MODE_HELD_ATTRIBUTE = "SlowModeHeld",
	-- Workspace attribute: while set, nobody flies farther than this from the dome center
	-- (studs), like at the edge of the map. The solar storm sets it to the station border.
	RANGE_LIMIT_ATTRIBUTE = "FlightRangeLimit",
})
