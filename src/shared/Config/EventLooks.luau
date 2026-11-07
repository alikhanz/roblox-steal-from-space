--!strict
-- How server events show: each event's color on the banner, the big announcement and the pin to
-- where it is. Greybox; the art pass gives events their own looks.

local EventConfig = require("./EventConfig")

return table.freeze({
	COLORS = table.freeze({
		Storm = Color3.fromRGB(255, 170, 60),
		Meteor = Color3.fromRGB(255, 110, 70),
		Serpent = Color3.fromRGB(150, 120, 255),
	} :: { [EventConfig.EventId]: Color3 }),
	-- Each event's icon on its line and over its announcement (a name in the client's UI/Icons).
	ICONS = table.freeze({
		Storm = "Sun",
		Meteor = "Meteor",
		Serpent = "Serpent",
	} :: { [EventConfig.EventId]: string }),
	-- How long the big announcement stays, seconds.
	ANNOUNCE_SECONDS = 3.5,
})
