--!strict
-- Prepares players for space and runs the authoritative space simulation.
-- Instances are created here, outside the simulation, as Server Authority requires.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DeathPose = require(ReplicatedStorage.Shared.Character.DeathPose)
local FlightAnimation = require(ReplicatedStorage.Shared.Character.FlightAnimation)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
local JetpackModel = require(script.Parent.Parent.Character.JetpackModel)
local Oxygen = require(ReplicatedStorage.Shared.Domain.Oxygen)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local RigPose = require(script.Parent.Parent.Character.RigPose)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)

local PART_WAIT_TIMEOUT = 10
-- Parts the jetpack attaches to; the character is only equipped once all of them exist.
local REQUIRED_PARTS = { "HumanoidRootPart", "UpperTorso", "RightHand", "LeftHand" }

export type Dependencies = {
	getSpawn: () -> SpawnLocation?,
	-- How the player's jetpack looks (their level); the starter look without a profile.
	getJetpackLooks: (player: Player) -> JetpackLooks.Looks,
}

export type SpaceService = {
	name: string,
	init: () -> (),
	start: () -> (),
	-- Fires when a player runs out of oxygen, with where they were (analytics).
	suffocated: Signal.Signal<Player, Vector3>,
}

local SpaceService = {}

local function waitForParts(character: Model): boolean
	for _, name in REQUIRED_PARTS do
		local part = character:WaitForChild(name, PART_WAIT_TIMEOUT)
		if not part or not part:IsA("BasePart") then
			warn(`[SpaceService] {character.Name} has no {name}; jetpack not equipped`)
			return false
		end
	end
	return true
end

local function addFlightConstraints(root: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Name = FlightConfig.ATTACHMENT_NAME

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = FlightConfig.VELOCITY_NAME
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 0

	local align = Instance.new("AlignOrientation")
	align.Name = FlightConfig.ALIGN_NAME
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = FlightConfig.ALIGN_RESPONSIVENESS
	align.MaxTorque = 0

	attachment.Parent = root
	velocity.Parent = root
	align.Parent = root
end

-- A character that dies out in space keeps drifting, whole, instead of falling under the
-- station's gravity (the flight simulation no longer holds it up; the station's floor needs
-- gravity, so it stays on). The body freezes, every part anchored, goes limp (DeathPose, set
-- by Character/RigPose) and the server moves it on at the speed it had, slowly tumbling, until
-- it is gone (respawn). No physics on the dead body: forces on a ragdoll under Server
-- Authority crash Studio. Its joints are kept (Humanoid.BreakJointsOnDeath is off, see
-- `equip`), so nothing comes apart before it freezes.
local function floatWhenDead(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) ~= true or not root or not root:IsA("BasePart") then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	RigPose.apply(character, DeathPose.JOINTS)

	local axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	local spinRate = math.rad(DeathPose.TUMBLE_DEGREES_PER_SECOND)
	local drift: RBXScriptConnection
	drift = RunService.Heartbeat:Connect(function(deltaTime)
		if character.Parent == nil then
			drift:Disconnect()
			return
		end
		local pivot = character:GetPivot()
		local turned = CFrame.fromAxisAngle(axis, spinRate * deltaTime) * pivot.Rotation
		character:PivotTo(CFrame.new(pivot.Position + velocity * deltaTime) * turned)
	end)
end

-- Out of oxygen: the character dies and respawns at the station.
local function suffocateEmptyTanks(suffocated: Signal.Signal<Player, Vector3>)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local oxygen = character and character:GetAttribute(OxygenConfig.ATTRIBUTE)
		if humanoid and humanoid.Health > 0 and type(oxygen) == "number" and Oxygen.isEmpty(oxygen) then
			humanoid.Health = 0
			suffocated.fire(player, (character :: Model):GetPivot().Position)
		end
	end
end

function SpaceService.new(dependencies: Dependencies): SpaceService
	local flightAnimationId: string? = nil
	local suffocated = Signal.new() :: Signal.Signal<Player, Vector3>

	local function equip(character: Model)
		if not waitForParts(character) then
			return
		end
		addFlightConstraints(character:FindFirstChild("HumanoidRootPart") :: BasePart)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- A body that comes apart would scatter its pieces in weightlessness (floatWhenDead).
			humanoid.BreakJointsOnDeath = false
			humanoid.Died:Once(function()
				floatWhenDead(character)
			end)
		end
		local player = Players:GetPlayerFromCharacter(character)
		local looks = if player then dependencies.getJetpackLooks(player) else JetpackLooks.forLevel(0)
		JetpackModel.attach(character, looks)

		if flightAnimationId then
			local animation = Instance.new("Animation")
			animation.Name = JetpackConfig.ANIMATION_INSTANCE_NAME
			animation.AnimationId = flightAnimationId
			animation.Parent = character
		end
		-- The punch exists only as an uploaded asset: Studio's on-the-fly animations do not
		-- play under Server Authority. Without it the strike is a lunge with no arm movement.
		if PvpConfig.STRIKE_ANIMATION_ID ~= "" then
			local animation = Instance.new("Animation")
			animation.Name = PvpConfig.STRIKE_ANIMATION_INSTANCE_NAME
			animation.AnimationId = PvpConfig.STRIKE_ANIMATION_ID
			animation.Parent = character
		end
	end

	local function onPlayerAdded(player: Player)
		FlightInputs.create().Parent = player
		-- The central station's spawn only for a player without an island yet: BayService puts
		-- every joining player's spawn on their own island (decision 068).
		local spawn = dependencies.getSpawn()
		if spawn and not player.RespawnLocation then
			player.RespawnLocation = spawn
		end
		player.CharacterAdded:Connect(equip)
		if player.Character then
			equip(player.Character)
		end
	end

	local function init()
		flightAnimationId = FlightAnimation.resolveId()
		if not flightAnimationId then
			warn("[SpaceService] No flight animation: set JetpackConfig.FLIGHT_ANIMATION_ID for live servers")
		end
	end

	local function start()
		PlayerEvents.observe(onPlayerAdded, function() end)
		SpaceSimulation.start()
		-- Deaths happen outside the simulation: they change the character's lifecycle.
		RunService.PostSimulation:Connect(function()
			suffocateEmptyTanks(suffocated)
		end)
	end

	return {
		name = "SpaceService",
		init = init,
		start = start,
		suffocated = suffocated,
	}
end

return table.freeze(SpaceService)
