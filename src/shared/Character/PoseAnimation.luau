--!strict
-- Turns pose data (joint rotations of an R15 rig, see FlightPose and StrikePose) into a
-- KeyframeSequence: the source uploaded as an animation asset.
-- Rotation axes follow the R15 joint frames: +X tips a limb forward (arms up in front, torso
-- back), -X tips it backward; +Y turns a part to the character's left; +Z swings a limb towards
-- the character's right.

export type Rotation = { x: number, y: number, z: number }
-- Part name -> rotation of the joint that drives that part. Missing parts keep their rest pose.
export type Joints = { [string]: Rotation }
export type Frame = { time: number, pose: Joints, rootOffsetY: number }

export type Spec = {
	name: string,
	loop: boolean,
	priority: Enum.AnimationPriority,
	keyframes: { Frame },
}

local PoseAnimation = {}

function PoseAnimation.rotation(x: number, y: number, z: number): Rotation
	return { x = x, y = y, z = z }
end

-- A copy of `base` with some parts' rotations replaced.
function PoseAnimation.with(base: Joints, changes: Joints): Joints
	local pose = table.clone(base)
	for part, rotation in changes do
		pose[part] = rotation
	end
	return pose
end

-- R15 hierarchy: each part's pose is nested under its parent part's pose.
PoseAnimation.HIERARCHY = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
} :: { [string]: string }

local function toCFrame(rotation: Rotation): CFrame
	return CFrame.Angles(math.rad(rotation.x), math.rad(rotation.y), math.rad(rotation.z))
end

local function buildKeyframe(data: Frame): Keyframe
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
		local parentName = PoseAnimation.HIERARCHY[partName]
		pose.Parent = if parentName then poseFor(parentName) else keyframe
		poses[partName] = pose
		return pose
	end

	for partName in PoseAnimation.HIERARCHY do
		poseFor(partName)
	end
	return keyframe
end

function PoseAnimation.build(spec: Spec): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = spec.name
	sequence.Loop = spec.loop
	sequence.Priority = spec.priority
	for _, data in spec.keyframes do
		buildKeyframe(data).Parent = sequence
	end
	return sequence
end

return table.freeze(PoseAnimation)
