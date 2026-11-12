--!strict
-- Whether a character is alive: one test for the flight simulation, the oxygen, the guardians and
-- PvP. Dead is dead even with health above zero: Roblox's Health script keeps healing a dead
-- humanoid, and the flight simulation, taking it for alive, switched it out of the Dead state
-- (ChangeState(Physics)), so Roblox never respawned the player (friends' playtest, 2026-11-12:
-- out of oxygen by the dome, the body hung there until they rejoined). Safe in the simulation.

local Vitals = {}

function Vitals.isAlive(humanoid: Humanoid): boolean
	return humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

return table.freeze(Vitals)
