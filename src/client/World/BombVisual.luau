--!strict
-- One gravity bomb on this client (brief docs/design/screens/pvp-abilities.md, "Гравибомба
-- «гироскоп»"). In flight: a dark core with a lit belt and a light, two violet orbits tumbling
-- round it and a Trail behind; the orbits spin and the light blinks faster towards the end of the
-- fuse, and close in on the core over its last moments (Domain/PvpFx.bombCharge). It flies as on
-- the server (World/BombFlight): from the throw with the thrower's velocity, homing on the same
-- target (decision 106), and is put where the server says it went off. The blast: a flash at the centre and a flat ring wave out to the blast's radius
-- (PvpFx.wave), so what it reached is plain to see.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Homing = require(ReplicatedStorage.Shared.Domain.Homing)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local PvpFx = require(ReplicatedStorage.Shared.Domain.PvpFx)
local PvpKit = require(script.Parent.PvpKit)
local PvpLooks = require(ReplicatedStorage.Shared.Config.PvpLooks)

local LOOK = PvpLooks.BOMB
-- How the two orbits lean: one precesses round the vertical, the other tumbles over.
local ORBIT_LEAN = math.rad(60)
local ORBIT_TILT = math.rad(70)
local TUMBLE_SHARE = 0.8
-- The light, off, stays faintly visible.
local LIGHT_OFF_TRANSPARENCY = 0.8
-- A bomb the server never reports going off is put out this long after its fuse.
local LATE_SECONDS = 0.5

export type Throw = {
	id: number,
	thrower: Player,
	start: Vector3,
	velocity: Vector3,
	fuse: number,
	-- The root part it homes on; nil: it flies straight.
	target: BasePart?,
}

export type Effect = {
	-- Steps the bomb by `deltaTime`; false once it is over and gone.
	step: (deltaTime: number) -> boolean,
	-- It went off at `center` (the server says so).
	explode: (center: Vector3) -> (),
}

local BombVisual = {}

local function facing(position: Vector3, direction: Vector3): CFrame
	if direction.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + direction)
end

local function flashBall(parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = "Flash"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = LOOK.color
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function build(throw: Throw?, center: Vector3?, folder: Instance): Effect
	local model = Instance.new("Model")
	model.Name = "GravityBomb"
	model.Parent = folder
	local body = PvpKit.piece("BombBody", model)
	local belt = PvpKit.piece("BombGlow", model, LOOK.color)
	local light = PvpKit.piece("BombLight", model, LOOK.color)
	local orbits = { PvpKit.piece("Ring", model, LOOK.color), PvpKit.piece("Ring", model, LOOK.color) }
	local flash = flashBall(model)

	local half = LOOK.trail.width / 2
	local trailFrom = Instance.new("Attachment")
	trailFrom.CFrame = body.offset:Inverse() * CFrame.new(-half, 0, 0)
	trailFrom.Parent = body.part
	local trailTo = Instance.new("Attachment")
	trailTo.CFrame = body.offset:Inverse() * CFrame.new(half, 0, 0)
	trailTo.Parent = body.part
	local trail = Instance.new("Trail")
	trail.Attachment0 = trailFrom
	trail.Attachment1 = trailTo
	trail.Color = ColorSequence.new(LOOK.color)
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.Lifetime = LOOK.trail.lifetime
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = body.part

	local elapsed = 0
	local blastAt: Vector3? = nil
	local blastTime = 0

	local function explode(at: Vector3)
		if blastAt then
			return
		end
		blastAt = at
		blastTime = 0
		for _, piece in { body, belt, light, orbits[2] } do
			piece.part.Transparency = 1
		end
		trail.Enabled = false
	end

	local position = if throw then throw.start else Vector3.zero
	local velocity = if throw then throw.velocity else Vector3.zero
	local lastTargetPosition: Vector3? = nil
	local targetVelocity = Vector3.zero

	-- Homes as the server's bomb does (PvpService, Domain/Homing), on where this client sees the
	-- target; the server's blast puts it right in the end.
	local function steer(deltaTime: number, target: BasePart)
		local now = target.Position
		targetVelocity = if lastTargetPosition and deltaTime > 0
			then (now - lastTargetPosition) / deltaTime
			else target.AssemblyLinearVelocity
		lastTargetPosition = now
		velocity = Homing.steer(
			position,
			velocity,
			now,
			targetVelocity,
			PvpConfig.BOMB.throwSpeed,
			PvpConfig.BOMB.steerAcceleration,
			deltaTime
		)
	end

	local function flight(deltaTime: number, current: Throw)
		elapsed += deltaTime
		if elapsed > current.fuse + LATE_SECONDS then
			explode(position)
			return
		end
		if elapsed <= current.fuse then
			local target = current.target
			if target and target.Parent then
				steer(deltaTime, target)
			end
			position += velocity * deltaTime
		end
		local angle, scale, isLit = PvpFx.bombCharge(elapsed, current.fuse, LOOK.charge)
		if GuiService.ReducedMotionEnabled then
			angle, isLit = 0, true
		end
		local frame = facing(position, velocity)
		light.part.Transparency = if isLit then 0 else LIGHT_OFF_TRANSPARENCY
		local place = CFrame.new(position)
		local leaning = place * CFrame.Angles(0, angle, 0) * CFrame.Angles(ORBIT_LEAN, 0, 0)
		local tumbling = place * CFrame.Angles(angle * TUMBLE_SHARE, 0, 0) * CFrame.Angles(0, 0, ORBIT_TILT)
		for _, orbit in orbits do
			PvpKit.sizeRing(orbit, LOOK.orbitRadius * scale, LOOK.orbitThickness)
		end
		workspace:BulkMoveTo({ body.part, belt.part, light.part, orbits[1].part, orbits[2].part }, {
			frame * body.offset,
			frame * belt.offset,
			frame * light.offset,
			leaning * orbits[1].offset,
			tumbling * orbits[2].offset,
		}, Enum.BulkMoveMode.FireCFrameChanged)
	end

	local function step(deltaTime: number): boolean
		local at = blastAt
		if not at then
			flight(deltaTime, throw :: Throw)
			return true
		end
		blastTime += deltaTime
		-- The first orbit becomes the wave: flat, round the centre.
		local wave = orbits[1]
		local radius, waveTransparency = PvpFx.wave(blastTime, PvpConfig.BOMB.radiusStuds, LOOK.wave)
		local size, flashTransparency = PvpFx.burst(blastTime, LOOK.flash.seconds, LOOK.flash.from, LOOK.flash.to)
		if not radius and not size then
			model:Destroy()
			return false
		end
		local place = CFrame.new(at)
		if radius then
			PvpKit.sizeRing(wave, radius, LOOK.waveThickness)
			wave.part.Transparency = waveTransparency
			wave.part.CFrame = place * wave.offset
		else
			wave.part.Transparency = 1
		end
		if size then
			flash.Size = Vector3.one * size * 2
			flash.Transparency = flashTransparency
			flash.CFrame = place
		else
			flash.Transparency = 1
		end
		return true
	end

	if center then
		explode(center)
	end
	return { step = step, explode = explode }
end

-- A thrown bomb, from its throw.
function BombVisual.thrown(throw: Throw, folder: Instance): Effect
	return build(throw, nil, folder)
end

-- Only the blast at `center`: a bomb that went off without this client seeing it thrown.
function BombVisual.blast(center: Vector3, folder: Instance): Effect
	return build(nil, center, folder)
end

return table.freeze(BombVisual)
