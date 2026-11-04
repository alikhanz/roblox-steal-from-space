--!strict
-- Turns the FlightPose data into a playable animation and resolves its id.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local FlightPose = require("./FlightPose")
local JetpackConfig = require("../Config/JetpackConfig")
local PoseAnimation = require("./PoseAnimation")

local FlightAnimation = {}

-- The pose as a looping KeyframeSequence (also the source to upload as an animation asset).
function FlightAnimation.buildSequence(): KeyframeSequence
	return PoseAnimation.build({
		name = FlightPose.NAME,
		loop = true,
		priority = Enum.AnimationPriority.Action,
		keyframes = FlightPose.KEYFRAMES,
	})
end

-- The uploaded animation if configured; in Studio, the pose registered on the fly (the server and
-- every client register the same data and get the same id). Nil in live games without an upload.
function FlightAnimation.resolveId(): string?
	if JetpackConfig.FLIGHT_ANIMATION_ID ~= "" then
		return JetpackConfig.FLIGHT_ANIMATION_ID
	end
	if not RunService:IsStudio() then
		return nil
	end
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(FlightAnimation.buildSequence())
	end)
	if not ok then
		warn(`[FlightAnimation] Could not register the flight pose in Studio: {result}`)
		return nil
	end
	return result
end

return table.freeze(FlightAnimation)
