--!strict
-- What the hunters of space (guardians, the star serpent) need to know about the player they go
-- after, and how their strike throws them: one place, so both catch the same way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local TopSpeed = require(ReplicatedStorage.Shared.Simulation.TopSpeed)

-- The egg a prey carries, as far as its weight goes.
export type Load = {
	read rarity: EggConfig.RarityId,
	read size: EggConfig.SizeId,
}

local Prey = {}

-- Share of the speed stat the carried egg takes away; 0 empty-handed.
function Prey.eggWeight(load: Load?): number
	if not load then
		return 0
	end
	return Speed.eggWeight(EggConfig.RARITIES[load.rarity].weight, EggConfig.SIZES[load.size].weightFactor)
end

-- How fast a hunter with speed stat `power` flies after this prey right now, studs per second
-- (Speed.chaseSpeed): the prey's stat `stat` and its egg against the hunter's. Taken from the
-- prey's actual top speed (slow mode included), so the chase feels the same either way.
function Prey.chaseSpeed(character: Model, stat: BigNum.BigNum, load: Load?, power: BigNum.BigNum): number
	local weight = Prey.eggWeight(load)
	local flightSpeed = TopSpeed.of(character) * Speed.carryMultiplier(weight)
	return Speed.chaseSpeed(flightSpeed, power, Speed.withEgg(stat, weight), SpeedConfig.CHASE)
end

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
