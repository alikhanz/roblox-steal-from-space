--!strict
-- Movement and life support in space, bound to RunService:BindToSimulation.
-- Runs on the server (authoritative) and on the client (prediction) with the same code, so it
-- may only use Simulation Access APIs, keeps its state in character attributes and never
-- creates, destroys or reparents instances. The math lives in Domain and is unit-tested.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Abilities = require("../Domain/Abilities")
local BayConfig = require("../Config/BayConfig")
local Bounds = require("../Domain/Bounds")
local DevConfig = require("../Config/DevConfig")
local EggConfig = require("../Config/EggConfig")
local EggTargets = require("./EggTargets")
local Flight = require("../Domain/Flight")
local FlightConfig = require("../Config/FlightConfig")
local FlightInputs = require("../Input/FlightInputs")
local FlightLean = require("../Domain/FlightLean")
local Grab = require("../Domain/Grab")
local GuardianConfig = require("../Config/GuardianConfig")
local JetpackConfig = require("../Config/JetpackConfig")
local JetpackSwitch = require("../Domain/JetpackSwitch")
local Oxygen = require("../Domain/Oxygen")
local OxygenConfig = require("../Config/OxygenConfig")
local PvpConfig = require("../Config/PvpConfig")
local Speed = require("../Domain/Speed")
local Stand = require("../Domain/Stand")
local StandConfig = require("../Config/StandConfig")
local StationConfig = require("../Config/StationConfig")
local TopSpeed = require("./TopSpeed")
local Trainer = require("../Domain/Trainer")
local WorldConfig = require("../Config/WorldConfig")
local Zones = require("../Domain/Zones")

local SpaceSimulation = {}

type Rig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	velocity: LinearVelocity,
	align: AlignOrientation,
}

-- A guardian's hit in progress: where the thief is thrown and the axis they tumble about.
type Hit = {
	velocity: Vector3,
	axis: Vector3,
}

local function findRig(player: Player): Rig?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	local velocity = root:FindFirstChild(FlightConfig.VELOCITY_NAME)
	local align = root:FindFirstChild(FlightConfig.ALIGN_NAME)
	if not velocity or not velocity:IsA("LinearVelocity") or not align or not align:IsA("AlignOrientation") then
		return nil
	end
	return { character = character, humanoid = humanoid, root = root, velocity = velocity, align = align }
end

-- Up: the up action (space, R1, A, the touch up button) or the humanoid's own jump. Roblox's touch
-- jump button sits under the up button and should be hidden in flight; should it show up anyway,
-- a press on it still climbs.
local function ascending(rig: Rig, context: Instance): boolean
	return rig.humanoid.Jump or FlightInputs.isPressed(context, FlightInputs.ASCEND)
end

local function verticalInput(rig: Rig, context: Instance): number
	local up = if ascending(rig, context) then 1 else 0
	local down = if FlightInputs.isPressed(context, FlightInputs.DESCEND) then 1 else 0
	return up - down
end

-- Jumping is on exactly while the jetpack is off, checked every step rather than only when the
-- mode changes: a client rolled back past that change kept jumping on in flight, and Roblox's touch
-- jump button stayed over the up button, taking its presses. Written only when it differs.
local function allowJumping(rig: Rig, allowed: boolean)
	if rig.humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) ~= allowed then
		rig.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, allowed)
	end
end

local function carriedRarity(character: Model): EggConfig.RarityId?
	local value = character:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE)
	if type(value) == "string" and EggConfig.RARITIES[value :: EggConfig.RarityId] then
		return value :: EggConfig.RarityId
	end
	return nil
end

-- Share of the stat the carried egg takes away; 0 without an egg.
local function carriedWeight(character: Model): number
	local rarity = carriedRarity(character)
	if not rarity then
		return 0
	end
	local sizeValue = character:GetAttribute(EggConfig.CARRIED_SIZE_ATTRIBUTE)
	local size = EggConfig.SIZES[sizeValue :: EggConfig.SizeId] or EggConfig.SIZES[EggConfig.TYPICAL_SIZE]
	return Speed.eggWeight(EggConfig.RARITIES[rarity].weight, size.weightFactor)
end

-- Top flight speed without an egg, studs per second: set by the server from the speed stat.
local function flightSpeed(character: Model): number
	return TopSpeed.of(character)
end

-- Switches slow mode on each press of its key (the edge is found from the key state of the
-- last step, kept on the character like the rest of the predicted state).
local function toggleSlowMode(character: Model, context: Instance)
	local pressed = FlightInputs.isPressed(context, FlightInputs.SLOW_MODE)
	local held = character:GetAttribute(FlightConfig.SLOW_MODE_HELD_ATTRIBUTE) == true
	if pressed and not held then
		local on = character:GetAttribute(FlightConfig.SLOW_MODE_ATTRIBUTE) == true
		character:SetAttribute(FlightConfig.SLOW_MODE_ATTRIBUTE, if on then nil else true)
	end
	if pressed ~= held then
		character:SetAttribute(FlightConfig.SLOW_MODE_HELD_ATTRIBUTE, if pressed then true else nil)
	end
end

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.RespectCanCollide = true

-- How far above a floor the feet are, studs, when one is within `reach` of them (nil: none). A
-- ray straight down from the body, through the character itself.
local function floorGap(rig: Rig, reach: number): number?
	local standing = rig.humanoid.HipHeight + rig.root.Size.Y / 2
	floorParams.FilterDescendantsInstances = { rig.character }
	local origin = rig.root.Position
	local hit = workspace:Raycast(origin, Vector3.new(0, -(standing + reach), 0), floorParams)
	return if hit then origin.Y - hit.Position.Y - standing else nil
end

-- The floor under a flyer, if near: for landing and for not sinking into it. Nil on foot.
local function floorUnderFlyer(rig: Rig, deltaTime: number): number?
	if rig.velocity.MaxForce == 0 then
		return nil
	end
	local fallY = math.min(rig.root.AssemblyLinearVelocity.Y, rig.velocity.VectorVelocity.Y)
	return floorGap(rig, JetpackSwitch.floorReach(fallY, deltaTime, FlightConfig.SWITCH))
end

local function numberOr(character: Model, name: string, fallback: number): number
	local value = character:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function writeAttribute(character: Model, name: string, value: any)
	if character:GetAttribute(name) ~= value then
		character:SetAttribute(name, value)
	end
end

-- Switches the jetpack (Domain/JetpackSwitch, decision 096): always on in space, a double jump
-- under a dome, off on landing there (`gap`: the floor under a flyer, floorUnderFlyer). Jump
-- comes from the up action (space, R1, A, the touch up button) or the humanoid's own jump
-- (Roblox's touch jump button). Returns whether it is on.
local function switchJetpack(rig: Rig, context: Instance, inSpace: boolean, gap: number?, deltaTime: number): boolean
	local character = rig.character
	local tuning = FlightConfig.SWITCH
	local fresh = JetpackSwitch.initial(tuning)
	local state: JetpackSwitch.State = {
		on = character:GetAttribute(FlightConfig.JETPACK_ON_ATTRIBUTE) == true,
		held = character:GetAttribute(FlightConfig.JUMP_HELD_ATTRIBUTE) == true,
		releasedFor = numberOr(character, FlightConfig.JUMP_RELEASED_ATTRIBUTE, fresh.releasedFor),
		tapWindow = numberOr(character, FlightConfig.JUMP_TAP_WINDOW_ATTRIBUTE, 0),
	}
	local up = ascending(rig, context)
	local landed = state.on and JetpackSwitch.isLanding(gap, rig.root.AssemblyLinearVelocity.Y, up, tuning)
	local nextState = JetpackSwitch.step(state, {
		inSpace = inSpace,
		pressed = up,
		landed = landed,
	}, deltaTime, tuning)
	writeAttribute(character, FlightConfig.JETPACK_ON_ATTRIBUTE, nextState.on)
	writeAttribute(character, FlightConfig.JUMP_HELD_ATTRIBUTE, if nextState.held then true else nil)
	writeAttribute(
		character,
		FlightConfig.JUMP_RELEASED_ATTRIBUTE,
		if nextState.releasedFor < tuning.minReleaseSeconds then nextState.releasedFor else nil
	)
	writeAttribute(
		character,
		FlightConfig.JUMP_TAP_WINDOW_ATTRIBUTE,
		if nextState.tapWindow > 0 then nextState.tapWindow else nil
	)
	return nextState.on
end

local function currentHit(character: Model): Hit?
	local velocity = character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE)
	if typeof(velocity) ~= "Vector3" then
		return nil
	end
	local axis = character:GetAttribute(GuardianConfig.HIT_AXIS_ATTRIBUTE)
	return {
		velocity = velocity,
		axis = if typeof(axis) == "Vector3" and axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis,
	}
end

-- Advances the tumble while hit and clears it afterwards. The angle is predicted state, so it
-- lives in an attribute like everything else the simulation owns.
local function tumbleAngle(character: Model, hit: Hit?, deltaTime: number): number
	local previous = character:GetAttribute(GuardianConfig.HIT_ANGLE_ATTRIBUTE)
	if not hit then
		if previous ~= nil then
			character:SetAttribute(GuardianConfig.HIT_ANGLE_ATTRIBUTE, nil)
		end
		return 0
	end
	local angle = (if type(previous) == "number" then previous else 0) + GuardianConfig.TUMBLE_SPIN_RATE * deltaTime
	character:SetAttribute(GuardianConfig.HIT_ANGLE_ATTRIBUTE, angle)
	return angle
end

local function numberAttribute(character: Model, name: string): number
	local value = character:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function setNumberAttribute(character: Model, name: string, value: number)
	local stored = if value > 0 then value else nil
	if character:GetAttribute(name) ~= stored then
		character:SetAttribute(name, stored)
	end
end

-- Advances the strike (Abilities.stepStrike) and returns the lunge's direction while it lasts.
-- `canStrike`: out in space, not stunned and empty-handed. The state is predicted, so it lives
-- in character attributes; the server watches the lunge for a touch (PvpService).
local function strike(rig: Rig, context: Instance, canStrike: boolean, deltaTime: number): Vector3?
	local character = rig.character
	local timers: Abilities.StrikeTimers = {
		lungeLeft = numberAttribute(character, PvpConfig.STRIKE_LUNGE_ATTRIBUTE),
		cooldownLeft = numberAttribute(character, PvpConfig.STRIKE_COOLDOWN_ATTRIBUTE),
	}
	local wants = canStrike and FlightInputs.isPressed(context, FlightInputs.STRIKE)
	local nextTimers, started = Abilities.stepStrike(timers, wants, deltaTime, PvpConfig.STRIKE)
	setNumberAttribute(character, PvpConfig.STRIKE_LUNGE_ATTRIBUTE, nextTimers.lungeLeft)
	setNumberAttribute(character, PvpConfig.STRIKE_COOLDOWN_ATTRIBUTE, nextTimers.cooldownLeft)

	if started then
		local aim = Flight.sanitizeAim(FlightInputs.readAim(context) or Vector3.zero)
		local direction = if aim and aim.Magnitude > 1e-3 then aim.Unit else rig.root.CFrame.LookVector
		character:SetAttribute(PvpConfig.STRIKE_AIM_ATTRIBUTE, direction)
	elseif nextTimers.lungeLeft <= 0 and character:GetAttribute(PvpConfig.STRIKE_AIM_ATTRIBUTE) ~= nil then
		character:SetAttribute(PvpConfig.STRIKE_AIM_ATTRIBUTE, nil)
	end
	if nextTimers.lungeLeft <= 0 then
		return nil
	end
	local direction = character:GetAttribute(PvpConfig.STRIKE_AIM_ATTRIBUTE)
	return if typeof(direction) == "Vector3" then direction else nil
end

local function fly(
	rig: Rig,
	context: Instance,
	deltaTime: number,
	target: EggTargets.Target?,
	hit: Hit?,
	lunge: Vector3?,
	gap: number?
)
	local current = rig.root.AssemblyLinearVelocity
	local maxSpeed = flightSpeed(rig.character)
	local aim = Flight.sanitizeAim(FlightInputs.readAim(context) or Vector3.zero)

	local velocity: Vector3
	if hit then
		-- Thrown by a guardian: no steering until the stun ends.
		velocity = hit.velocity
	elseif lunge then
		-- The strike: a straight dash along the aim it started with.
		velocity = lunge * (maxSpeed + PvpConfig.STRIKE.lungeExtraSpeed)
	elseif target then
		-- Magnetic grab, locked on with one press: pulled to the egg instead of drifting past it.
		velocity =
			Grab.magnetVelocity(current, rig.root.Position, target.position, deltaTime, EggConfig.MAGNET, maxSpeed)
	else
		local direction = Flight.direction(rig.humanoid.MoveDirection, aim, Vector3.yAxis, verticalInput(rig, context))
		local carryMultiplier = Speed.carryMultiplier(carriedWeight(rig.character))
		velocity = Flight.nextVelocity(current, direction, deltaTime, maxSpeed * carryMultiplier, FlightConfig.TUNING)
	end
	-- Never into a floor: the jetpack's force would push a fast flyer through a platform.
	velocity = Vector3.new(velocity.X, JetpackSwitch.limitDescent(velocity.Y, gap, deltaTime), velocity.Z)
	velocity =
		Bounds.limitVelocity(rig.root.Position, velocity, StationConfig.PLATFORM_CENTER, WorldConfig.BOUNDARY_RADIUS)
	-- A closer edge while something (the solar storm) keeps everyone near the station.
	local rangeLimit = workspace:GetAttribute(FlightConfig.RANGE_LIMIT_ATTRIBUTE)
	if type(rangeLimit) == "number" then
		velocity = Bounds.limitVelocity(rig.root.Position, velocity, StationConfig.STATION.domeCenter, rangeLimit)
	end

	rig.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	rig.velocity.MaxForce = FlightConfig.MAX_FORCE
	rig.velocity.VectorVelocity = velocity

	local angle = tumbleAngle(rig.character, hit, deltaTime)
	if hit then
		-- Tumbling: the body spins about the hit axis for the whole stun.
		rig.align.CFrame = CFrame.fromAxisAngle(hit.axis, angle)
	else
		-- Face where the camera looks (level, so the body never tumbles), then lean into the motion.
		local facing = if aim then Vector3.new(aim.X, 0, aim.Z) else Vector3.zero
		if facing.Magnitude < 1e-3 then
			local look = rig.root.CFrame.LookVector
			facing = Vector3.new(look.X, 0, look.Z)
		end
		if facing.Magnitude > 1e-3 then
			local heading = CFrame.lookAlong(Vector3.zero, facing)
			local localVelocity = heading:VectorToObjectSpace(velocity)
			local pitch, roll = FlightLean.angles(-localVelocity.Z, localVelocity.X, maxSpeed, JetpackConfig.LEAN)
			rig.align.CFrame = heading * CFrame.Angles(pitch, 0, roll)
		end
	end
	rig.align.MaxTorque = FlightConfig.MAX_FORCE
end

-- Keeps an animation of the character playing while `active` and stops it otherwise; a
-- one-shot animation is only started and runs out by itself. Runs inside the simulation: under
-- Server Authority, character animations started elsewhere are rolled back. Tracks are looked
-- up each step, never cached.
local function setAnimation(rig: Rig, instanceName: string, active: boolean, fadeSeconds: number, oneShot: boolean?)
	if oneShot and not active then
		return
	end
	local animation = rig.character:FindFirstChild(instanceName)
	local animator = rig.humanoid:FindFirstChildOfClass("Animator")
	if not animation or not animation:IsA("Animation") or not animator then
		return
	end
	local track = animator:GetTrackByAnimationId(animation.AnimationId)
	if active then
		if not track then
			track = animator:LoadAnimation(animation)
		end
		if not track.IsPlaying then
			track:Play(fadeSeconds)
		end
	elseif track and track.IsPlaying then
		track:Stop(fadeSeconds)
	end
end

local function walk(rig: Rig)
	if rig.velocity.MaxForce == 0 then
		return
	end
	rig.velocity.MaxForce = 0
	rig.align.MaxTorque = 0
	rig.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end

-- The jetpack stand on the player's own island (docs/design/screens/jetpack-stand.md,
-- Domain/Stand): pulls its owner onto the platform and holds them there facing the island's
-- center until they jump or step away; never takes a flyer. True while it holds them (and they
-- train).
local function stand(player: Player, rig: Rig, context: Instance, flying: boolean): boolean
	local character = rig.character
	local previous = character:GetAttribute(StandConfig.STATE_ATTRIBUTE)
	local island = player:GetAttribute(StandConfig.ISLAND_ATTRIBUTE)
	local frame = if type(island) == "number" then StationConfig.ISLAND_FRAMES[island] else nil
	local pad = BayConfig.TRAINER_PAD
	local inZone, onPlatform = false, false
	if frame and not flying then
		local spot = frame:PointToObjectSpace(rig.root.Position)
		inZone = Trainer.isOnPad(spot.X, spot.Y, spot.Z, pad, BayConfig.TRAINER_TOLERANCE)
		onPlatform = Trainer.isOnPad(spot.X, spot.Y, spot.Z, pad, 0)
	end
	local state = Stand.next(Stand.parse(previous), {
		inZone = inZone,
		onPlatform = onPlatform,
		grounded = rig.humanoid.FloorMaterial ~= Enum.Material.Air,
		moving = rig.humanoid.MoveDirection.Magnitude > StandConfig.LEAVE_MOVE_THRESHOLD,
		jumping = rig.humanoid.Jump or FlightInputs.isPressed(context, FlightInputs.ASCEND),
	})
	if state ~= previous then
		character:SetAttribute(StandConfig.STATE_ATTRIBUTE, state)
	end
	if not frame or not Stand.isTraining(state) then
		return false
	end

	local platform = frame * Vector3.new(pad.x, StandConfig.PLATFORM_HEIGHT, pad.z)
	local target = platform + Vector3.yAxis * (rig.humanoid.HipHeight + rig.root.Size.Y / 2)
	if rig.velocity.MaxForce == 0 then
		rig.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	rig.velocity.MaxForce = FlightConfig.MAX_FORCE
	rig.velocity.VectorVelocity =
		Stand.pullVelocity(rig.root.Position, target, StandConfig.PULL_SECONDS, StandConfig.PULL_MAX_SPEED)
	local toCenter = frame.Position - platform
	rig.align.CFrame = CFrame.lookAlong(Vector3.zero, Vector3.new(toCenter.X, 0, toCenter.Z))
	rig.align.MaxTorque = FlightConfig.MAX_FORCE
	return true
end

local function breathe(player: Player, rig: Rig, inSpace: boolean, deltaTime: number)
	local current = rig.character:GetAttribute(OxygenConfig.ATTRIBUTE)
	local oxygen = if type(current) == "number" then current else OxygenConfig.CAPACITY
	-- Studio playtests can switch draining off (DevService); live servers never set this.
	local draining = inSpace and player:GetAttribute(DevConfig.INFINITE_OXYGEN_ATTRIBUTE) ~= true
	local nextOxygen = Oxygen.step(oxygen, OxygenConfig.CAPACITY, draining, deltaTime, OxygenConfig.TUNING)
	if nextOxygen ~= current then
		rig.character:SetAttribute(OxygenConfig.ATTRIBUTE, nextOxygen)
	end
end

-- The grab's lock (docs/design/screens/grab-button.md, Grab.nextEngaged): one press of the grab
-- input locks on the egg the grab button offers, and the lock holds without holding the input.
-- Returns the locked-on egg, if any. The lock and the last input state live in character
-- attributes, so the client predicts them as the server runs them.
local function engage(rig: Rig, context: Instance, blocked: boolean, lockRange: number): EggTargets.Target?
	local character = rig.character
	local position = rig.root.Position
	local range = Grab.buttonRange(lockRange, EggConfig.GRAB_BUTTON_RANGE)
	local engagedId = character:GetAttribute(EggConfig.GRAB_ENGAGED_ATTRIBUTE)
	local engaged = if type(engagedId) == "string"
		then EggTargets.find(engagedId, position, range * EggConfig.GRAB_RELEASE_FACTOR)
		else nil
	local pressed = FlightInputs.isPressed(context, FlightInputs.GRAB)
	local wasPressed = character:GetAttribute(EggConfig.GRAB_PRESSED_ATTRIBUTE) == true
	-- Looked for only on a press: the egg the button offers.
	local candidate = if pressed and not wasPressed and not blocked then EggTargets.nearest(position, range) else nil

	local nextId = Grab.nextEngaged({
		engaged = if type(engagedId) == "string" then engagedId else nil,
		pressed = pressed,
		wasPressed = wasPressed,
		candidate = if candidate then candidate.id else nil,
		engagedPresent = engaged ~= nil,
		movingAway = engaged ~= nil and Grab.isMovingAway(
			rig.humanoid.MoveDirection,
			engaged.position - position,
			EggConfig.GRAB_LEAVE_MOVE,
			EggConfig.GRAB_LEAVE_DOT
		),
		blocked = blocked,
	})
	if nextId ~= engagedId then
		character:SetAttribute(EggConfig.GRAB_ENGAGED_ATTRIBUTE, nextId)
	end
	if pressed ~= wasPressed then
		character:SetAttribute(EggConfig.GRAB_PRESSED_ATTRIBUTE, pressed)
	end
	if nextId == nil then
		return nil
	elseif engaged and engaged.id == nextId then
		return engaged
	end
	return candidate
end

-- Fills the grab progress while the grab is locked on an egg. Completion is only a request: the
-- server confirms it outside the simulation (CarryService) and hands over the egg.
local function grab(rig: Rig, deltaTime: number, target: EggTargets.Target?, holding: boolean)
	local character = rig.character
	local previousProgress = character:GetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE)
	local previousTarget = character:GetAttribute(EggConfig.GRAB_TARGET_ATTRIBUTE)

	local targetId = if target then target.id else nil
	-- Switching to another egg starts over.
	local progress = if type(previousProgress) == "number" and previousTarget == targetId then previousProgress else 0
	local grabSeconds = if target then EggConfig.RARITIES[target.rarity].grabSeconds else 0
	local inReach = target ~= nil and (target.position - rig.root.Position).Magnitude <= EggConfig.GRAB_REACH
	local nextProgress = Grab.step(progress, holding, target ~= nil, inReach, grabSeconds, deltaTime)

	if nextProgress ~= previousProgress then
		character:SetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE, nextProgress)
	end
	local nextTarget = if nextProgress > 0 then targetId else nil
	if nextTarget ~= previousTarget then
		character:SetAttribute(EggConfig.GRAB_TARGET_ATTRIBUTE, nextTarget)
	end
end

local function step(deltaTime: number)
	for _, player in Players:GetPlayers() do
		local rig = findRig(player)
		local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
		if not rig or not context then
			continue
		end

		local previous = rig.character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE)
		local inSpace =
			Zones.nextInSpace(previous == true, rig.root.Position, StationConfig.STATIONS, StationConfig.ZONE_MARGIN)
		-- Compared with the raw attribute so a fresh character (nil) gets an explicit value.
		if previous ~= inSpace then
			rig.character:SetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE, inSpace)
		end

		toggleSlowMode(rig.character, context)
		local hit = currentHit(rig.character)
		local carrying = carriedRarity(rig.character) ~= nil
		-- The egg the grab is locked on, if any: shared by the magnetic grab and the grab progress.
		-- A fast flyer is offered an egg from farther away, so it is not flown past. A stunned
		-- thief cannot grab: the dropped egg is not snatched straight back.
		local lockRange = Grab.lockRange(flightSpeed(rig.character), EggConfig.GRAB_REACH, EggConfig.LOCK_LEAD_SECONDS)
		local target = engage(rig, context, not inSpace or hit ~= nil or carrying, lockRange)
		-- Hands full with an egg: no strike.
		local lunge = strike(rig, context, inSpace and hit == nil and not carrying, deltaTime)

		local gap = floorUnderFlyer(rig, deltaTime)
		local jetpackOn = switchJetpack(rig, context, inSpace, gap, deltaTime)
		-- The stand takes only those on foot (a flyer lands first).
		local onStand = stand(player, rig, context, jetpackOn)
		-- No jumping in flight: Roblox's touch jump button hides when the jump state is off, and up
		-- and down take its corner (docs/design/screens/hud.md).
		allowJumping(rig, not jetpackOn)
		if jetpackOn then
			fly(rig, context, deltaTime, target, hit, lunge, gap)
		elseif not onStand then
			walk(rig)
		end
		setAnimation(rig, JetpackConfig.ANIMATION_INSTANCE_NAME, jetpackOn, JetpackConfig.ANIMATION_FADE_SECONDS)
		setAnimation(rig, StandConfig.ANIMATION_INSTANCE_NAME, onStand, StandConfig.ANIMATION_FADE_SECONDS)
		-- The punch starts with the lunge and plays out by itself.
		setAnimation(
			rig,
			PvpConfig.STRIKE_ANIMATION_INSTANCE_NAME,
			lunge ~= nil,
			PvpConfig.STRIKE_ANIMATION_FADE_SECONDS,
			true
		)
		breathe(player, rig, inSpace, deltaTime)
		grab(rig, deltaTime, target, target ~= nil)
	end
end

function SpaceSimulation.start()
	RunService:BindToSimulation(step)
end

return table.freeze(SpaceSimulation)
