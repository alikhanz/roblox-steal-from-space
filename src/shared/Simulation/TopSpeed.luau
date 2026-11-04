--!strict
-- The top flight speed a character flies at right now, studs per second: what the server set
-- from the speed stat, held down to the starting speed while slow mode is on (for careful
-- flying near nests). The simulation flies at it and guardians chase relative to it, so slow
-- mode changes the feel, not who wins a chase.

local FlightConfig = require("../Config/FlightConfig")
local SpeedConfig = require("../Config/SpeedConfig")

local TopSpeed = {}

function TopSpeed.of(character: Model): number
	local value = character:GetAttribute(SpeedConfig.FLIGHT_SPEED_ATTRIBUTE)
	local speed = if type(value) == "number" then value else SpeedConfig.FLIGHT.minFlightSpeed
	if character:GetAttribute(FlightConfig.SLOW_MODE_ATTRIBUTE) == true then
		return math.min(speed, SpeedConfig.FLIGHT.referenceFlightSpeed)
	end
	return speed
end

return table.freeze(TopSpeed)
