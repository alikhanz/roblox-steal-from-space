--!strict
-- The bench's buttons (decision 082): fill the island with 30 aliens to measure it on a
-- phone, and take them away; set the Event Horizon's 42 guardians round the player, or a gallery
-- of one guardian a post, and take them away (BenchService.showGuardians); fill the island with the
-- pet gallery's next page, one family's aliens (BenchService.gallery; "/bench clear" takes it
-- away). Shown only while the server marks the player as allowed
-- (DevConfig.BENCH_ATTRIBUTE: Studio, or the Dev game's creator). A developer's tool, not a
-- player's screen: plain instances, no brief, no localization (the labels are the commands' names).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)

local PLAYER_GUI_WAIT_TIMEOUT = 30
local BUTTON_SIZE = UDim2.fromOffset(190, 36)
local BUTTON_COLOR = Color3.fromRGB(60, 70, 140)
local TEXT_SIZE = 16
local BUTTONS = 6
-- The gallery's button: the command, and with a page on the bench that page ("crab 1/2").
local GALLERY_LABEL = "/gallery pets"

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
		local column = Instance.new("Frame")
		column.AnchorPoint = Vector2.new(1, 0.5)
		column.Position = UDim2.new(1, -12, 0.5, 0)
		column.Size = UDim2.fromOffset(BUTTON_SIZE.X.Offset, BUTTON_SIZE.Y.Offset * BUTTONS + 6 * (BUTTONS - 1))
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
	end

	return {
		name = "BenchController",
		start = start,
	}
end

return table.freeze(BenchController)
