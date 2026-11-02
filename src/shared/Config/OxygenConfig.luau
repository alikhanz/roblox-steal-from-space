--!strict
-- Oxygen tank tuning. Capacity becomes a trainable stat in stage 4.

local Oxygen = require("../Domain/Oxygen")

local TUNING: Oxygen.Tuning = {
	drainPerSecond = 1,
	refillPerSecond = 25,
}

return table.freeze({
	-- One unit lasts one second in space at the base drain rate.
	CAPACITY = 60,
	TUNING = table.freeze(TUNING),
	-- Below this share of a full tank the HUD warns the player.
	LOW_FRACTION = 0.25,
	-- Character attribute holding the current oxygen (simulation state).
	ATTRIBUTE = "Oxygen",
})
