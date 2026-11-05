--!strict
-- Puts an R15 character into a pose (joint rotations, as in PoseAnimation) by moving its parts
-- directly, the way an animation would place them: each part sits on its joint's attachments
-- under its parent, turned by the pose. For a body nothing animates any more (one that died
-- in space and is frozen, SpaceService). Parts that are not limbs (accessories, the jetpack)
-- move with the limb they are fastened to. Anchor the parts first: this only places them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PoseAnimation = require(ReplicatedStorage.Shared.Character.PoseAnimation)

local RigPose = {}

local function toCFrame(rotation: PoseAnimation.Rotation): CFrame
	return CFrame.Angles(math.rad(rotation.x), math.rad(rotation.y), math.rad(rotation.z))
end

-- Limbs from the root outwards, so every parent is placed before its children.
local function limbOrder(): { string }
	local depth: { [string]: number } = {}
	local function depthOf(name: string): number
		local known = depth[name]
		if known then
			return known
		end
		local parent = PoseAnimation.HIERARCHY[name]
		local value = if parent then depthOf(parent) + 1 else 0
		depth[name] = value
		return value
	end
	local names: { string } = {}
	for name in PoseAnimation.HIERARCHY do
		depthOf(name)
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		return depth[a] < depth[b]
	end)
	return names
end
local LIMB_ORDER = limbOrder()

-- The attachments of the joint that drives `limb` (an AnimationConstraint or Motor6D under
-- it): on its parent and on itself.
local function jointOf(limb: BasePart): (CFrame?, CFrame?)
	for _, child in limb:GetChildren() do
		if child:IsA("AnimationConstraint") then
			local onParent, onLimb = child.Attachment0, child.Attachment1
			if onParent and onLimb then
				return onParent.CFrame, onLimb.CFrame
			end
		elseif child:IsA("Motor6D") then
			return child.C0, child.C1
		end
	end
	return nil, nil
end

-- The two parts a fastening (a weld or a rigid constraint) holds together, if it is one.
local function fastenedParts(item: Instance): (BasePart?, BasePart?)
	local a: Instance?, b: Instance? = nil, nil
	if item:IsA("WeldConstraint") or item:IsA("JointInstance") then
		a, b = item.Part0, item.Part1
	elseif item:IsA("RigidConstraint") then
		a = if item.Attachment0 then item.Attachment0.Parent else nil
		b = if item.Attachment1 then item.Attachment1.Parent else nil
	end
	if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
		return a, b
	end
	return nil, nil
end

-- For every part that is not a limb, the limb it hangs on through its fastenings.
local function owners(character: Model, limbs: { [string]: BasePart }): { [BasePart]: BasePart }
	local links: { [BasePart]: { BasePart } } = {}
	local function link(a: BasePart, b: BasePart)
		links[a] = links[a] or {}
		table.insert(links[a], b)
	end
	for _, item in character:GetDescendants() do
		local a, b = fastenedParts(item)
		if a and b then
			link(a, b)
			link(b, a)
		end
	end
	local owner: { [BasePart]: BasePart } = {}
	local queue: { BasePart } = {}
	for _, limb in limbs do
		owner[limb] = limb
		table.insert(queue, limb)
	end
	local index = 1
	while index <= #queue do
		local part = queue[index]
		index += 1
		for _, other in links[part] or {} do
			if not owner[other] then
				owner[other] = owner[part]
				table.insert(queue, other)
			end
		end
	end
	return owner
end

-- Places `character`'s parts in `pose`, its root where it is.
function RigPose.apply(character: Model, pose: PoseAnimation.Joints)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local limbs: { [string]: BasePart } = { HumanoidRootPart = root }
	for name in PoseAnimation.HIERARCHY do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			limbs[name] = limb
		end
	end

	local before: { [BasePart]: CFrame } = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			before[part] = part.CFrame
		end
	end

	local placed: { [BasePart]: CFrame } = { [root] = root.CFrame }
	for _, name in LIMB_ORDER do
		local limb = limbs[name]
		local parentName = PoseAnimation.HIERARCHY[name]
		local parent = if parentName then limbs[parentName] else nil
		local onParent: CFrame?, onLimb: CFrame? = nil, nil
		if limb then
			-- Both of jointOf's values: an if-expression would keep only the first.
			onParent, onLimb = jointOf(limb)
		end
		if limb and parent and placed[parent] and onParent and onLimb then
			local rotation = pose[name]
			local turn = if rotation then toCFrame(rotation) else CFrame.identity
			placed[limb] = placed[parent] * onParent * turn * onLimb:Inverse()
		end
	end

	-- Everything else keeps its place on the limb it hangs on.
	for part, limb in owners(character, limbs) do
		if not placed[part] and placed[limb] then
			placed[part] = placed[limb] * before[limb]:ToObjectSpace(before[part])
		end
	end

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for part, frame in placed do
		table.insert(parts, part)
		table.insert(frames, frame)
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

return table.freeze(RigPose)
