--!strict
-- The solar storm (EventConfig.EVENTS.Storm has its clock): while it lasts, nobody flies past
-- the station border, and every incubator runs much faster. Whoever is out in space past the
-- border when it starts is brought back to their spawn, and an egg in their hands goes back to
-- its home (Domain/Storm); eggs floating in space go home too.

local StationSize = require("./StationSize")

return table.freeze({
	-- The edge during the storm: the station border, where guardians stop too (one number for
	-- both, so the storm's ring and the guardians' line never drift apart).
	RANGE_RADIUS = StationSize.BORDER_RADIUS,
	-- Incubators run this many times faster during the storm.
	HATCH_RATE = 30,
})
