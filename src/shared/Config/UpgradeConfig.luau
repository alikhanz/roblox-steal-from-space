--!strict
-- The trainer and jetpack upgrades (stage 4 builds them; the balance calculator already uses
-- the numbers). The speed stat is trained speed x jetpack multiplier.

local BigNum = require("../Domain/BigNum")

return table.freeze({
	-- Speed points per second on a level-0 trainer, and the gain per trainer level.
	TRAINER_BASE_RATE = BigNum.fromNumber(0.3),
	TRAINER_RATE_GROWTH = BigNum.fromNumber(1.6),
	-- Trainer level n costs TRAINER_COST_BASE * TRAINER_COST_GROWTH^(n-1) coins.
	TRAINER_COST_BASE = BigNum.fromNumber(300),
	TRAINER_COST_GROWTH = BigNum.fromNumber(5),

	-- Each jetpack level multiplies the whole speed stat by this.
	JETPACK_MULTIPLIER = BigNum.fromNumber(2),
	-- Jetpack level n costs JETPACK_COST_BASE * JETPACK_COST_GROWTH^(n-1) coins.
	JETPACK_COST_BASE = BigNum.fromNumber(2000),
	JETPACK_COST_GROWTH = BigNum.fromNumber(8),

	-- Training keeps going while the player is away: at this share of the rate, up to this long.
	OFFLINE_TRAINING_FACTOR = 0.5,
	OFFLINE_TRAINING_CAP_SECONDS = 8 * 60 * 60,
})
