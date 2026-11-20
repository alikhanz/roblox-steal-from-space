--!strict
-- The bench's buttons (decision 082): fill the island with 30 aliens to measure it on a
-- phone, and take them away; set the Event Horizon's 42 guardians round the player, or a gallery
-- of one guardian a post, and take them away (BenchService.showGuardians); fill the island with the
-- pet gallery's next page, one family's aliens (BenchService.gallery; "/bench clear" takes it
-- away); the rejoin test (decision 146): the idle times before the rejoin shortened to 3 and 3.5
-- minutes, on and off. Shown only while the server marks the player as allowed
-- (DevConfig.BENCH_ATTRIBUTE: Studio, or the Dev game's creator). A developer's tool, not a
-- player's screen: plain instances, no brief, no localization (the labels are the commands' names).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local RejoinConfig = require(ReplicatedStorage.Shared.Config.RejoinConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- Open, the toggle and the six commands fit the shortest phone (Galaxy A16: 281 points under
-- Roblox's top bar).
local BUTTON_SIZE = UDim2.fromOffset(190, 32)
local BUTTON_COLOR = Color3.fromRGB(60, 70, 140)
local TEXT_SIZE = 16
local BUTTONS = 7
-- The one button the commands fold behind, its labels, and how far down the screen it stands:
-- near the top, so the commands hang down to the right of the menu row, not off the screen.
local TOGGLE_SIZE = UDim2.fromOffset(64, 30)
-- Plain ASCII: GothamBold has no arrows (they drew as empty boxes).
local FOLDED_LABEL = "dev +"
local OPEN_LABEL = "dev -"
local TOP_SHARE = 0.04
-- The gallery's button: the command, and with a page on the bench that page ("crab 1/2").
local GALLERY_LABEL = "/gallery pets"
-- The rejoin test's button, with its state ("on" / "off").
local REJOIN_LABEL = "/rejoin test"

export type BenchController = {
	name: string,
	start: () -> (),
}

local BenchController = {}

local function button(parent: Instance, text: string, order: number, press: () -> ()): TextButton
	local item = Instance.new("TextButton")
	item.Name = text
	item.LayoutOrder = order
	item.Size = BUTTON_SIZE
	item.BackgroundColor3 = BUTTON_COLOR
	item.BackgroundTransparency = 0.2
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = Color3.new(1, 1, 1)
	-- Scaled down to fit the longer gallery label, never above the usual size.
	item.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = TEXT_SIZE
	limit.Parent = item
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = item
	item.Text = text
	item.AutoLocalize = false
	Instance.new("UICorner").Parent = item
	item.Activated:Connect(function()
		press()
	end)
	item.Parent = parent
	return item
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
		-- Folded to one small button by default: always open, the commands hid the jump button
		-- and the flight buttons on a small phone (docs/design/screens/hud-menu-fold.md).
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -12, TOP_SHARE, 0)
		panel.Size = UDim2.fromOffset(BUTTON_SIZE.X.Offset, 0)
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.BackgroundTransparency = 1
		panel.Parent = gui
		local panelLayout = Instance.new("UIListLayout")
		panelLayout.Padding = UDim.new(0, 6)
		panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
		panelLayout.Parent = panel
		-- The commands, under the toggle.
		local column = Instance.new("Frame")
		column.Name = "Commands"
		column.LayoutOrder = 2
		column.Size = UDim2.fromOffset(BUTTON_SIZE.X.Offset, BUTTON_SIZE.Y.Offset * BUTTONS + 6 * (BUTTONS - 1))
		column.BackgroundTransparency = 1
		column.Visible = false
		column.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = column
		local toggle: TextButton
		toggle = button(panel, FOLDED_LABEL, 1, function()
			column.Visible = not column.Visible
			toggle.Text = if column.Visible then OPEN_LABEL else FOLDED_LABEL
		end)
		toggle.Size = TOGGLE_SIZE
		button(column, "/bench", 1, function()
			Remotes.Bench.Fire(true)
		end)
		button(column, "/bench clear", 2, function()
			Remotes.Bench.Fire(false)
		end)
		local gallery = button(column, GALLERY_LABEL, 3, function()
			Remotes.BenchGallery.Fire()
		end)
		button(column, "/bench guardians", 4, function()
			Remotes.BenchGuardians.Fire("Bench")
		end)
		button(column, "/gallery guardians", 5, function()
			Remotes.BenchGuardians.Fire("Gallery")
		end)
		button(column, "/bench guardians clear", 6, function()
			Remotes.BenchGuardians.Fire("Off")
		end)
		local function rejoinTesting(): boolean
			return player:GetAttribute(RejoinConfig.TEST_ATTRIBUTE) == true
		end
		local rejoin = button(column, REJOIN_LABEL, 7, function()
			Remotes.RejoinTest.Fire(not rejoinTesting())
		end)
		gui.Parent = playerGui

		local function show()
			gui.Enabled = player:GetAttribute(DevConfig.BENCH_ATTRIBUTE) == true
		end
		player:GetAttributeChangedSignal(DevConfig.BENCH_ATTRIBUTE):Connect(show)
		show()
		local function label()
			local page = player:GetAttribute(DevConfig.GALLERY_ATTRIBUTE)
			gallery.Text = if type(page) == "string" then `{GALLERY_LABEL}: {page}` else GALLERY_LABEL
		end
		player:GetAttributeChangedSignal(DevConfig.GALLERY_ATTRIBUTE):Connect(label)
		label()
		local function rejoinLabel()
			rejoin.Text = `{REJOIN_LABEL}: {if rejoinTesting() then "on" else "off"}`
		end
		player:GetAttributeChangedSignal(RejoinConfig.TEST_ATTRIBUTE):Connect(rejoinLabel)
		rejoinLabel()
	end

	return {
		name = "BenchController",
		start = start,
	}
end

return table.freeze(BenchController)
