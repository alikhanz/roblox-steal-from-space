--!strict
-- Oxygen tank tuning. The tank is the soft limit on how long one flight lasts; it never grows,
-- a faster player simply gets further in the same time.

local Oxygen = require("../Domain/Oxygen")

local TUNING: Oxygen.Tuning = {
	drainPerSecond = 1,
	refillPerSecond = 25,
}

-- A catch by a guardian or the star serpent takes a share of a full tank (Oxygen.catchShare,
-- Oxygen.afterHit), the harder the hunter for this thief, the more (decision 112): a player
-- cannot haul eggs from guardians far past their stat by getting caught over and over, while
-- a guardian the player has outgrown costs little. A hit on a nearly empty tank empties it.
local CATCH_SHARES: Oxygen.CatchShares = {
	weak = 0.05,
	fair = 0.1,
	strong = 0.35,
	tooStrong = 0.9,
}

return table.freeze({
	-- One unit lasts one second in space at the base drain rate: about three minutes of flight.
	CAPACITY = 180,
	TUNING = table.freeze(TUNING),
	CATCH_SHARES = table.freeze(CATCH_SHARES),
	-- Below this share of a full tank the HUD warns the player.
	LOW_FRACTION = 0.25,
	-- Character attribute holding the current oxygen (simulation state).
	ATTRIBUTE = "Oxygen",
})
