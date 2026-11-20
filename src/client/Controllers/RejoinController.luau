--!strict
-- The client's side of the rejoin before Roblox's idle kick (decision 146,
-- docs/design/screens/rejoin.md). Roblox tells the client how long the player has had no input
-- (Player.Idled: first after 2 minutes, then about every 30 s). At RejoinConfig's warning time a
-- toast says the game will reconnect; any input takes it away. At the request time the client
-- asks the server, which decides by its own view of the player, and sets the screen Roblox shows
-- while the teleport runs. The developer's test (the bench's "/rejoin test", the player
-- attribute RejoinConfig.TEST_ATTRIBUTE) uses the shorter times.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local Rejoin = require(ReplicatedStorage.Shared.Domain.Rejoin)
local RejoinConfig = require(ReplicatedStorage.Shared.Config.RejoinConfig)
local RejoinScreen = require(script.Parent.Parent.UI.RejoinScreen)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local ToastState = require(script.Parent.Parent.State.ToastState)

local TOAST_GROUP = "Rejoin"

local NORMAL: Rejoin.Thresholds = {
	warnAt = RejoinConfig.WARN_IDLE_SECONDS,
	requestAt = RejoinConfig.REQUEST_IDLE_SECONDS,
}
local TEST: Rejoin.Thresholds = {
	warnAt = RejoinConfig.TEST_WARN_IDLE_SECONDS,
	requestAt = RejoinConfig.TEST_REQUEST_IDLE_SECONDS,
}

-- Input that means the player is back: the toast goes.
local BACK_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.Touch] = true,
}

export type Dependencies = {
	toasts: ToastState.ToastState,
}

export type RejoinController = {
	name: string,
	start: () -> (),
}

local RejoinController = {}

function RejoinController.new(dependencies: Dependencies): RejoinController
	local player = Players.LocalPlayer
	local warned = false
	-- os.clock of the last request; nil: none this idle stretch.
	local askedAt: number? = nil
	local screenSet = false

	local function back()
		if warned then
			warned = false
			dependencies.toasts.dismiss(TOAST_GROUP)
		end
		askedAt = nil
	end

	local function showWarning(locale: Text.Locale)
		if warned then
			return
		end
		warned = true
		dependencies.toasts.push(Text.get(locale, "rejoin.soon.toast"), "Rejoin", nil, {
			group = TOAST_GROUP,
			detail = Text.get(locale, "rejoin.soon.hint"),
			seconds = RejoinConfig.TOAST_SECONDS,
		})
	end

	local function ask(locale: Text.Locale)
		-- The server ignores a repeat sooner than this; after a failed teleport it tries again.
		if askedAt and os.clock() - askedAt < RejoinConfig.RETRY_GAP_SECONDS then
			return
		end
		if not screenSet then
			screenSet = true
			local screen = RejoinScreen({
				title = Text.get(locale, "rejoin.screen.title"),
				hint = Text.get(locale, "rejoin.screen.hint"),
			})
			-- Typed as a GuiObject, but Roblox takes the ScreenGui itself (its own docs' example).
			TeleportService:SetTeleportGui(screen :: any)
		end
		askedAt = os.clock()
		Remotes.RequestRejoin.Fire()
	end

	local function onIdled(idleSeconds: number)
		local thresholds = if player:GetAttribute(RejoinConfig.TEST_ATTRIBUTE) == true then TEST else NORMAL
		local step = Rejoin.clientStep(idleSeconds, thresholds)
		if step == "None" then
			return
		end
		local locale = Text.localeOf(player)
		showWarning(locale)
		if step == "Request" then
			ask(locale)
		end
	end

	local function start()
		player.Idled:Connect(onIdled)
		UserInputService.InputBegan:Connect(back)
		UserInputService.InputChanged:Connect(function(input)
			if BACK_INPUTS[input.UserInputType] then
				back()
			end
		end)
	end

	return {
		name = "RejoinController",
		start = start,
	}
end

return table.freeze(RejoinController)
