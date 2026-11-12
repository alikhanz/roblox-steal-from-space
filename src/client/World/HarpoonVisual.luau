--!strict
-- One harpoon shot on this client (brief docs/design/screens/pvp-abilities.md, "Гарпун на
-- тросе"). A launcher appears on the shooter's right wrist; the hook flies from its muzzle on a
-- cable (two Beams) with a short Trail. On a hit its claws close and a ring flashes; if an egg
-- came loose the hook rides it as it drifts towards the shooter (the loose egg found by its tag,
-- or the drift worked out when it is not here), then lets go and reels in. A miss hangs at the
-- end of the reach, the cable sagging, and reels in empty. The server decided everything before
-- this starts (PvpService); this only shows it.
-- The hook flies out and reels in relative to the shooter (decision 103): it covers the way from
-- the muzzle to its goal in a set time wherever the shooter flies meanwhile, and a miss's end of
-- the reach moves with the shooter, so at full flight speed it still goes ahead, not behind.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local PvpFx = require(ReplicatedStorage.Shared.Domain.PvpFx)
local PvpKit = require(script.Parent.PvpKit)
local PvpLooks = require(ReplicatedStorage.Shared.Config.PvpLooks)

local LOOK = PvpLooks.HARPOON
-- The launcher sits on this hand when the rig has one.
local HAND_NAME = "RightHand"
-- The claws close this far in front of a loose egg's middle, towards the shooter.
local GRIP_STUDS = 0.6
local FLASH_THICKNESS = 0.25
-- Whatever happens, a shot is over by then.
local LONGEST_SECONDS = 4

export type Shot = {
	shooter: Player,
	target: Vector3,
	aim: Vector3,
	hit: boolean,
	egg: boolean,
}

-- Steps the shot by `deltaTime`; false once it is over and gone.
export type Effect = {
	step: (deltaTime: number) -> boolean,
}

type Phase = "Out" | "Grab" | "Ride" | "Hang" | "Back"

local HarpoonVisual = {}

local function handOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local hand = character:FindFirstChild(HAND_NAME) or character:FindFirstChild("HumanoidRootPart")
	return if hand and hand:IsA("BasePart") then hand else nil
end

local function nearestLooseEgg(near: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = LOOK.eggSearchStuds
	for _, egg in CollectionService:GetTagged(EggConfig.LOOSE_EGG_TAG) do
		if egg:IsA("BasePart") then
			local distance = (egg.Position - near).Magnitude
			if distance <= bestDistance then
				best, bestDistance = egg, distance
			end
		end
	end
	return best
end

-- An attachment on `piece` at `at`, given from the piece's group speck.
local function attach(piece: PvpKit.Piece, at: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.CFrame = piece.offset:Inverse() * at
	attachment.Parent = piece.part
	return attachment
end

local function beam(from: Attachment, to: Attachment, color: Color3, width: number, transparency: number): Beam
	local instance = Instance.new("Beam")
	instance.Attachment0 = from
	instance.Attachment1 = to
	instance.Color = ColorSequence.new(color)
	instance.Width0 = width
	instance.Width1 = width
	instance.Transparency = NumberSequence.new(transparency)
	instance.LightEmission = 1
	instance.LightInfluence = 0
	instance.Brightness = 2
	instance.FaceCamera = true
	instance.Segments = 12
	instance.Parent = from.Parent
	return instance
end

local function trail(from: Attachment, to: Attachment): Trail
	local instance = Instance.new("Trail")
	instance.Attachment0 = from
	instance.Attachment1 = to
	instance.Color = ColorSequence.new(LOOK.color)
	instance.Transparency = NumberSequence.new(0.3, 1)
	instance.Lifetime = LOOK.trail.lifetime
	instance.LightEmission = 1
	instance.LightInfluence = 0
	instance.FaceCamera = true
	instance.Parent = from.Parent
	return instance
end

-- A frame at `position` looking along `direction` (any frame when it has no length).
local function facing(position: Vector3, direction: Vector3): CFrame
	if direction.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + direction)
end

function HarpoonVisual.new(shot: Shot, folder: Instance): Effect?
	local hand = handOf(shot.shooter)
	if not hand then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Harpoon"
	model.Parent = folder

	local launcherBody = PvpKit.piece("LauncherBody", model)
	local launcherGlow = PvpKit.piece("LauncherGlow", model, LOOK.color)
	local hookBody = PvpKit.piece("HookBody", model)
	local hookGlow = PvpKit.piece("HookGlow", model, LOOK.color)
	local clawsOpen = PvpKit.piece("ClawsOpen", model)
	local clawsClosed = PvpKit.piece("ClawsClosed", model)
	local flash = PvpKit.piece("Ring", model, LOOK.color)
	clawsClosed.part.Transparency = 1
	flash.part.Transparency = 1

	local muzzleAt = PvpKit.point("Muzzle")
	local backAt = PvpKit.point("HookBack")
	local cableStart = attach(launcherBody, muzzleAt)
	local cableEnd = attach(hookBody, backAt)
	local cables = {
		beam(cableStart, cableEnd, LOOK.coreColor, LOOK.cableWidth, 0),
		beam(cableStart, cableEnd, LOOK.color, LOOK.cableGlowWidth, LOOK.cableGlowTransparency),
	}
	local half = LOOK.trail.width / 2
	local hookTrail =
		trail(attach(hookBody, backAt * CFrame.new(-half, 0, 0)), attach(hookBody, backAt * CFrame.new(half, 0, 0)))

	local launcherPieces = { launcherBody, launcherGlow }
	local hookPieces = { hookBody, hookGlow, clawsOpen, clawsClosed }

	local phase: Phase = "Out"
	local phaseTime = 0
	local elapsed = 0
	local egg: BasePart? = nil
	local eggSpeed = math.huge
	local lastEggPosition: Vector3? = nil
	local flashAt: CFrame? = nil
	local flashTime = 0
	local sag = 0
	local aim = if shot.aim.Magnitude > 1e-3 then shot.aim.Unit else hand.CFrame.LookVector
	-- A miss's end of the reach, carried along with the shooter.
	local function missEnd(): Vector3
		return hand.Position + aim * PvpConfig.HARPOON.rangeStuds
	end
	local firstGoal = if shot.hit then shot.target else missEnd()
	local hookPosition = (CFrame.lookAt(hand.Position, firstGoal) * muzzleAt).Position
	-- The way out, and the hook's place relative to the hand as it starts reeling in.
	local outDistance = math.max((firstGoal - hookPosition).Magnitude, 1)
	local backOffset = hookPosition - hand.Position
	local backDistance = 1

	local function enter(next: Phase)
		phase = next
		phaseTime = 0
		if next == "Back" then
			backOffset = hookPosition - hand.Position
			backDistance = math.max(backOffset.Magnitude, 1)
		end
		local isClosed = shot.hit and next ~= "Out"
		clawsOpen.part.Transparency = if isClosed then 1 else 0
		clawsClosed.part.Transparency = if isClosed then 0 else 1
		hookTrail.Enabled = next == "Out" or next == "Back"
	end

	-- Where the loose egg is now: the real one once found, else its drift worked out from where
	-- the hook landed towards the shooter.
	local function eggPosition(): Vector3
		if not egg and shot.egg then
			egg = nearestLooseEgg(shot.target)
		end
		local found = egg
		if found and found.Parent then
			return found.Position
		end
		local toShooter = hand.Position - shot.target
		if toShooter.Magnitude < 1e-3 then
			return shot.target
		end
		local drifted = PvpFx.driftDistance(EggConfig.DROP_SPEED, EggConfig.DROP_RETENTION_PER_SECOND, elapsed)
		return shot.target + toShooter.Unit * math.min(drifted, toShooter.Magnitude)
	end

	-- Where the claws grip a loose egg: just in front of it, towards the shooter.
	local function grip(): Vector3
		local at = eggPosition()
		local toShooter = hand.Position - at
		return if toShooter.Magnitude > GRIP_STUDS then at + toShooter.Unit * GRIP_STUDS else at
	end

	local function finish(): boolean
		model:Destroy()
		return false
	end

	local function step(deltaTime: number): boolean
		if hand.Parent == nil or elapsed > LONGEST_SECONDS then
			return finish()
		end
		elapsed += deltaTime
		phaseTime += deltaTime
		local launcherFrame = facing(hand.Position, hookPosition - hand.Position)
		local muzzle = (launcherFrame * muzzleAt).Position

		if phase == "Out" then
			local goal = if not shot.hit then missEnd() elseif shot.egg then grip() else shot.target
			local share = math.min(phaseTime * LOOK.hookSpeed / outDistance, 1)
			hookPosition = muzzle:Lerp(goal, share)
			if share >= 1 then
				if shot.hit then
					flashAt = facing(goal, goal - muzzle) * CFrame.Angles(math.pi / 2, 0, 0)
					flashTime = 0
					enter("Grab")
				else
					enter("Hang")
				end
			end
		elseif phase == "Grab" then
			hookPosition = if shot.egg then grip() else hookPosition
			if phaseTime >= LOOK.grabSeconds then
				enter(if shot.egg then "Ride" else "Back")
			end
		elseif phase == "Ride" then
			hookPosition = grip()
			local now = eggPosition()
			if lastEggPosition and deltaTime > 0 then
				eggSpeed = (now - lastEggPosition).Magnitude / deltaTime
			end
			lastEggPosition = now
			if phaseTime >= LOOK.rideSeconds or eggSpeed < LOOK.rideRestSpeed then
				enter("Back")
			end
		elseif phase == "Hang" then
			hookPosition = missEnd()
			sag = LOOK.missSagStuds * math.min(phaseTime / LOOK.missHoldSeconds, 1)
			if phaseTime >= LOOK.missHoldSeconds then
				enter("Back")
			end
		else
			-- Reeled in by the cable: from where it let go, carried along with the shooter.
			local share = phaseTime * LOOK.retractSpeed / backDistance
			if share >= 1 then
				return finish()
			end
			hookPosition = (hand.Position + backOffset):Lerp(muzzle, share)
		end

		-- The hook points away from the shooter, out or back.
		launcherFrame = facing(hand.Position, hookPosition - hand.Position)
		muzzle = (launcherFrame * muzzleAt).Position
		local hookFrame = facing(hookPosition, hookPosition - muzzle)
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for _, piece in launcherPieces do
			table.insert(parts, piece.part)
			table.insert(frames, launcherFrame * piece.offset)
		end
		for _, piece in hookPieces do
			table.insert(parts, piece.part)
			table.insert(frames, hookFrame * piece.offset)
		end

		local radius, transparency = nil, 1
		if flashAt then
			flashTime += deltaTime
			radius, transparency = PvpFx.burst(flashTime, LOOK.flash.seconds, LOOK.flash.from, LOOK.flash.to)
		end
		if radius and flashAt then
			PvpKit.sizeRing(flash, radius, FLASH_THICKNESS)
			flash.part.Transparency = transparency
			table.insert(parts, flash.part)
			table.insert(frames, flashAt * flash.offset)
		else
			flash.part.Transparency = 1
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)

		-- A miss's cable sags: the Beams' curve pulls down from both ends.
		for _, cable in cables do
			cable.CurveSize0 = sag
			cable.CurveSize1 = sag
		end
		if sag > 0 then
			local hookBack = (hookFrame * backAt).Position
			cableStart.WorldCFrame = CFrame.fromMatrix(muzzle, -Vector3.yAxis, Vector3.xAxis)
			cableEnd.WorldCFrame = CFrame.fromMatrix(hookBack, Vector3.yAxis, Vector3.xAxis)
		end
		return true
	end

	enter("Out")
	return { step = step }
end

return table.freeze(HarpoonVisual)
