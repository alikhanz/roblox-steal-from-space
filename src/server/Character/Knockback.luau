--!strict
-- A hit on a flyer: thrown at `velocity`, tumbling about `axis`, unable to steer for the stun.
-- Written as character attributes, which the simulation applies and the clients show (the
-- flames stall, the screen flashes). Guardians and players deal the same kind of hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)

local Knockback = {}

-- `by` names the attacker: GuardianConfig.HIT_BY_GUARDIAN or a player's name.
function Knockback.apply(character: Model, velocity: Vector3, axis: Vector3, stunSeconds: number, by: string)
	character:SetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE, velocity)
	character:SetAttribute(GuardianConfig.HIT_AXIS_ATTRIBUTE, axis)
	character:SetAttribute(GuardianConfig.HIT_BY_ATTRIBUTE, by)
	task.delay(stunSeconds, function()
		-- A newer hit may have replaced this one; only this hit's own stun is cleared.
		if character.Parent and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) == velocity then
			character:SetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE, nil)
			character:SetAttribute(GuardianConfig.HIT_AXIS_ATTRIBUTE, nil)
			character:SetAttribute(GuardianConfig.HIT_BY_ATTRIBUTE, nil)
		end
	end)
end

-- True while a hit's stun holds.
function Knockback.isStunned(character: Model): boolean
	return character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) ~= nil
end

return table.freeze(Knockback)
