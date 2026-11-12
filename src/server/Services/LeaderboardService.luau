--!strict
-- The coin board: coins earned all time (PlayerData.coinsEarned) in the player list of this
-- server (and on the player, for the owner's reward windows), and the top of all servers on the
-- board at the station. Scores go to a shared ranked
-- store; a failed write or read only delays the board (CONVENTIONS: leaderboards are derived
-- data). In Studio, where an unpublished place has no data stores, the board falls back to a
-- store in memory with the players of this playtest.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Leaderboard = require(ReplicatedStorage.Shared.Domain.Leaderboard)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local RankStore = require(script.Parent.Parent.Data.RankStore)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	getCoinBoard: () -> Model?,
	scheduler: Scheduler.Scheduler,
}

export type LeaderboardService = {
	name: string,
	start: () -> (),
}

-- Where one player on this server is at.
type Tracked = {
	stat: StringValue,
	earned: BigNum.BigNum,
	score: number,
	-- The score last written to the store.
	written: number,
}

-- One board row as the client gets it (LeaderboardController).
type Row = {
	userId: number,
	name: string,
	coins: { mantissa: number, exponent: number },
}

local LeaderboardService = {}

local function createStat(player: Player): StringValue
	local folder = Instance.new("Folder")
	-- The name the player list looks for.
	folder.Name = "leaderstats"
	local stat = Instance.new("StringValue")
	stat.Name = LeaderboardConfig.PLAYER_LIST_STAT
	stat.Value = BigNum.format(BigNum.ZERO)
	stat.Parent = folder
	folder.Parent = player
	return stat
end

function LeaderboardService.new(dependencies: Dependencies): LeaderboardService
	local tracked: { [Player]: Tracked } = {}
	local store = RankStore.ordered(LeaderboardConfig.STORE_NAME)
	local inMemory = false
	-- The top as last read from the store.
	local stored: { Leaderboard.Entry } = {}
	-- Display names of players who are not on this server, by user id.
	local names: { [number]: string } = {}
	-- The rows as the board last showed them: who, in what order, and the coins as the client
	-- formats them (CoinBoardController). Coins of a player here change every second, but the
	-- board shows three digits, so the rows go out only when what they show changes (each change
	-- is sent to every client; decision 101).
	local publishedShown = ""

	-- Names for stored rows of players who are not here, in one request.
	local function fetchNames(entries: { Leaderboard.Entry })
		local missing: { number } = {}
		for _, entry in entries do
			if not names[entry.userId] then
				table.insert(missing, entry.userId)
			end
		end
		if #missing == 0 then
			return
		end
		local ok, result = pcall(function(): { any }
			return UserService:GetUserInfosByUserIdsAsync(missing)
		end)
		if not ok then
			warn(`[LeaderboardService] Fetching names failed: {result}`)
			return
		end
		for _, info in result do
			if type(info.Id) == "number" and type(info.DisplayName) == "string" then
				names[info.Id] = info.DisplayName
			end
		end
	end

	-- Rebuilds the rows from the stored top and the players here; sends them out when what the
	-- board shows changed.
	local function publish()
		local board = dependencies.getCoinBoard()
		if not board then
			return
		end
		local live: { Leaderboard.Entry } = {}
		local here: { [number]: Player } = {}
		for player, state in tracked do
			table.insert(live, { userId = player.UserId, score = state.score })
			here[player.UserId] = player
		end
		local rows: { Row } = {}
		local shown: { string } = {}
		for _, entry in Leaderboard.top(stored, live, LeaderboardConfig.TOP_SIZE) do
			local player = here[entry.userId]
			local state = if player then tracked[player] else nil
			-- Players here show their exact count; stored rows are as precise as a score.
			local coins = if state then state.earned else Leaderboard.coinsOf(entry.score)
			local name = if player then player.DisplayName else names[entry.userId] or "?"
			table.insert(rows, {
				userId = entry.userId,
				name = name,
				coins = { mantissa = coins.mantissa, exponent = coins.exponent },
			})
			table.insert(shown, `{entry.userId}|{name}|{BigNum.format(coins)}`)
		end
		local key = table.concat(shown, "\n")
		local value = board:FindFirstChild(LeaderboardConfig.ROWS_VALUE_NAME)
		if key ~= publishedShown and value and value:IsA("StringValue") then
			publishedShown = key
			value.Value = HttpService:JSONEncode(rows)
		end
	end

	-- In Studio a place with no data stores keeps the board in memory instead.
	local function fallBackToMemory()
		print("[LeaderboardService] No data stores in this Studio session: the board shows this playtest only")
		inMemory = true
		store = RankStore.memory()
		for player, state in tracked do
			store.set(player.UserId, state.score)
			state.written = state.score
		end
	end

	local function readTop()
		local items, problem = store.top(LeaderboardConfig.TOP_SIZE)
		if not items and not inMemory and RunService:IsStudio() then
			fallBackToMemory()
			items, problem = store.top(LeaderboardConfig.TOP_SIZE)
		end
		if not items then
			warn(`[LeaderboardService] Reading the top failed: {problem}`)
			return
		end
		local entries = Leaderboard.fromPage(items)
		fetchNames(entries)
		stored = entries
		publish()
	end

	local function write(player: Player, state: Tracked)
		if state.score == state.written then
			return
		end
		-- Studio's test players have made-up ids: they never go to the shared board.
		if player.UserId <= 0 and not inMemory then
			return
		end
		local ok, problem = store.set(player.UserId, state.score)
		if ok then
			state.written = state.score
		else
			warn(`[LeaderboardService] Writing {player.Name}'s score failed: {problem}`)
		end
	end

	local function writeAll()
		for player, state in tracked do
			write(player, state)
		end
	end

	-- Follows each player's profile: the list column and the score.
	local function refresh()
		local changed = false
		for player, state in tracked do
			local data = dependencies.getData(player)
			if data and not BigNum.equals(data.coinsEarned, state.earned) then
				state.earned = data.coinsEarned
				state.score = Leaderboard.score(data.coinsEarned)
				state.stat.Value = BigNum.format(data.coinsEarned)
				player:SetAttribute(LeaderboardConfig.EARNED_MANTISSA_ATTRIBUTE, data.coinsEarned.mantissa)
				player:SetAttribute(LeaderboardConfig.EARNED_EXPONENT_ATTRIBUTE, data.coinsEarned.exponent)
				changed = true
			end
		end
		if changed then
			publish()
		end
	end

	local function onPlayerAdded(player: Player)
		tracked[player] = { stat = createStat(player), earned = BigNum.ZERO, score = 0, written = 0 }
	end

	local function onPlayerRemoving(player: Player)
		local state = tracked[player]
		tracked[player] = nil
		if state then
			task.spawn(write, player, state)
			publish()
		end
	end

	local function start()
		PlayerEvents.observe(onPlayerAdded, onPlayerRemoving)
		dependencies.scheduler.every(LeaderboardConfig.PLAYER_LIST_INTERVAL_SECONDS, refresh)
		-- Store calls yield, so they run outside the scheduler's step.
		dependencies.scheduler.every(LeaderboardConfig.WRITE_INTERVAL_SECONDS, function()
			task.spawn(writeAll)
		end)
		dependencies.scheduler.every(LeaderboardConfig.READ_INTERVAL_SECONDS, function()
			task.spawn(readTop)
		end)
		task.spawn(readTop)
	end

	return {
		name = "LeaderboardService",
		start = start,
	}
end

return table.freeze(LeaderboardService)
