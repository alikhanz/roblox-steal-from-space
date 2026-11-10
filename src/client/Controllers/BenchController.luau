--!strict
-- The bench's buttons (decision 082): fill the island with 30 aliens to measure it on a
-- phone, and take them away; set the Event Horizon's 42 guardians round the player and take them
-- away (BenchService.showGuardians). Shown only while the server marks the player as allowed
-- (DevConfig.BENCH_ATTRIBUTE: Studio, or the Dev game's creator). A developer's tool, not a
-- player's screen: plain instances, no brief, no localization (the labels are the commands' names).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local PLAYER_GUI_WAIT_TIMEOUT = 30
local BUTTON_SIZE = UDim2.fromOffset(190, 36)
local BUTTON_COLOR = Color3.fromRGB(60, 70, 140)

export type BenchController = {
	name: string,
	start: () -> (),
}

local BenchController = {}

local function button(parent: Instance, text: string, order: number, press: () -> ())
	local item = Instance.new("TextButton")
	item.Name = text
	item.LayoutOrder = order
	item.Size = BUTTON_SIZE
	item.BackgroundColor3 = BUTTON_COLOR
	item.BackgroundTransparency = 0.2
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextSize = 16
	item.Text = text
	item.AutoLocalize = false
	Instance.new("UICorner").Parent = item
	item.Activated:Connect(function()
		press()
	end)
	item.Parent = parent
end

function BenchController.new(): BenchController
	local function start()
		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "Bench"
		gui.ResetOnSpawn = false
		gui.AutoLocalize = false
		gui.Enabled = false
		local column = Instance.new("Frame")
		column.AnchorPoint = Vector2.new(1, 0.5)
		column.Position = UDim2.new(1, -12, 0.5, 0)
		column.Size = UDim2.fromOffset(BUTTON_SIZE.X.Offset, BUTTON_SIZE.Y.Offset * 4 + 6 * 3)
		column.BackgroundTransparency = 1
		column.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = column
		button(column, "/bench", 1, function()
			Remotes.Bench.Fire(true)
		end)
		button(column, "/bench clear", 2, function()
			Remotes.Bench.Fire(false)
		end)
		button(column, "/bench guardians", 3, function()
			Remotes.BenchGuardians.Fire(true)
		end)
		button(column, "/bench guardians clear", 4, function()
			Remotes.BenchGuardians.Fire(false)
		end)
		gui.Parent = playerGui

		local function show()
			gui.Enabled = player:GetAttribute(DevConfig.BENCH_ATTRIBUTE) == true
		end
		player:GetAttributeChangedSignal(DevConfig.BENCH_ATTRIBUTE):Connect(show)
		show()
	end

	return {
		name = "BenchController",
		start = start,
	}
end

return table.freeze(BenchController)
