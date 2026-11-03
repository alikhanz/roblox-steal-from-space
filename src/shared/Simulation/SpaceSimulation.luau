--!strict
-- Movement and life support in space, bound to RunService:BindToSimulation.
-- Runs on the server (authoritative) and on the client (prediction) with the same code, so it
-- may only use Simulation Access APIs, keeps its state in character attributes and never
-- creates, destroys or reparents instances. The math lives in Domain and is unit-tested.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Bounds = require("../Domain/Bounds")
local DevConfig = require("../Config/DevConfig")
local EggConfig = require("../Config/EggConfig")
local EggTargets = require("./EggTargets")
local Flight = require("../Domain/Flight")
local FlightConfig = require("../Config/FlightConfig")
local FlightInputs = require("../Input/FlightInputs")
local FlightLean = require("../Domain/FlightLean")
local Grab = require("../Domain/Grab")
local JetpackConfig = require("../Config/JetpackConfig")
local Oxygen = require("../Domain/Oxygen")
local OxygenConfig = require("../Config/OxygenConfig")
local Speed = require("../Domain/Speed")
local SpeedConfig = require("../Config/SpeedConfig")
local StationConfig = require("../Config/StationConfig")
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

local function verticalInput(context: Instance): number
	local up = if FlightInputs.isPressed(context, FlightInputs.ASCEND) then 1 else 0
	local down = if FlightInputs.isPressed(context, FlightInputs.DESCEND) then 1 else 0
	return up - down
end

local function carriedRarity(character: Model): EggConfig.RarityId?
	local value = character:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE)
	if type(value) == "string" and EggConfig.RARITIES[value :: EggConfig.RarityId] then
		return value :: EggConfig.RarityId
	end
	return nil
end

-- Top flight speed without an egg, studs per second: set by the server from the speed stat.
local function flightSpeed(character: Model): number
	local value = character:GetAttribute(SpeedConfig.FLIGHT_SPEED_ATTRIBUTE)
	return if type(value) == "number" then value else SpeedConfig.FLIGHT.minFlightSpeed
end

local function fly(rig: Rig, context: Instance, deltaTime: number)
	local aim = Flight.sanitizeAim(FlightInputs.readAim(context) or Vector3.zero)
	local direction = Flight.direction(rig.humanoid.MoveDirection, aim, Vector3.yAxis, verticalInput(context))
	local rarity = carriedRarity(rig.character)
	-- Every carried egg counts as medium until eggs get sizes (stage 2, guardians step).
	local carryMultiplier = if rarity then Speed.carryMultiplier(EggConfig.RARITIES[rarity].weight) else 1
	local maxSpeed = flightSpeed(rig.character)
	local velocity = Flight.nextVelocity(
		rig.root.AssemblyLinearVelocity,
		direction,
		deltaTime,
		maxSpeed * carryMultiplier,
		FlightConfig.TUNING
	)
	velocity =
		Bounds.limitVelocity(rig.root.Position, velocity, StationConfig.PLATFORM_CENTER, WorldConfig.BOUNDARY_RADIUS)

	rig.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	rig.velocity.MaxForce = FlightConfig.MAX_FORCE
	rig.velocity.VectorVelocity = velocity

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
	rig.align.MaxTorque = FlightConfig.MAX_FORCE
end

-- Plays or stops the flight pose. Runs inside the simulation: under Server Authority, character
-- animations started elsewhere are rolled back. Tracks are looked up each step, never cached.
local function setFlightPose(rig: Rig, active: boolean)
	local animation = rig.character:FindFirstChild(JetpackConfig.ANIMATION_INSTANCE_NAME)
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
			track:Play(JetpackConfig.ANIMATION_FADE_SECONDS)
		end
	elseif track and track.IsPlaying then
		track:Stop(JetpackConfig.ANIMATION_FADE_SECONDS)
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

-- Fills the grab progress while the grab input is held next to an egg. Completion is only a
-- request: the server confirms it outside the simulation (CarryService) and hands over the egg.
local function grab(rig: Rig, context: Instance, deltaTime: number)
	local character = rig.character
	local previousProgress = character:GetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE)
	local previousTarget = character:GetAttribute(EggConfig.GRAB_TARGET_ATTRIBUTE)

	local target = if carriedRarity(character) then nil else EggTargets.nearest(rig.root.Position)
	local targetId = if target then target.id else nil
	-- Switching to another egg starts over.
	local progress = if type(previousProgress) == "number" and previousTarget == targetId then previousProgress else 0
	local grabSeconds = if target then EggConfig.RARITIES[target.rarity].grabSeconds else 0
	local nextProgress =
		Grab.step(progress, FlightInputs.isPressed(context, FlightInputs.GRAB), target ~= nil, grabSeconds, deltaTime)

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
			Zones.nextInSpace(previous == true, rig.root.Position, StationConfig.STATION, StationConfig.ZONE_MARGIN)
		-- Compared with the raw attribute so a fresh character (nil) gets an explicit value.
		if previous ~= inSpace then
			rig.character:SetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE, inSpace)
		end

		if inSpace then
			fly(rig, context, deltaTime)
		else
			walk(rig)
		end
		setFlightPose(rig, inSpace)
		breathe(player, rig, inSpace, deltaTime)
		grab(rig, context, deltaTime)
	end
end

function SpaceSimulation.start()
	RunService:BindToSimulation(step)
end

return table.freeze(SpaceSimulation)
