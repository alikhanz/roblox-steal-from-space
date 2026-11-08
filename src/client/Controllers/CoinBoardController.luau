--!strict
-- Draws the coin board at the station in this client's language. The server publishes the rows
-- as a JSON attribute on the board model (LeaderboardService); this controller decodes them,
-- formats the coins and marks the player's own row.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CoinBoard = require(script.Parent.Parent.UI.CoinBoard)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
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

	local function watchBoard(instance: Instance)
		task.spawn(function()
			local panel = instance:WaitForChild(LeaderboardConfig.PANEL_NAME, PART_WAIT_TIMEOUT)
			local value = instance:WaitForChild(LeaderboardConfig.ROWS_VALUE_NAME, PART_WAIT_TIMEOUT)
			if
				not panel
				or not panel:IsA("BasePart")
				or not value
				or not value:IsA("StringValue")
				or not instance:IsDescendantOf(workspace)
			then
				warn(`[CoinBoardController] {instance:GetFullName()} is not a complete board; no board`)
				return
			end
			local rows = source(decodeRows(value.Value))
			local changed = value.Changed:Connect(function(json: string)
				rows(decodeRows(json))
			end)
			-- Drawn on the panel itself, so it goes away with it (streaming out, a rebuilt world).
			local unmount = Vide.mount(function()
				return CoinBoard({
					adornee = panel,
					title = text("leaderboard.board.title"),
					allTime = text("leaderboard.allTime.hint"),
					empty = text("leaderboard.empty.hint"),
					rows = rows,
					rowCount = LeaderboardConfig.TOP_SIZE,
				})
			end, panel)
			panel.Destroying:Once(function()
				changed:Disconnect()
				unmount()
			end)
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
