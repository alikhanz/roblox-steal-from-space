--!strict
-- Draws the coin board at the station in this client's language, on each of its screens, and
-- turns its coins (decision 087). The server publishes the rows as JSON in a value on the board
-- model (LeaderboardService); this controller decodes them, formats the coins and marks the
-- player's own row.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CoinBoard = require(script.Parent.Parent.UI.CoinBoard)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local LeaderboardLooks = require(ReplicatedStorage.Shared.Config.LeaderboardLooks)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local StationShape = require(ReplicatedStorage.Shared.Config.StationShape)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local PART_WAIT_TIMEOUT = 10

export type CoinBoardController = {
	name: string,
	start: () -> (),
}

local CoinBoardController = {}

-- The rows in an attribute value; broken rows are skipped, a broken value gives none.
local function decodeRows(value: unknown): { CoinBoard.Row }
	if type(value) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	if not ok or type(decoded) ~= "table" then
		return {}
	end
	local rows: { CoinBoard.Row } = {}
	for _, item in decoded do
		local coins = type(item) == "table" and BigNum.fromSaved(item.coins)
		if coins and type(item.name) == "string" and type(item.userId) == "number" then
			table.insert(rows, {
				place = #rows + 1,
				name = item.name,
				coins = BigNum.format(coins),
				own = item.userId == Players.LocalPlayer.UserId,
			})
		end
	end
	return rows
end

function CoinBoardController.new(): CoinBoardController
	local locale: Text.Locale = "en"

	local function text(key: Text.Key): string
		return Text.get(locale, key)
	end

	-- The board's coins turning about their pivots, until the board goes. Coins stream in and out,
	-- so each frame turns whichever are there, from the pivot each had when first seen. The
	-- pivots are kept in a plain table, cleared as a coin goes: in a weak one Luau drops a coin's
	-- entry while the coin lives, its turned pivot is taken for the rest one, and the coin jumps
	-- (playtest 2026-11-10).
	local function turnCoins(board: Instance, folder: Instance)
		if GuiService.ReducedMotionEnabled then
			return
		end
		local pivots: { [Instance]: CFrame } = {}
		local removed = folder.ChildRemoved:Connect(function(child)
			pivots[child] = nil
		end)
		local turning = RunService.RenderStepped:Connect(function()
			local turn = CFrame.Angles(0, os.clock() / LeaderboardLooks.COIN_TURN_SECONDS * math.pi * 2, 0)
			for _, child in folder:GetChildren() do
				if child:IsA("Model") then
					local pivot = pivots[child] or child:GetPivot()
					pivots[child] = pivot
					child:PivotTo(pivot * turn)
				end
			end
		end)
		board.Destroying:Once(function()
			turning:Disconnect()
			removed:Disconnect()
		end)
	end

	local function watchBoard(instance: Instance)
		task.spawn(function()
			local value = instance:WaitForChild(LeaderboardConfig.ROWS_VALUE_NAME, PART_WAIT_TIMEOUT)
			if not value or not value:IsA("StringValue") or not instance:IsDescendantOf(workspace) then
				warn(`[CoinBoardController] {instance:GetFullName()} has no rows; no board`)
				return
			end
			local rows = source(decodeRows(value.Value))
			local changed = value.Changed:Connect(function(json: string)
				rows(decodeRows(json))
			end)
			-- Far from the board: the screens show the top three big.
			local far = source(false)
			local middle = StationConfig.PLATFORM_CENTER
				+ LeaderboardLooks.POSITION
				+ Vector3.yAxis * StationShape.BOARD_SCREEN_MIDDLE
			local sinceCheck = math.huge
			local checking = RunService.Heartbeat:Connect(function(delta: number)
				sinceCheck += delta
				local camera = workspace.CurrentCamera
				if sinceCheck < LeaderboardLooks.FAR_CHECK_SECONDS or not camera then
					return
				end
				sinceCheck = 0
				far((camera.CFrame.Position - middle).Magnitude > LeaderboardLooks.FAR_DISTANCE)
			end)
			instance.Destroying:Once(function()
				changed:Disconnect()
				checking:Disconnect()
			end)
			-- Drawn on each panel itself, as it streams in, so it goes away with it (streaming out,
			-- a rebuilt world). A panel streamed out and back in keeps its drawing.
			-- A plain table, cleared as a panel goes (instances are no keys for a weak one).
			local drawn: { [Instance]: true } = {}
			local function draw(panel: Instance)
				if drawn[panel] or panel.Name ~= LeaderboardConfig.PANEL_NAME or not panel:IsA("BasePart") then
					return
				end
				drawn[panel] = true
				panel.Destroying:Once(function()
					drawn[panel] = nil
				end)
				local unmount = Vide.mount(function()
					return CoinBoard({
						adornee = panel,
						title = text("leaderboard.board.title"),
						allTime = text("leaderboard.allTime.hint"),
						empty = text("leaderboard.empty.hint"),
						rows = rows,
						rowCount = LeaderboardConfig.TOP_SIZE,
						far = far,
					})
				end, panel)
				panel.Destroying:Once(unmount)
			end
			for _, child in instance:GetChildren() do
				draw(child)
			end
			instance.ChildAdded:Connect(draw)
			local coins = instance:WaitForChild(LeaderboardConfig.COINS_FOLDER_NAME, PART_WAIT_TIMEOUT)
			if coins then
				turnCoins(instance, coins)
			end
		end)
	end

	local function start()
		locale = Text.localeOf(Players.LocalPlayer)
		for _, instance in CollectionService:GetTagged(LeaderboardConfig.TAG) do
			watchBoard(instance)
		end
		CollectionService:GetInstanceAddedSignal(LeaderboardConfig.TAG):Connect(watchBoard)
	end

	return {
		name = "CoinBoardController",
		start = start,
	}
end

return table.freeze(CoinBoardController)
