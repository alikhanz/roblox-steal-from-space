--!strict
-- The coin board: who is on it, how often it is written and read. Players are ranked by coins
-- earned all time (PlayerData.coinsEarned), across all servers. Its place and looks are in
-- LeaderboardLooks.

return table.freeze({
	-- The ranked store all servers share. Changing the name starts a new board from nothing.
	STORE_NAME = "CoinsEarned_v1",
	-- Rows on the board.
	TOP_SIZE = 10,
	-- Each server writes its players' scores this often (only changed ones) and when a player
	-- leaves, seconds. Ranked-store writes are limited per minute per server.
	WRITE_INTERVAL_SECONDS = 300,
	-- Each server reads the top this often, seconds.
	READ_INTERVAL_SECONDS = 120,
	-- The player list column is refreshed this often, seconds.
	PLAYER_LIST_INTERVAL_SECONDS = 1,

	-- The board model (replicated for the client, who draws it in its own language).
	TAG = "CoinBoard",
	-- The parts the board is drawn on (one a screen), inside the model.
	PANEL_NAME = "Panel",
	-- The folder in the model of the coins each client turns: models, each round its pivot's Y.
	COINS_FOLDER_NAME = "Coins",
	-- StringValue in the model: the rows as JSON, [{ userId, name, coins = saved BigNum }], best
	-- first. Not an attribute: string attributes here take only 50 characters.
	ROWS_VALUE_NAME = "Rows",

	-- Player list column. One name for every language, so it is the coin sign the HUD uses.
	PLAYER_LIST_STAT = "●",
	-- On the player, refreshed with the list: coins earned all time as a BigNum's parts. The
	-- owner's quest and gift windows cap a reward by it (PlayReward.Limit, decision 114).
	EARNED_MANTISSA_ATTRIBUTE = "CoinsEarnedMantissa",
	EARNED_EXPONENT_ATTRIBUTE = "CoinsEarnedExponent",
})
