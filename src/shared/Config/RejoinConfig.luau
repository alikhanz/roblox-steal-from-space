--!strict
-- The rejoin before Roblox's idle kick (decision 146, Domain/Rejoin, RejoinService,
-- docs/design/screens/rejoin.md). Roblox disconnects a player after 20 minutes with no input;
-- training idle on the stand is part of the game, so a little before that the game moves the
-- player to a server again, which starts Roblox's timer over. Plain values: Lune loads them.

return table.freeze({
	-- Roblox's own idle kick, seconds: everything below must happen before it.
	ROBLOX_KICK_SECONDS = 20 * 60,
	-- The client's idle times (Player.Idled: first after 2 minutes, then about every 30 s): the
	-- warning toast, then the request. 30 s apart, one Idled step: the toast shows about as long
	-- as the brief says; the request leaves three minutes for saving and two teleport tries.
	WARN_IDLE_SECONDS = 16.5 * 60,
	REQUEST_IDLE_SECONDS = 17 * 60,
	-- The same for the developer's test ("/rejoin test" on the bench, Dev game's creator only): a
	-- rejoin after 3.5 minutes instead of 17. Past the server's "away" (ActivityConfig.IDLE_SECONDS,
	-- 3 minutes) by one Idled step, so the server agrees.
	TEST_WARN_IDLE_SECONDS = 3 * 60,
	TEST_REQUEST_IDLE_SECONDS = 3.5 * 60,

	-- At most one rejoin a player this often, seconds; the time is in the profile, so it holds on
	-- the next server too. In the developer's test, so two rejoins fit in one sitting.
	COOLDOWN_SECONDS = 15 * 60,
	TEST_COOLDOWN_SECONDS = 60,
	-- A new request this soon after the last one tried is dropped without a word, seconds (a
	-- client asking again every Idled step; a spammer). Also the wait before a retry after a
	-- failed teleport.
	RETRY_GAP_SECONDS = 60,
	-- The arriving server puts the player back on the stand only if the rejoin started this
	-- recently, seconds (a player who left mid-teleport and comes back tomorrow just spawns).
	RESTORE_SECONDS = 5 * 60,
	-- How long the arriving server looks for the character and the stand to put the player on it.
	RESTORE_WAIT_SECONDS = 30,
	RESTORE_POLL_SECONDS = 0.5,
	-- How long the server waits for the store to confirm the save before teleporting, seconds;
	-- no confirmation, no rejoin (the player stays).
	SAVE_TIMEOUT_SECONDS = 30,
	-- A teleport that neither fails nor takes the player away in this long is given up, seconds.
	TELEPORT_TIMEOUT_SECONDS = 60,
	-- The warning toast stays this long (past the request, until the teleport screen covers it).
	TOAST_SECONDS = 45,

	-- On the Player: the developer's test is on (the client's shorter idle times).
	TEST_ATTRIBUTE = "RejoinTest",
	-- In the teleport data: the test stays on after the rejoin. Only the creator's test reads it
	-- (teleport data passes through the client), never anything a player gets.
	TEST_DATA_KEY = "rejoinTest",
})
