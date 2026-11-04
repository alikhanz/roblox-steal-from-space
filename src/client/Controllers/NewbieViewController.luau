--!strict
-- A "Newbie" sign over every other player under newbie protection, so nobody wastes a strike
-- on them and everyone sees who is off limits. Follows the player attribute the server keeps.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mount = require(script.Parent.Parent.UI.Mount)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local HEAD_WAIT_TIMEOUT = 10
local STUDS_ABOVE = 3
local MAX_DISTANCE = 150

export type NewbieViewController = {
	name: string,
	start: () -> (),
}

local NewbieViewController = {}

function NewbieViewController.new(): NewbieViewController
	local unmounts: { [Model]: () -> () } = {}
	local locale: Text.Locale = "en"

	local function secondsLeft(player: Player): number
		local value = player:GetAttribute(PvpConfig.NEWBIE_ATTRIBUTE)
		return if type(value) == "number" then value else 0
	end

	local function hide(character: Model)
		local unmount = unmounts[character]
		if unmount then
			unmounts[character] = nil
			unmount()
		end
	end

	local function show(player: Player, character: Model)
		if unmounts[character] then
			return
		end
		task.spawn(function()
			local head = character:WaitForChild("Head", HEAD_WAIT_TIMEOUT)
			if not head or not head:IsA("BasePart") or unmounts[character] or secondsLeft(player) <= 0 then
				return
			end
			unmounts[character] = Mount.instance(function()
				return WorldLabel({
					adornee = head,
					title = Text.get(locale, "pvp.newbie.title"),
					value = "",
					valueColor = Theme.TOAST_GOOD,
					studsAbove = STUDS_ABOVE,
					maxDistance = MAX_DISTANCE,
				})
			end, character)
		end)
	end

	local function refresh(player: Player)
		local character = player.Character
		if not character then
			return
		end
		if secondsLeft(player) > 0 then
			show(player, character)
		else
			hide(character)
		end
	end

	local function watch(player: Player)
		if player == Players.LocalPlayer then
			return
		end
		player:GetAttributeChangedSignal(PvpConfig.NEWBIE_ATTRIBUTE):Connect(function()
			refresh(player)
		end)
		player.CharacterAdded:Connect(function()
			refresh(player)
		end)
		player.CharacterRemoving:Connect(hide)
		refresh(player)
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		Players.PlayerAdded:Connect(watch)
	end

	return {
		name = "NewbieViewController",
		start = start,
	}
end

return table.freeze(NewbieViewController)
