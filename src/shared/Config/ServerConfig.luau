--!strict
-- Server-wide limits. MAX_PLAYERS must match Game Settings → Places → Max Players.

return table.freeze({
	-- One station bay per player.
	MAX_PLAYERS = 8,
})
