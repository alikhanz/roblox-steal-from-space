--!strict
-- A player's bay on the station: pods, inventory, crossbreeding, selling and offline income.

local BigNum = require("../Domain/BigNum")

return table.freeze({
	-- Pods a new player owns; more are bought with coins.
	STARTING_PODS = 3,
	MAX_PODS = 12,
	-- Bought pod number n (counting the starting ones) costs
	-- POD_PRICE_BASE * POD_PRICE_GROWTH^(n - STARTING_PODS - 1).
	POD_PRICE_BASE = BigNum.fromNumber(250),
	POD_PRICE_GROWTH = BigNum.fromNumber(3),

	INVENTORY_SLOTS = 10,

	-- Aliens of one grade that make one crossbreed.
	CROSSBREED_COUNT = 3,
	-- Luck of a crossbreed (see Hatch.shiftedWeights): the result tilts toward the top tiers.
	CROSSBREED_LUCK = 0.5,

	-- Selling an alien pays this many seconds of its income: placing it is always the better deal.
	SELL_INCOME_SECONDS = 120,

	-- Pods keep earning while the player is away, up to this long.
	OFFLINE_INCOME_CAP_SECONDS = 4 * 60 * 60,
	-- Pods pay out this often (CONVENTIONS, performance: income at 1 Hz).
	INCOME_TICK_SECONDS = 1,
})
