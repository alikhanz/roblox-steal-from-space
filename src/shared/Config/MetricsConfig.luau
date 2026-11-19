--!strict
-- What the launch analytics measure (decisions 126, 131, 143): the posts of the day-1 wall and the
-- ranges times are sorted into. Analytics fields hold strings, so a time goes out as the label of
-- its range; every range ends below its `limit`, seconds, and the last one is open.
-- Never rename a label once live: Creator Hub groups events by the exact text.

export type Range = {
	read limit: number,
	read label: string,
}

return table.freeze({
	-- The day-1 wall (decision 131): a free player beats post 10 in the first session and post 11
	-- after a night of training. The time between their first deliveries is what is measured.
	WALL_FROM_POST = 10,
	WALL_TO_POST = 11,

	-- One session's length. Three minutes is the stop signal of decision 126 (new players who
	-- leave that early); Roblox's recommendations also penalise leaving in the first minute.
	SESSION_RANGES = table.freeze({
		table.freeze({ limit = 60, label = "0-1 min" }),
		table.freeze({ limit = 3 * 60, label = "1-3 min" }),
		table.freeze({ limit = 10 * 60, label = "3-10 min" }),
		table.freeze({ limit = 30 * 60, label = "10-30 min" }),
		table.freeze({ limit = 60 * 60, label = "30-60 min" }),
		table.freeze({ limit = 2 * 60 * 60, label = "1-2 h" }),
		table.freeze({ limit = math.huge, label = "2 h+" }),
	} :: { Range }),

	-- Real time from post 10 to post 11: in one sitting, the same day, or after coming back.
	WALL_REAL_RANGES = table.freeze({
		table.freeze({ limit = 60 * 60, label = "Real - 0-1 h" }),
		table.freeze({ limit = 4 * 60 * 60, label = "Real - 1-4 h" }),
		table.freeze({ limit = 24 * 60 * 60, label = "Real - 4-24 h" }),
		table.freeze({ limit = 2 * 24 * 60 * 60, label = "Real - 1-2 d" }),
		table.freeze({ limit = 7 * 24 * 60 * 60, label = "Real - 2-7 d" }),
		table.freeze({ limit = math.huge, label = "Real - 7 d+" }),
	} :: { Range }),

	-- Time in the game from post 10 to post 11 (to hold against `lune run balance`).
	WALL_PLAY_RANGES = table.freeze({
		table.freeze({ limit = 15 * 60, label = "Play - 0-15 min" }),
		table.freeze({ limit = 30 * 60, label = "Play - 15-30 min" }),
		table.freeze({ limit = 60 * 60, label = "Play - 30-60 min" }),
		table.freeze({ limit = 2 * 60 * 60, label = "Play - 1-2 h" }),
		table.freeze({ limit = 4 * 60 * 60, label = "Play - 2-4 h" }),
		table.freeze({ limit = math.huge, label = "Play - 4 h+" }),
	} :: { Range }),
})
