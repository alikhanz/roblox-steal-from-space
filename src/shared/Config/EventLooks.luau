--!strict
-- How server events show: each event's color on the banner, the big announcement and the pin to
-- where it is. Greybox; the art pass gives events their own looks.

local EventConfig = require("./EventConfig")

return table.freeze({
	COLORS = table.freeze({
		Storm = Color3.fromRGB(255, 170, 60),
	} :: { [EventConfig.EventId]: Color3 }),
	-- How long the big announcement stays, seconds.
	ANNOUNCE_SECONDS = 3.5,
})
