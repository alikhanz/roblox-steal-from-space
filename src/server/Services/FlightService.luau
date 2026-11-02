--!strict
-- Prepares players for jetpack flight and runs the authoritative simulation.
-- Instances are created here, outside the simulation, as Server Authority requires.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlightConfig = require(ReplicatedStorage.Shared.Flight.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Flight.FlightInputs)
local JetpackSimulation = require(ReplicatedStorage.Shared.Flight.JetpackSimulation)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)

export type FlightService = {
	name: string,
	start: () -> (),
}

local FlightService = {}

local function equipCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		warn(`[FlightService] {character.Name} has no HumanoidRootPart`)
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
	align.MaxTorque = 0
	align.Responsiveness = 50

	attachment.Parent = root
	velocity.Parent = root
	align.Parent = root
end

function FlightService.new(): FlightService
	local function start()
		PlayerEvents.observe(function(player)
			FlightInputs.create().Parent = player
			player.CharacterAdded:Connect(equipCharacter)
			if player.Character then
				equipCharacter(player.Character)
			end
		end, function() end)
		JetpackSimulation.start()
	end

	return {
		name = "FlightService",
		start = start,
	}
end

return table.freeze(FlightService)
