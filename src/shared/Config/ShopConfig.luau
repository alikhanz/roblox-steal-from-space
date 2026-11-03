--!strict
-- The jetpack shop on the station: one kiosk for everyone, where jetpack levels are bought.
-- Its place and looks are in ShopLooks.

return table.freeze({
	-- The kiosk model (replicated for the client's sign and prompt texts).
	TAG = "Shop",
	-- Instance names inside the kiosk model.
	SIGN_NAME = "Panel",
	COUNTER_NAME = "Counter",
	-- The prompt that opens the shop window works from this far, studs.
	PROMPT_DISTANCE = 9,
})
