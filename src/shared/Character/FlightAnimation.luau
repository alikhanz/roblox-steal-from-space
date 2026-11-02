--!strict
-- Turns the FlightPose data into a playable animation and resolves its id.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local FlightPose = require("./FlightPose")
local JetpackConfig = require("../Config/JetpackConfig")

local FlightAnimation = {}

local function toCFrame(rotation: FlightPose.Rotation): CFrame
	return CFrame.Angles(math.rad(rotation.x), math.rad(rotation.y), math.rad(rotation.z))
end

local function buildKeyframe(data: FlightPose.Keyframe): Keyframe
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = data.time

	local poses: { [string]: Pose } = {}
	local function poseFor(partName: string): Pose
		local existing = poses[partName]
		if existing then
			return existing
		end
		local pose = Instance.new("Pose")
		pose.Name = partName
		pose.Weight = 1
		local rotation = data.pose[partName]
		pose.CFrame = if rotation then toCFrame(rotation) else CFrame.identity
		if partName == "LowerTorso" then
			pose.CFrame = CFrame.new(0, data.rootOffsetY, 0) * pose.CFrame
		end
		local parentName = FlightPose.HIERARCHY[partName]
		pose.Parent = if parentName then poseFor(parentName) else keyframe
		poses[partName] = pose
		return pose
	end

	for partName in FlightPose.HIERARCHY do
		poseFor(partName)
	end
	return keyframe
end

-- The pose as a looping KeyframeSequence (also the source to upload as an animation asset).
function FlightAnimation.buildSequence(): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = FlightPose.NAME
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Action
	for _, data in FlightPose.KEYFRAMES do
		buildKeyframe(data).Parent = sequence
	end
	return sequence
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
