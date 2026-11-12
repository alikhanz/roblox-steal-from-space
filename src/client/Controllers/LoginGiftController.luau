--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The login gift on the client: the screen that opens by itself when today's gift waits (after
-- the welcome-back screen), the HUD menu tile with a badge to open it again, and the celebration
-- when it is taken. Tile gifts are shown with the same formula the server pays with
-- (Domain/PlayReward), from the profile copy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local LoginGiftConfig = require(ReplicatedStorage.Shared.Config.LoginGiftConfig)
local LoginGiftWindow = require(script.Parent.Parent.UI.LoginGiftWindow)
local MenuState = require(script.Parent.Parent.State.MenuState)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local Pace = require(script.Parent.Parent.State.Pace)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local SpeedState = require(script.Parent.Parent.State.SpeedState)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
local UtcDay = require(ReplicatedStorage.Shared.Domain.UtcDay)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
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
	-- The speed stat: a gift is capped by it (decision 114).
	speed: SpeedState.SpeedState,
	toasts: ToastState.ToastState,
	-- The welcome-back screen is up; the gift waits for it.
	welcomeOpen: () -> boolean,
	windows: WindowState.WindowState,
	menu: MenuState.MenuState,
}

export type LoginGiftController = {
	name: string,
	start: () -> (),
}

local LoginGiftController = {}

function LoginGiftController.new(dependencies: Dependencies): LoginGiftController
	local profile = dependencies.profile
	local toast = dependencies.toasts.push
	local isOpen = dependencies.windows.slot("LoginGift")
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
	local function tiles(): { LoginGiftWindow.Tile }
		local gift = profile.loginGift()
		local look = (EggLooks.RARITIES :: any)[LoginGiftConfig.EGG_RARITY]
		local result: { LoginGiftWindow.Tile } = {}
		for day, minutes in LoginGiftConfig.MINUTES do
			local cap = { share = LoginGiftConfig.MAX_SHARE_OF_EARNED, speed = dependencies.speed.speed }
			local coins, speed = Pace.reward(profile, minutes, LoginGiftConfig.MIN_REWARD_COINS, true, cap)
			-- Taken: days before today, and today once its gift is in.
			local state: LoginGiftWindow.TileState = if day < gift.day or (day == gift.day and not gift.available)
				then "Taken"
				elseif day == gift.day then "Today"
				else "Ahead"
			table.insert(result, {
				title = text("gift.day.hint", { day = day }),
				coins = BigNum.format(coins),
				speed = BigNum.format(speed),
				egg = if day == LoginGiftConfig.EGG_DAY then eggName() else nil,
				eggColor = if day == LoginGiftConfig.EGG_DAY and look then look.color else nil,
				state = state,
			})
		end
		return result
	end

	local function hint(): string
		local gift = profile.loginGift()
		if not gift.available then
			local _ = clock()
			local left = UtcDay.secondsLeft(workspace:GetServerTimeNow())
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

				LoginGiftWindow.create({
					visible = function()
						return isOpen() and not dependencies.welcomeOpen()
					end,
					coins = function()
						return BigNum.format(profile.coins())
					end,
					tiles = tiles,
					title = text("gift.window.title"),
					hint = hint,
					claim = text("gift.claim.button"),
					miss = text("gift.miss.hint"),
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
		locale = Text.localeOf(Players.LocalPlayer)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[LoginGiftController] PlayerGui did not appear")
		mountUi(playerGui)
		-- The tile in the HUD menu row: only while today's gift waits (none for a brand-new player
		-- before the first delivery, none once taken); last in the row, so it leaves no gap.
		dependencies.menu.add({
			slot = "Gift",
			badge = function()
				return if profile.loginGift().available then 1 else 0
			end,
			visible = function()
				return profile.loginGift().available
			end,
			onPress = function()
				isOpen(not isOpen())
			end,
		})

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
				LoginGiftWindow.burst(screen, layer, reward.day, Theme.NEON.ACTION.Coins)
			end
			local paid = { coins = BigNum.format(reward.coins), speed = BigNum.format(reward.speed) }
			-- The egg needs no toast of its own: the bay cheers every new egg in the incubator.
			toast(text("gift.rewarded.toast", paid), "Gift")
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
