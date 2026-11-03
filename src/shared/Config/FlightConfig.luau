--!strict
-- Jetpack flight tuning and the instance and attribute names the flight code shares.

local Flight = require("../Domain/Flight")

-- Top speed comes from the speed stat (SpeedConfig.FLIGHT), not from here.
local TUNING: Flight.Tuning = {
	response = 4,
	driftRetentionPerSecond = 0.6,
}

return table.freeze({
	TUNING = table.freeze(TUNING),
	-- Force budget for the velocity and orientation constraints; large enough to cancel gravity.
	MAX_FORCE = 1e6,
	ALIGN_RESPONSIVENESS = 40,

	-- Instance names under HumanoidRootPart.
	ATTACHMENT_NAME = "JetpackAttachment",
	VELOCITY_NAME = "JetpackVelocity",
	ALIGN_NAME = "JetpackAlign",

	-- Character attribute: true while outside the dome (read by the HUD).
	IN_SPACE_ATTRIBUTE = "InSpace",
})
