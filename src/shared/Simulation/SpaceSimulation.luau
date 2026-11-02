--!strict
-- Movement and life support in space, bound to RunService:BindToSimulation.
-- Runs on the server (authoritative) and on the client (prediction) with the same code, so it
-- may only use Simulation Access APIs, keeps its state in character attributes and never
-- creates, destroys or reparents instances. The math lives in Domain and is unit-tested.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Flight = require("../Domain/Flight")
local FlightConfig = require("../Config/FlightConfig")
local FlightInputs = require("../Input/FlightInputs")
local FlightLean = require("../Domain/FlightLean")
local JetpackConfig = require("../Config/JetpackConfig")
local Oxygen = require("../Domain/Oxygen")
local OxygenConfig = require("../Config/OxygenConfig")
local StationConfig = require("../Config/StationConfig")
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

local function fly(rig: Rig, context: Instance, deltaTime: number)
	local aim = Flight.sanitizeAim(FlightInputs.readAim(context) or Vector3.zero)
	local direction = Flight.direction(rig.humanoid.MoveDirection, aim, Vector3.yAxis, verticalInput(context))
	local velocity = Flight.nextVelocity(rig.root.AssemblyLinearVelocity, direction, deltaTime, FlightConfig.TUNING)

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
		local pitch, roll =
			FlightLean.angles(-localVelocity.Z, localVelocity.X, FlightConfig.TUNING.maxSpeed, JetpackConfig.LEAN)
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

local function breathe(rig: Rig, inSpace: boolean, deltaTime: number)
	local current = rig.character:GetAttribute(OxygenConfig.ATTRIBUTE)
	local oxygen = if type(current) == "number" then current else OxygenConfig.CAPACITY
	local nextOxygen = Oxygen.step(oxygen, OxygenConfig.CAPACITY, inSpace, deltaTime, OxygenConfig.TUNING)
	if nextOxygen ~= current then
		rig.character:SetAttribute(OxygenConfig.ATTRIBUTE, nextOxygen)
	end
end

local function step(deltaTime: number)
	for _, player in Players:GetPlayers() do
		local rig = findRig(player)
		local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
		if not rig or not context then
			continue
		end

		local inSpace = not Zones.isInsideDome(rig.root.Position, StationConfig.DOME)
		if rig.character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) ~= inSpace then
			rig.character:SetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE, inSpace)
		end

		if inSpace then
			fly(rig, context, deltaTime)
		else
			walk(rig)
		end
		setFlightPose(rig, inSpace)
		breathe(rig, inSpace, deltaTime)
	end
end

function SpaceSimulation.start()
	RunService:BindToSimulation(step)
end

return table.freeze(SpaceSimulation)
