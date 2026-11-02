--!strict
-- Oxygen supply: drains in space, refills under the station dome. Pure Luau.

local Oxygen = {}

export type Tuning = {
	-- Units lost per second in space.
	read drainPerSecond: number,
	-- Units restored per second under the dome.
	read refillPerSecond: number,
}

function Oxygen.step(current: number, capacity: number, inSpace: boolean, deltaTime: number, tuning: Tuning): number
	local change = if inSpace then -tuning.drainPerSecond else tuning.refillPerSecond
	return math.clamp(current + change * deltaTime, 0, capacity)
end

function Oxygen.isEmpty(current: number): boolean
	return current <= 0
end

-- Share of a full tank, for the HUD: 0..1.
function Oxygen.fraction(current: number, capacity: number): number
	if capacity <= 0 then
		return 0
	end
	return math.clamp(current / capacity, 0, 1)
end

return table.freeze(Oxygen)
