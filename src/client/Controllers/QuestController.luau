--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Daily quests on the client: the HUD button (with how many rewards wait), the quests window
-- and the toasts for a finished quest and a reward. Rows come from the profile copy; rewards
-- shown before a claim use the same formula the server pays with (Domain/Quests.reward).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Button = require(script.Parent.Parent.UI.Button)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local QuestWindow = require(script.Parent.Parent.UI.QuestWindow)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
local TOGGLE_KEY = Enum.KeyCode.J
-- The countdown to new quests is whole minutes and seconds: once a second is enough.
local COUNTDOWN_INTERVAL = 1
-- The quests button stands right above the bay button.
local BUTTON_ABOVE_BAY = 48

local TASK_KEYS: { [ProfileState.QuestKind]: Text.Key } = {
	DeliverEggs = "quest.deliverEggs.hint",
	DeliverFromZone = "quest.deliverFromZone.hint",
	HatchAliens = "quest.hatchAliens.hint",
	Train = "quest.train.hint",
	Crossbreed = "quest.crossbreed.hint",
	KnockEgg = "quest.knockEgg.hint",
}

export type Dependencies = {
	profile: ProfileState.ProfileState,
	toasts: ToastState.ToastState,
}

export type QuestController = {
	name: string,
	start: () -> (),
}

local QuestController = {}

local function isComplete(quest: ProfileState.Quest): boolean
	return quest.progress >= quest.target
end

function QuestController.new(dependencies: Dependencies): QuestController
	local profile = dependencies.profile
	local toast = dependencies.toasts.push
	local isOpen = source(false)
	-- Bumped every second while the window is open, so the countdown recomputes.
	local clock = source(0)
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local function zoneName(zoneId: string?): string
		local zone = zoneId and (ZoneConfig.ZONES :: any)[zoneId]
		return if zone then text(zone.nameKey) else "?"
	end

	local function taskText(quest: ProfileState.Quest): string
		-- Looked up through `any`: the union of every string key is too much for the checker.
		local key: Text.Key = (TASK_KEYS :: any)[quest.kind] or "quest.crossbreed.hint"
		if quest.kind == "Train" then
			return text(key, { count = math.ceil(quest.target / 60) })
		elseif quest.kind == "DeliverFromZone" then
			return text(key, { zone = zoneName(quest.zone) })
		end
		return text(key, { count = quest.target })
	end

	local function progressText(quest: ProfileState.Quest): string
		if quest.kind == "Train" then
			-- Minutes, like the task says.
			return `{math.floor(quest.progress / 60)}/{math.ceil(quest.target / 60)}`
		end
		return `{math.floor(quest.progress)}/{quest.target}`
	end

	-- What the quest pays right now, the way the server will pay it.
	local function rewardText(quest: ProfileState.Quest): string
		local definition = Quests.definition(QuestConfig.DEFINITIONS, quest.kind)
		local minutes = if definition then definition.rewardMinutes else 0
		local income = BigNum.ZERO
		for _, pod in profile.bay().pods do
			local alien = pod.alien and AlienConfig.ALIENS[pod.alien.id]
			if alien then
				income = BigNum.add(income, alien.income)
			end
		end
		local upgrades = profile.upgrades()
		local rate = Upgrades.trainerRate(upgrades.trainerLevel, UpgradeConfig.TUNING)
		local coins, trained = Quests.reward(minutes, income, rate, QuestConfig.MIN_REWARD_COINS)
		local speed = BigNum.mul(trained, Upgrades.jetpackMultiplier(upgrades.jetpackLevel, UpgradeConfig.TUNING))
		return `+{BigNum.format(coins)} ● · +{BigNum.format(speed)} ⚡`
	end

	local function rows(): { QuestWindow.Row }
		local current = profile.quests()
		local result: { QuestWindow.Row } = {}
		for _, quest in current.list do
			local state: "Active" | "Done" | "Claimed" = if quest.claimed
				then "Claimed"
				elseif isComplete(quest) then "Done"
				else "Active"
			local row: QuestWindow.Row = {
				task = taskText(quest),
				progress = quest.progress / math.max(quest.target, 1),
				progressText = progressText(quest),
				reward = rewardText(quest),
				state = state,
				canSwap = not current.rerolled,
			}
			table.insert(result, row)
		end
		return result
	end

	local function claimable(): number
		local count = 0
		for _, quest in profile.quests().list do
			if not quest.claimed and isComplete(quest) then
				count += 1
			end
		end
		return count
	end

	-- A quest that reached its target since the last update, on the same day: time to cheer.
	local seen: ProfileState.Quests? = nil
	local function watchQuests()
		local current = profile.quests()
		local previous = seen
		seen = current
		if not previous or previous.day ~= current.day then
			return
		end
		for index, quest in current.list do
			local before = previous.list[index]
			if before and before.kind == quest.kind and not isComplete(before) and isComplete(quest) then
				toast(text("quests.done.toast"), Theme.TOAST_GOOD)
			end
		end
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			Vide.effect(watchQuests)
			return create("ScreenGui")({
				Name = "QuestUi",
				ResetOnSpawn = false,
				DisplayOrder = 10,

				Button({
					name = "OpenQuests",
					text = function()
						local waiting = claimable()
						local label = text("quests.open.button")
						return if waiting > 0 then `{label} ({waiting})` else label
					end,
					onClick = function()
						isOpen(not isOpen())
					end,
				}),
				Vide.action(function(gui)
					local button = gui:FindFirstChild("OpenQuests") :: GuiObject
					button.AnchorPoint = Vector2.new(0, 1)
					button.Position = UDim2.new(0, Theme.MARGIN, 1, -(Theme.MARGIN + BUTTON_ABOVE_BAY))
				end),

				QuestWindow({
					visible = isOpen,
					rows = rows,
					texts = {
						title = text("quests.window.title"),
						resetIn = function()
							local _ = clock()
							local left = Quests.secondsLeftInDay(workspace:GetServerTimeNow())
							return text("quests.resetIn.hint", { time = Duration.describe(locale, left) })
						end,
						swapHint = function()
							return if profile.quests().rerolled
								then text("quests.swapUsed.hint")
								else text("quests.swap.hint")
						end,
						claim = text("quests.claim.button"),
						swap = text("quests.swap.button"),
						claimed = text("quests.claimed.hint"),
					},
					onClaim = function(index)
						Remotes.ClaimQuest.Fire(index)
					end,
					onSwap = function(index)
						Remotes.RerollQuest.Fire(index)
					end,
					onClose = function()
						isOpen(false)
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[QuestController] PlayerGui did not appear")
		mountUi(playerGui)

		profile.questRewarded.connect(function(coins, speed)
			toast(
				text("quests.rewarded.toast", { coins = BigNum.format(coins), speed = BigNum.format(speed) }),
				Theme.TOAST_GOOD
			)
		end)
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not gameProcessed and input.KeyCode == TOGGLE_KEY then
				isOpen(not isOpen())
			end
		end)
		local sinceTick = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			sinceTick += deltaTime
			if sinceTick >= COUNTDOWN_INTERVAL and isOpen() then
				sinceTick = 0
				clock(clock() + 1)
			end
		end)
	end

	return {
		name = "QuestController",
		start = start,
	}
end

return table.freeze(QuestController)
