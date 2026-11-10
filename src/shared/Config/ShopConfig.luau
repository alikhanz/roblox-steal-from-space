--!strict
-- The jetpack shop on the station: one kiosk for everyone, where jetpack levels are bought. The
-- kiosk is the station's capsule kiosk "Jetpacks" (StationLooks, World/KioskModel).

return table.freeze({
	-- The kiosk model (replicated for the client's prompt texts).
	TAG = "Shop",
	-- The attachment at a kiosk's counter that holds its prompt.
	PROMPT_POINT_NAME = "PromptPoint",
	-- The prompt that opens the shop window works from this far, studs.
	PROMPT_DISTANCE = 9,
})
