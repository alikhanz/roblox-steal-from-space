--!strict
-- Jetpack movement, bound to RunService:BindToSimulation. Runs on the server (authoritative)
-- and on the client (prediction) with the same code, so it may only use Simulation Access APIs,
-- keep its state in attributes and never create, destroy or reparent instances.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FlightConfig = require("./FlightConfig")
local FlightInputs = require("./FlightInputs")

local JetpackSimulation = {}

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
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	local velocity = root:FindFirstChild(FlightConfig.VELOCITY_NAME)
	local align = root:FindFirstChild(FlightConfig.ALIGN_NAME)
	if not velocity or not velocity:IsA("LinearVelocity") or not align or not align:IsA("AlignOrientation") then
		return nil
	end
	return { character = character, humanoid = humanoid, root = root, velocity = velocity, align = align }
end

local function updateToggle(rig: Rig, togglePressed: boolean): boolean
	local wasHeld = rig.character:GetAttribute(FlightConfig.TOGGLE_HELD_ATTRIBUTE) == true
	local flying = rig.character:GetAttribute(FlightConfig.FLYING_ATTRIBUTE) == true
	-- Edge detection on polled state: Pressed/Released events are unreliable under rollback.
	if togglePressed and not wasHeld then
		flying = not flying
		rig.character:SetAttribute(FlightConfig.FLYING_ATTRIBUTE, flying)
	end
	rig.character:SetAttribute(FlightConfig.TOGGLE_HELD_ATTRIBUTE, togglePressed)
	return flying
end

local function fly(rig: Rig, context: Instance, deltaTime: number)
	local vertical = (if FlightInputs.isPressed(context, FlightInputs.ASCEND) then 1 else 0)
		- (if FlightInputs.isPressed(context, FlightInputs.DESCEND) then 1 else 0)
	local input = rig.humanoid.MoveDirection + Vector3.yAxis * vertical
	if input.Magnitude > 1 then
		input = input.Unit
	end

	local current = rig.root.AssemblyLinearVelocity
	local nextVelocity
	if input.Magnitude > 0 then
		-- Exponential approach to the input target: frame-rate independent acceleration.
		local blend = 1 - math.exp(-FlightConfig.RESPONSE * deltaTime)
		nextVelocity = current:Lerp(input * FlightConfig.MAX_SPEED, blend)
	else
		-- No input: keep gliding, losing a fixed share of speed per second.
		nextVelocity = current * FlightConfig.DRIFT_RETENTION_PER_SECOND ^ deltaTime
	end

	rig.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	rig.velocity.MaxForce = FlightConfig.MAX_FORCE
	rig.velocity.VectorVelocity = nextVelocity

	local horizontal = Vector3.new(current.X, 0, current.Z)
	if horizontal.Magnitude > 1 then
		rig.align.CFrame = CFrame.lookAlong(Vector3.zero, horizontal)
	end
	rig.align.MaxTorque = FlightConfig.MAX_FORCE
end

local function land(rig: Rig)
	if rig.velocity.MaxForce == 0 then
		return
	end
	rig.velocity.MaxForce = 0
	rig.align.MaxTorque = 0
	rig.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end

local function step(deltaTime: number)
	for _, player in Players:GetPlayers() do
		local rig = findRig(player)
		local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
		if not rig or not context then
			continue
		end
		if updateToggle(rig, FlightInputs.isPressed(context, FlightInputs.TOGGLE)) then
			fly(rig, context, deltaTime)
		else
			land(rig)
		end
	end
end

function JetpackSimulation.start()
	RunService:BindToSimulation(step)
end

return table.freeze(JetpackSimulation)
