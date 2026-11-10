--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The community gift on the client (decision 098, docs/design/screens/community.md): the HUD
-- menu tile and its window while the gift waits (after the tutorial), the invitation toast when
-- the tutorial ends, Roblox's own join prompt behind "Join", and the toast when the server pays.
-- The client never decides the gift: after the prompt it only asks the server to check.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CommunityConfig = require(ReplicatedStorage.Shared.Config.CommunityConfig)
local CommunityGift = require(ReplicatedStorage.Shared.Domain.CommunityGift)
local CommunityWindow = require(script.Parent.Parent.UI.CommunityWindow)
local MenuState = require(script.Parent.Parent.State.MenuState)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local ToastState = require(script.Parent.Parent.State.ToastState)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The button says "Checking…" at most this long, seconds: the server's check with its retries
-- (CommunityConfig) answers well within it.
local CHECK_TIMEOUT_SECONDS = 15

export type Dependencies = {
	profile: ProfileState.ProfileState,
	toasts: ToastState.ToastState,
	windows: WindowState.WindowState,
	menu: MenuState.MenuState,
	-- The tutorial is over (reactive), and the moment it ends (TutorialController).
	tutorialDone: () -> boolean,
	tutorialFinished: Signal.Signal<>,
}

export type CommunityController = {
	name: string,
	start: () -> (),
}

local CommunityController = {}

function CommunityController.new(dependencies: Dependencies): CommunityController
	local profile = dependencies.profile
	local player = Players.LocalPlayer
	local isOpen = dependencies.windows.slot("Community")
	local communityId = CommunityConfig.communityFor(game.GameId)
	-- The gift is taken (the server's attribute); nil: no profile yet.
	local taken = source(nil :: boolean?)
	local readTaken = taken :: () -> boolean?
	-- The server is checking after Roblox's prompt; the bumped number tells a timeout which check
	-- it belongs to.
	local checking = source(false)
	local checkNumber = 0
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local function waiting(): boolean
		return readTaken() == false and dependencies.tutorialDone()
	end

	-- The gift as the stat would show it with the jetpack worn now.
	local function giftText(): string
		local level = profile.upgrades().jetpackLevel
		return BigNum.format(CommunityGift.shown(CommunityConfig.GIFT_TRAINED, level, UpgradeConfig.TUNING))
	end

	local function stopChecking()
		checkNumber += 1
		checking(false)
	end

	local function join(community: number)
		if Vide.untrack(checking) then
			return
		end
		checkNumber += 1
		local number = checkNumber
		checking(true)
		Remotes.CommunityPrompted.Fire()
		local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, community)
		if not ok then
			warn(`[CommunityController] Roblox's community prompt failed: {status}`)
		end
		local joined = ok
			and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember)
		if not joined then
			if number == checkNumber then
				stopChecking()
			end
			return
		end
		Remotes.CommunityJoined.Fire()
		task.delay(CHECK_TIMEOUT_SECONDS, function()
			if number == checkNumber then
				stopChecking()
			end
		end)
	end

	local function mountUi(playerGui: Instance, community: number)
		Vide.mount(function()
			return create("ScreenGui")({
				Name = "CommunityUi",
				ResetOnSpawn = false,
				-- Over the HUD, like the other windows.
				DisplayOrder = 20,
				CommunityWindow({
					visible = function()
						return isOpen() and waiting()
					end,
					title = text("community.window.title"),
					coins = function()
						return BigNum.format(profile.coins())
					end,
					gift = giftText,
					hint = text("community.gift.hint"),
					button = function()
						return if checking() then text("community.checking.button") else text("community.join.button")
					end,
					canJoin = function()
						return not checking()
					end,
					onJoin = function()
						task.spawn(join, community)
					end,
					onClose = function()
						isOpen(false)
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		if not communityId then
			-- No community for this game: no invitation and no gift.
			return
		end
		local community = communityId
		locale = Text.localeOf(player)
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[CommunityController] PlayerGui did not appear")

		local function readAttribute()
			local value = player:GetAttribute(CommunityConfig.GIFT_TAKEN_ATTRIBUTE)
			taken(if type(value) == "boolean" then value else nil)
		end
		player:GetAttributeChangedSignal(CommunityConfig.GIFT_TAKEN_ATTRIBUTE):Connect(readAttribute)
		readAttribute()

		mountUi(playerGui, community)
		-- Last in the row: it goes away for good once the gift is taken.
		dependencies.menu.add({
			slot = "Community",
			badge = function()
				return if waiting() then 1 else 0
			end,
			visible = waiting,
			onPress = function()
				isOpen(not isOpen())
			end,
		})

		Remotes.CommunityRewarded.SetCallback(function(value)
			stopChecking()
			isOpen(false)
			local speed = BigNum.fromSaved(value)
			if speed then
				dependencies.toasts.push(text("community.rewarded.toast", { speed = BigNum.format(speed) }), "Speed")
			end
		end)
		profile.notice.connect(function(notice)
			if notice == "NotInCommunity" or notice == "TooFast" then
				stopChecking()
			end
		end)
		-- After the tutorial's farewell, unless the server has already found them in the community.
		dependencies.tutorialFinished.connect(function()
			if Vide.untrack(readTaken) == false then
				dependencies.toasts.push(text("community.invite.toast", { speed = Vide.untrack(giftText) }), "Speed")
			end
		end)
	end

	return {
		name = "CommunityController",
		start = start,
	}
end

return table.freeze(CommunityController)
