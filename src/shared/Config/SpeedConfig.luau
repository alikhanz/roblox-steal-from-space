--!strict
-- The speed stat: where new players start, how it turns into flight, and how chases resolve.

local BigNum = require("../Domain/BigNum")
local Speed = require("../Domain/Speed")

local FLIGHT: Speed.FlightTuning = {
	referenceSpeed = 10,
	referenceFlightSpeed = 48,
	-- Stat 10 flies at 48, stat 100 billion at about 130.
	flightSpeedPerDecade = 8.2,
	minFlightSpeed = 30,
}

local CHASE: Speed.ChaseTuning = {
	ratioExponent = 0.5,
	minRatio = 0.6,
	maxRatio = 1.5,
}

return table.freeze({
	-- Every new player starts here; the first guardian is beatable right away.
	STARTING_SPEED = BigNum.fromNumber(10),
	FLIGHT = table.freeze(FLIGHT),
	CHASE = table.freeze(CHASE),
})
