--!strict
-- Floating "+12 ⚡" numbers over the local character while the trainer pays out: each payout
-- pops a label at the head that drifts up and fades. The HUD number itself follows the speed
-- attributes, so this is only the celebration.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local LABEL_SIZE = UDim2.fromOffset(160, 36)
local TEXT_SIZE = 24
-- Where a pop starts above the head and how far it rises, studs; a little sideways scatter so
-- consecutive pops do not stack into one.
local START_STUDS_ABOVE = 1.6
local RISE_STUDS = 2
local SCATTER_STUDS = 0.8
local RISE_SECONDS = 1.1

export type Dependencies = {
	profile: ProfileState.ProfileState,
}

export type TrainingViewController = {
	name: string,
	start: () -> (),
}

local TrainingViewController = {}

function TrainingViewController.new(dependencies: Dependencies): TrainingViewController
	local random = Random.new()

	local function pop(head: BasePart, text: string)
		local gui = Instance.new("BillboardGui")
		gui.Name = "TrainingPop"
		gui.Adornee = head
		gui.Size = LABEL_SIZE
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local scatter = random:NextNumber(-SCATTER_STUDS, SCATTER_STUDS)
		gui.StudsOffset = Vector3.new(scatter, START_STUDS_ABOVE, 0)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Theme.FONT
		label.TextSize = TEXT_SIZE
		label.TextColor3 = Theme.SPEED
		label.TextStrokeTransparency = 0.4
		label.Text = text
		label.Parent = gui
		gui.Parent = head

		local rise = TweenInfo.new(RISE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(gui, rise, { StudsOffset = Vector3.new(scatter, START_STUDS_ABOVE + RISE_STUDS, 0) }):Play()
		local fade = TweenInfo.new(RISE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(RISE_SECONDS, function()
			gui:Destroy()
		end)
	end

	local function start()
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		dependencies.profile.trained.connect(function(gain)
			local character = Players.LocalPlayer.Character
			local head = character and character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				pop(head, Text.get(locale, "trainer.gain.hint", { gain = BigNum.format(gain) }))
			end
		end)
	end

	return {
		name = "TrainingViewController",
		start = start,
	}
end

return table.freeze(TrainingViewController)
