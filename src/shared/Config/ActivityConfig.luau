--!strict
-- Who is actually playing (Domain/Activity, ActivityService). Used where idle players must not
-- count: the meteor shower's egg count; later perhaps a limit on how long one may stay idle.

return table.freeze({
	-- Counts as moving once this far from where the player last was, studs: more than a jump in
	-- place, less than a few steps.
	MOVE_STUDS = 10,
	-- Away after this long without moving or a command, seconds.
	IDLE_SECONDS = 3 * 60,
	-- How often positions are looked at, seconds.
	SAMPLE_SECONDS = 1,
})
