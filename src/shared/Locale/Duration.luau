--!strict
-- A time span in words a kid reads at a glance: "40 seconds", "12 minutes", "1.5 hours".

local Text = require("./Text")

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * 60
-- Hours keep one decimal while they are few, so "1.5 hours" is not rounded to "2 hours".
local PRECISE_HOURS_LIMIT = 10

local Duration = {}

function Duration.describe(locale: Text.Locale, seconds: number): string
	seconds = math.max(0, seconds)
	if seconds < SECONDS_PER_MINUTE then
		return Text.get(locale, "time.seconds.hint", { count = math.ceil(seconds) })
	elseif seconds < SECONDS_PER_HOUR then
		return Text.get(locale, "time.minutes.hint", { count = math.ceil(seconds / SECONDS_PER_MINUTE) })
	end
	local hours = seconds / SECONDS_PER_HOUR
	if hours < PRECISE_HOURS_LIMIT then
		hours = math.ceil(hours * 10) / 10
	else
		hours = math.ceil(hours)
	end
	return Text.get(locale, "time.hours.hint", { count = hours })
end

return table.freeze(Duration)
