--!strict
-- Prepares players for space and runs the authoritative space simulation.
-- Instances are created here, outside the simulation, as Server Authority requires.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local Oxygen = require(ReplicatedStorage.Shared.Domain.Oxygen)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local SpaceSimulation = require(ReplicatedStorage.Shared.Simulation.SpaceSimulation)

local ROOT_WAIT_TIMEOUT = 10

export type Dependencies = {
	getSpawn: () -> SpawnLocation?,
}

export type SpaceService = {
	name: string,
	start: () -> (),
}

local SpaceService = {}

local function equipJetpack(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", ROOT_WAIT_TIMEOUT)
	if not root or not root:IsA("BasePart") then
		warn(`[SpaceService] {character.Name} has no HumanoidRootPart`)
		return
	end

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

-- Out of oxygen: the character dies and respawns at the station.
local function suffocateEmptyTanks()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local oxygen = character and character:GetAttribute(OxygenConfig.ATTRIBUTE)
		if humanoid and humanoid.Health > 0 and type(oxygen) == "number" and Oxygen.isEmpty(oxygen) then
			humanoid.Health = 0
		end
	end
end

function SpaceService.new(dependencies: Dependencies): SpaceService
	local function onPlayerAdded(player: Player)
		FlightInputs.create().Parent = player
		local spawn = dependencies.getSpawn()
		if spawn then
			player.RespawnLocation = spawn
		end
		player.CharacterAdded:Connect(equipJetpack)
		if player.Character then
			equipJetpack(player.Character)
		end
	end

	local function start()
		PlayerEvents.observe(onPlayerAdded, function() end)
		SpaceSimulation.start()
		-- Deaths happen outside the simulation: they change the character's lifecycle.
		RunService.PostSimulation:Connect(suffocateEmptyTanks)
	end

	return {
		name = "SpaceService",
		start = start,
	}
end

return table.freeze(SpaceService)
