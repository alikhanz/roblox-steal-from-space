--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The login gift on the client: the screen that opens by itself when today's gift waits (after
-- the welcome-back screen), the HUD button with a badge to open it again, and the celebration
-- when it is taken. Tile gifts are shown with the same formula the server pays with
-- (Domain/PlayReward), from the profile copy.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Button = require(script.Parent.Parent.UI.Button)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local LoginGiftConfig = require(ReplicatedStorage.Shared.Config.LoginGiftConfig)
local LoginGiftScreen = require(script.Parent.Parent.UI.LoginGiftScreen)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local PlayReward = require(ReplicatedStorage.Shared.Domain.PlayReward)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The gift button stands above the quests button, which stands above the bay button.
local BUTTON_ABOVE_BAY = 96
-- The screen waits this long after the profile arrived, so the welcome-back screen (sent right
-- after) comes first.
local OPEN_DELAY_SECONDS = 1.5
-- After a claim the screen stays a moment for the celebration.
local CLOSE_AFTER_CLAIM_SECONDS = 1.6
-- Today's tile breathes this much, this fast.
local PULSE_AMPLITUDE = 0.06
local PULSE_SPEED = 4

export type Dependencies = {
	profile: ProfileState.ProfileState,
	toasts: ToastState.ToastState,
	-- The welcome-back screen is up; the gift waits for it.
	welcomeOpen: () -> boolean,
}

export type LoginGiftController = {
	name: string,
	start: () -> (),
}

local LoginGiftController = {}

function LoginGiftController.new(dependencies: Dependencies): LoginGiftController
	local profile = dependencies.profile
	local toast = dependencies.toasts.push
	local isOpen = source(false)
	local pulse = source(1)
	-- Bumped every second while open, for the countdown.
	local clock = source(0)
	local locale: Text.Locale = "en"
	local screen: Instance? = nil
	local layer: ScreenGui? = nil

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local function eggName(): string
		return Names.egg(locale, LoginGiftConfig.EGG_RARITY) or "?"
	end

	-- What each streak day gives right now.
	local function tiles(): { LoginGiftScreen.Tile }
		local gift = profile.loginGift()
		local income = BigNum.ZERO
		for _, pod in profile.bay().pods do
			local alien = pod.alien and AlienConfig.ALIENS[pod.alien.id]
			if alien then
				income = BigNum.add(income, alien.income)
			end
		end
		local upgrades = profile.upgrades()
		local rate = Upgrades.trainerRate(upgrades.trainerLevel, UpgradeConfig.TUNING)
		local multiplier = Upgrades.jetpackMultiplier(upgrades.jetpackLevel, UpgradeConfig.TUNING)
		local result: { LoginGiftScreen.Tile } = {}
		for day, minutes in LoginGiftConfig.MINUTES do
			local coins, trained = PlayReward.worth(minutes, income, rate, LoginGiftConfig.MIN_REWARD_COINS)
			-- Taken: days before today, and today once its gift is in.
			local state: LoginGiftScreen.TileState = if day < gift.day or (day == gift.day and not gift.available)
				then "Taken"
				elseif day == gift.day then "Today"
				else "Ahead"
			table.insert(result, {
				title = text("gift.day.hint", { day = day }),
				coins = BigNum.format(coins),
				speed = BigNum.format(BigNum.mul(trained, multiplier)),
				egg = if day == LoginGiftConfig.EGG_DAY then eggName() else nil,
				state = state,
			})
		end
		return result
	end

	local function hint(): string
		local gift = profile.loginGift()
		if not gift.available then
			local _ = clock()
			local left = Quests.secondsLeftInDay(workspace:GetServerTimeNow())
			return text("gift.next.hint", { time = Duration.describe(locale, left) })
		end
		return if gift.reset then text("gift.reset.hint") else text("gift.streak.hint")
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			return create("ScreenGui")({
				Name = "LoginGiftUi",
				ResetOnSpawn = false,
				-- Over the HUD and the bay window, like the welcome-back screen.
				DisplayOrder = 20,
				Vide.action(function(gui)
					layer = gui :: ScreenGui
				end),

				Button({
					name = "OpenGift",
					text = text("gift.open.button"),
					badge = function()
						return if profile.loginGift().available then 1 else 0
					end,
					onClick = function()
						isOpen(not isOpen())
					end,
				}),
				Vide.action(function(gui)
					local button = gui:FindFirstChild("OpenGift") :: GuiObject
					button.AnchorPoint = Vector2.new(0, 1)
					button.Position = UDim2.new(0, Theme.MARGIN, 1, -(Theme.MARGIN + BUTTON_ABOVE_BAY))
				end),

				LoginGiftScreen.create({
					visible = function()
						return isOpen() and not dependencies.welcomeOpen()
					end,
					tiles = tiles,
					title = text("gift.window.title"),
					hint = hint,
					claim = text("gift.claim.button"),
					later = text("gift.later.button"),
					canClaim = function()
						return profile.loginGift().available
					end,
					pulse = pulse,
					onClaim = function()
						Remotes.ClaimLoginGift.Fire()
					end,
					onClose = function()
						isOpen(false)
					end,
				}, LoginGiftConfig.LENGTH),
				Vide.action(function(gui)
					screen = gui:FindFirstChild("LoginGift")
				end),
			})
		end, playerGui)
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[LoginGiftController] PlayerGui did not appear")
		mountUi(playerGui)

		-- Opens by itself whenever a gift starts waiting: on join, at UTC midnight online.
		local wasAvailable = false
		local function onGift()
			local available = profile.loginGift().available
			if available and not wasAvailable then
				task.delay(OPEN_DELAY_SECONDS, function()
					if profile.loginGift().available then
						isOpen(true)
					end
				end)
			end
			wasAvailable = available
		end
		Vide.root(function()
			Vide.effect(onGift)
		end)

		profile.giftRewarded.connect(function(reward)
			if screen and layer then
				LoginGiftScreen.burst(screen, layer, reward.day, Theme.COINS)
			end
			local paid = { coins = BigNum.format(reward.coins), speed = BigNum.format(reward.speed) }
			toast(text("gift.rewarded.toast", paid), Theme.TOAST_GOOD)
			if reward.egg then
				toast(text("gift.egg.toast", { egg = eggName() }), Theme.TOAST_GOOD)
			end
			task.delay(CLOSE_AFTER_CLAIM_SECONDS, function()
				isOpen(false)
			end)
		end)

		local elapsed = 0
		local sinceTick = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			if not isOpen() then
				return
			end
			elapsed += deltaTime
			pulse(1 + math.sin(elapsed * PULSE_SPEED) * PULSE_AMPLITUDE)
			sinceTick += deltaTime
			if sinceTick >= 1 then
				sinceTick = 0
				clock(clock() + 1)
			end
		end)
	end

	return {
		name = "LoginGiftController",
		start = start,
	}
end

return table.freeze(LoginGiftController)
