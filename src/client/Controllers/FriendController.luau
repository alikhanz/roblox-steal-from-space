--!strict
-- Friends on the client (decision 128, docs/design/screens/friends.md): a toast when the friend
-- bonus changes, and the "Invite a friend" menu tile that opens Roblox's own invite prompt. The
-- tile shows only where Roblox lets this player invite. Nothing is given for an invite: the
-- client only reports how many went out (analytics).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local FriendBonus = require(ReplicatedStorage.Shared.Domain.FriendBonus)
local FriendConfig = require(ReplicatedStorage.Shared.Config.FriendConfig)
local FriendState = require(script.Parent.Parent.State.FriendState)
local MenuState = require(script.Parent.Parent.State.MenuState)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local ToastState = require(script.Parent.Parent.State.ToastState)
local Vide = require(ReplicatedStorage.Packages.Vide)

-- Toasts about friends replace each other: three friends joining at once leave one toast.
local TOAST_GROUP = "Friends"
-- Roblox counts at most this many in one report (the remote carries a byte).
local MAX_REPORTED_INVITES = 255

export type Dependencies = {
	friends: FriendState.FriendState,
	toasts: ToastState.ToastState,
	menu: MenuState.MenuState,
}

export type FriendController = {
	name: string,
	start: () -> (),
}

local FriendController = {}

function FriendController.new(dependencies: Dependencies): FriendController
	local player = Players.LocalPlayer
	local canInvite = Vide.source(false)
	local locale: Text.Locale = "en"

	local function toast(now: number, before: number)
		local percent = FriendBonus.percentOf(now)
		if percent == FriendBonus.percentOf(before) then
			-- A fourth friend past the cap, or one of four leaving: the bonus is the same.
			return
		end
		local text = if now > before
			then Text.get(locale, "friends.joined.toast", { percent = percent })
			elseif percent > 0 then Text.get(locale, "friends.left.toast", { percent = percent })
			else Text.get(locale, "friends.leftAll.toast")
		local detail = if now > before
			then Text.get(locale, "friends.rule.hint", {
				step = FriendConfig.PERCENT_PER_FRIEND,
				max = FriendBonus.maxPercent(),
			})
			else nil
		dependencies.toasts.push(text, "Friends", nil, { group = TOAST_GROUP, detail = detail })
	end

	-- Whether Roblox lets this player send invites here (it varies by platform and player).
	local function checkInvites()
		local ok, result = pcall(SocialService.CanSendGameInviteAsync, SocialService, player, nil)
		if not ok then
			warn(`[FriendController] Roblox did not say whether invites are allowed: {result}`)
		end
		canInvite(ok and result == true)
	end

	local function invite()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = Text.get(locale, "friends.invite.hint", { step = FriendConfig.PERCENT_PER_FRIEND })
		local ok, problem = pcall(SocialService.PromptGameInvite, SocialService, player, options)
		if not ok then
			warn(`[FriendController] Roblox's invite prompt failed: {problem}`)
		end
	end

	local function start()
		locale = Text.localeOf(player)
		dependencies.friends.changed.connect(toast)
		dependencies.menu.add({
			slot = "Invite",
			visible = function()
				return canInvite()
			end,
			onPress = invite,
		})
		SocialService.GameInvitePromptClosed:Connect(function(closedFor: Instance, recipients: { any })
			if closedFor == player then
				Remotes.FriendInvitesSent.Fire(math.min(#recipients, MAX_REPORTED_INVITES))
			end
		end)
		task.spawn(checkInvites)
	end

	return {
		name = "FriendController",
		start = start,
	}
end

return table.freeze(FriendController)
