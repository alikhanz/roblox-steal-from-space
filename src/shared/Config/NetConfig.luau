--!strict
-- Limits on what a client may send. Every command is rate limited per player before anything
-- else is checked (CONVENTIONS, section 5).

return table.freeze({
	-- Commands a player may send in a window, and the window, seconds. Generous for a human,
	-- tight for a script.
	COMMAND_LIMIT = 5,
	COMMAND_WINDOW_SECONDS = 1,
})
