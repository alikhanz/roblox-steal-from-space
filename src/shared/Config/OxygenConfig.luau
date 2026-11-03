--!strict
-- Oxygen tank tuning. The tank is the soft limit on how long one flight lasts; it never grows,
-- a faster player simply gets further in the same time.

local Oxygen = require("../Domain/Oxygen")

local TUNING: Oxygen.Tuning = {
	drainPerSecond = 1,
	refillPerSecond = 25,
}

return table.freeze({
	-- One unit lasts one second in space at the base drain rate: about three minutes of flight.
	CAPACITY = 180,
	TUNING = table.freeze(TUNING),
	-- Below this share of a full tank the HUD warns the player.
	LOW_FRACTION = 0.25,
	-- Character attribute holding the current oxygen (simulation state).
	ATTRIBUTE = "Oxygen",
})
