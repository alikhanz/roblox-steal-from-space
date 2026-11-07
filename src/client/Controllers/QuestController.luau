--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- Daily quests on the client: the HUD menu tile (with how many rewards wait), the quests window
-- and the toasts for a finished quest and a reward. Rows come from the profile copy; rewards
-- shown before a claim use the same formula the server pays with (Domain/PlayReward via Pace).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local Icons = require(script.Parent.Parent.UI.Icons)
local MenuState = require(script.Parent.Parent.State.MenuState)
local Pace = require(script.Parent.Parent.State.Pace)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local QuestWindow = require(script.Parent.Parent.UI.QuestWindow)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local ToastState = require(script.Parent.Parent.State.ToastState)
local UtcDay = require(ReplicatedStorage.Shared.Domain.UtcDay)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The countdown to new quests is whole minutes and seconds: once a second is enough.
local COUNTDOWN_INTERVAL = 1
-- A first tap on "Swap" waits this long for the second one, then the card calms down.
local SWAP_CONFIRM_SECONDS = 3

local TASK_ICONS: { [ProfileState.QuestKind]: Icons.Name } = {
	DeliverEggs = "Egg",
	DeliverFromZone = "Egg",
	HatchAliens = "Bay",
	Train = "Bolt",
	Crossbreed = "Index",
	KnockEgg = "Strike",
}

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
	windows: WindowState.WindowState,
	menu: MenuState.MenuState,
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
	local isOpen = dependencies.windows.slot("Quests")
	-- Bumped every second while the window is open, so the countdown recomputes.
	local clock = source(0)
	-- The quest whose swap waits for a second tap. Read through a plain getter: Vide types an
	-- optional source ambiguously when called without arguments.
	local pendingSwap = source(nil :: number?)
	local readPendingSwap = pendingSwap :: () -> number?
	-- Each first tap gets its own number, so an old timer never calms a newer tap.
	local swapTaps = 0
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

	-- What the quest pays right now, the way the server will pay it: coins and ⚡, formatted.
	local function rewardTexts(quest: ProfileState.Quest): (string, string)
		local definition = Quests.definition(QuestConfig.DEFINITIONS, quest.kind)
		local minutes = if definition then definition.rewardMinutes else 0
		local coins, speed = Pace.reward(profile, minutes, QuestConfig.MIN_REWARD_COINS, true)
		return BigNum.format(coins), BigNum.format(speed)
	end

	local function rows(): { QuestWindow.Row }
		local current = profile.quests()
		local pending = readPendingSwap()
		local result: { QuestWindow.Row } = {}
		for index, quest in current.list do
			local state: QuestWindow.State = if quest.claimed
				then "Claimed"
				elseif isComplete(quest) then "Done"
				else "Active"
			local coins, speed = rewardTexts(quest)
			local row: QuestWindow.Row = {
				icon = (TASK_ICONS :: any)[quest.kind] or "Quests",
				task = taskText(quest),
				progress = quest.progress / math.max(quest.target, 1),
				progressText = progressText(quest),
				coins = coins,
				speed = speed,
				state = state,
				canSwap = not current.rerolled,
				confirming = pending == index,
			}
			table.insert(result, row)
		end
		return result
	end

	-- A swap takes two taps: the first asks "Sure?", the second swaps. Unanswered, the question
	-- goes away by itself.
	local function swap(index: number)
		if readPendingSwap() == index then
			pendingSwap(nil)
			Remotes.RerollQuest.Fire(index)
			return
		end
		swapTaps += 1
		local tap = swapTaps
		pendingSwap(index)
		task.delay(SWAP_CONFIRM_SECONDS, function()
			if swapTaps == tap and readPendingSwap() == index then
				pendingSwap(nil)
			end
		end)
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
				toast(text("quests.done.toast"), "Good")
			end
		end
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			Vide.effect(watchQuests)
			-- A closed window forgets a half-made swap.
			Vide.effect(function()
				if not isOpen() then
					pendingSwap(nil)
				end
			end)
			return create("ScreenGui")({
				Name = "QuestUi",
				ResetOnSpawn = false,
				DisplayOrder = 10,

				QuestWindow({
					visible = function()
						return isOpen()
					end,
					coins = function()
						return BigNum.format(profile.coins())
					end,
					rows = rows,
					texts = {
						title = text("quests.window.title"),
						resetIn = function()
							local _ = clock()
							local left = UtcDay.secondsLeft(workspace:GetServerTimeNow())
							return text("quests.resetIn.hint", { time = Duration.describe(locale, left) })
						end,
						swapHint = function()
							return if profile.quests().rerolled
								then text("quests.swapUsed.hint")
								else text("quests.swap.hint")
						end,
						claim = text("quests.claim.button"),
						swap = text("quests.swap.button"),
						confirm = text("quests.confirm.hint"),
						claimed = text("quests.claimed.hint"),
					},
					onClaim = function(index)
						pendingSwap(nil)
						Remotes.ClaimQuest.Fire(index)
					end,
					onSwap = swap,
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
			toast(text("quests.rewarded.toast", { coins = BigNum.format(coins), speed = BigNum.format(speed) }), "Good")
		end)
		-- The tile in the HUD menu row, with how many finished quests wait to be claimed; its key
		-- (J) is answered by MenuState.
		dependencies.menu.add({
			slot = "Quests",
			badge = claimable,
			onPress = function()
				isOpen(not isOpen())
			end,
		})
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
