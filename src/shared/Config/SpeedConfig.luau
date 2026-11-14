--!strict
-- The speed stat: where new players start, how it turns into flight, and how chases resolve.

local BigNum = require("../Domain/BigNum")
local Speed = require("../Domain/Speed")

local FLIGHT: Speed.FlightTuning = {
	referenceSpeed = 10,
	referenceFlightSpeed = 48,
	-- Stat 10 flies at 48, stat 1 trillion (the last guardian) at about 250.
	flightSpeedPerDecade = 18.4,
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
	-- A guardian this many tenfolds below the player's stat is "Weak" (Speed.challenge): about
	-- two posts back, an egg not worth the trip.
	CHALLENGE_WEAK_DECADES = 1,

	-- Player attributes: the stat as a BigNum, for the HUD and for anyone looking at a player.
	MANTISSA_ATTRIBUTE = "SpeedMantissa",
	EXPONENT_ATTRIBUTE = "SpeedExponent",
	-- Character attribute: top flight speed without an egg, studs per second (the simulation
	-- reads it; the server derives it from the stat so the simulation never touches BigNum).
	FLIGHT_SPEED_ATTRIBUTE = "FlightSpeed",
	-- The server writes FlightSpeed again only once it moved by this much, studs per second: the
	-- character is a predicted instance, and every write from outside the simulation reaches its
	-- owner as a correction (decision 134).
	FLIGHT_SPEED_STEP = 0.5,
})
