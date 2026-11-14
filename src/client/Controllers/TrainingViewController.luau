--!strict
-- Floating "+12 ⚡" numbers over the local character while they train (in flight or on the
-- stand): each batch from the server (about a second, decision 134) is shown as four pops, one
-- every quarter of a second (`Domain/Trickle`), each a label at the head that drifts up and fades.
-- The HUD number itself eases up by SpeedState, so this is only the celebration.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Trickle = require(ReplicatedStorage.Shared.Domain.Trickle)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)

local LABEL_SIZE = UDim2.fromOffset(160, 36)
local TEXT_SIZE = 24
-- Where a pop starts above the head and how far it rises, studs; a little sideways scatter so
-- consecutive pops do not stack into one.
local START_STUDS_ABOVE = 1.6
local RISE_STUDS = 2
local SCATTER_STUDS = 0.8
local RISE_SECONDS = 1.2
-- A pop as often as the server trains (it tells it a batch a second): four pops per batch.
local POP_SECONDS = UpgradeConfig.TRAINING_TICK_SECONDS
local POPS_PER_BATCH = math.max(math.round(UpgradeConfig.TRAINING_BATCH_SECONDS / POP_SECONDS), 1)
local TEXT_STROKE_TRANSPARENCY = 0.4
local PLAYER_GUI_WAIT_TIMEOUT = 30

type Pop = {
	gui: BillboardGui,
	label: TextLabel,
}

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
	-- Pops are reused (four a second while training; CONVENTIONS: frequent effects come from a
	-- pool). They live in PlayerGui, adorned to the head, so a respawn takes none of them away.
	local free: { Pop } = {}
	local playerGui: Instance? = nil

	local function make(parent: Instance): Pop
		local gui = Instance.new("BillboardGui")
		gui.Name = "TrainingPop"
		gui.Size = LABEL_SIZE
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.Enabled = false

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Theme.FONT
		label.TextSize = TEXT_SIZE
		label.TextColor3 = Theme.SPEED
		label.Parent = gui
		gui.Parent = parent
		return { gui = gui, label = label }
	end

	local function pop(head: BasePart, text: string)
		local parent = playerGui
		if not parent then
			return
		end
		local item = table.remove(free) or make(parent)
		local gui, label = item.gui, item.label
		gui.Adornee = head
		local scatter = random:NextNumber(-SCATTER_STUDS, SCATTER_STUDS)
		gui.StudsOffset = Vector3.new(scatter, START_STUDS_ABOVE, 0)
		label.Text = text
		label.TextTransparency = 0
		label.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
		gui.Enabled = true

		local rise = TweenInfo.new(RISE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(gui, rise, { StudsOffset = Vector3.new(scatter, START_STUDS_ABOVE + RISE_STUDS, 0) }):Play()
		local fade = TweenInfo.new(RISE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(RISE_SECONDS, function()
			gui.Enabled = false
			table.insert(free, item)
		end)
	end

	local function start()
		playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[TrainingViewController] PlayerGui did not appear; no training pops")
		end
		local locale = Text.localeOf(Players.LocalPlayer)
		local trickle = Trickle.new()
		-- Seconds since the last pop, while pieces are left.
		local sincePop = 0

		local function popNext()
			local gain = Trickle.take(trickle)
			if not gain or BigNum.isZero(gain) then
				return
			end
			local character = Players.LocalPlayer.Character
			local head = character and character:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				-- The payout is in speed points; the stat grows by them times the jetpack.
				local jetpackLevel = dependencies.profile.upgrades().jetpackLevel
				local shown = BigNum.mul(gain, Upgrades.jetpackMultiplier(jetpackLevel, UpgradeConfig.TUNING))
				pop(head, Text.get(locale, "trainer.gain.hint", { gain = BigNum.format(shown) }))
			end
		end

		-- A batch pops its first piece at once and the rest one a quarter-second apart; one coming
		-- before the last batch has popped whole takes over what it had left.
		dependencies.profile.trained.connect(function(gain)
			Trickle.add(trickle, gain, POPS_PER_BATCH)
			sincePop = 0
			popNext()
		end)
		RunService.Heartbeat:Connect(function(dt)
			if trickle.left <= 0 then
				return
			end
			sincePop += dt
			if sincePop >= POP_SECONDS then
				sincePop -= POP_SECONDS
				popNext()
			end
		end)
	end

	return {
		name = "TrainingViewController",
		start = start,
	}
end

return table.freeze(TrainingViewController)
