--!strict
-- What the hunters of space (guardians, the star serpent) need to know about the player they go
-- after, and how their strike throws them: one place, so both catch the same way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)

local Prey = {}

-- The player's living character and its root, or nil if there is nothing to chase.
function Prey.root(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, root
	end
	return nil, nil
end

-- Out in space (not walking on the station).
function Prey.inSpace(character: Model): boolean
	return character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
end

export type Strike = {
	-- Away from the hunter: where the prey is thrown.
	direction: Vector3,
	-- Across the throw: the tumble's axis, and where a knocked-out egg flies off.
	sideways: Vector3,
	-- How a knocked-out egg flies: off to the side and back past the hunter, so getting it back
	-- takes a turn.
	eggLaunch: Vector3,
}

-- The strike of a hunter at `from` on the prey at `root`.
function Prey.strike(from: Vector3, root: BasePart): Strike
	local away = root.Position - from
	local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis
	local sideways = direction:Cross(Vector3.yAxis)
	if sideways.Magnitude < 1e-3 then
		sideways = Vector3.xAxis
	end
	sideways = sideways.Unit
	return {
		direction = direction,
		sideways = sideways,
		eggLaunch = (sideways * 0.8 - direction * 0.6).Unit * EggConfig.DROP_SPEED,
	}
end

return table.freeze(Prey)
