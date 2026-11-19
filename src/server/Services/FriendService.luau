--!strict
-- Who plays with their Roblox friends (decision 128, Domain/FriendBonus). When a player joins,
-- the server asks Roblox about them and each player already here, once per pair; the answer
-- holds until one of the two leaves. The count of friends here travels as a player attribute
-- (FriendConfig.FRIENDS_ATTRIBUTE) for the HUD; BayService pays the bonus from `friendsHere`.
-- Only the server decides who is a friend: the client never says so.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FriendBonus = require(ReplicatedStorage.Shared.Domain.FriendBonus)
local FriendConfig = require(ReplicatedStorage.Shared.Config.FriendConfig)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local RateLimit = require(ReplicatedStorage.Shared.Domain.RateLimit)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

export type Dependencies = {
	scheduler: Scheduler.Scheduler,
}

export type FriendService = {
	name: string,
	start: () -> (),
	-- How many of the player's friends play on this server now (with the Studio command's
	-- pretend ones).
	friendsHere: (player: Player) -> number,
	-- The count changed: the player, the count now and before.
	changed: Signal.Signal<Player, number, number>,
	-- Fired every FriendConfig.METRICS_MINUTE_SECONDS for each player with friends here, with
	-- their count (analytics: minutes played together).
	playedMinute: Signal.Signal<Player, number>,
	-- The player came in through an invite or a referral link (Roblox's join data).
	joinedByInvite: Signal.Signal<Player>,
	-- The client says Roblox's invite prompt closed having sent `sent` invites (analytics only).
	-- Rate limited; nothing is given for it.
	reportInvites: (player: Player, sent: number) -> (),
	invited: Signal.Signal<Player, number>,
	-- Studio command: the player counts `count` more friends here than they have (0: none).
	setPretend: (player: Player, count: number) -> (),
}

local FriendService = {}

function FriendService.new(dependencies: Dependencies): FriendService
	local changed = Signal.new() :: Signal.Signal<Player, number, number>
	local playedMinute = Signal.new() :: Signal.Signal<Player, number>
	local joinedByInvite = Signal.new() :: Signal.Signal<Player>
	local invited = Signal.new() :: Signal.Signal<Player, number>
	local circle = FriendBonus.newCircle()
	local inviteLimit = RateLimit.new(1, FriendConfig.INVITE_REPORT_SECONDS)
	-- Players on the server (an answer that comes after one of the two left is dropped).
	local present: { [Player]: boolean } = {}
	-- The count last published per player.
	local published: { [Player]: number } = {}
	local pretend: { [Player]: number } = {}

	local function friendsHere(player: Player): number
		return circle.countOf(player.UserId) + (pretend[player] or 0)
	end

	local function publish(player: Player)
		if not present[player] then
			return
		end
		local count = friendsHere(player)
		local before = published[player]
		if before == count then
			return
		end
		published[player] = count
		player:SetAttribute(FriendConfig.FRIENDS_ATTRIBUTE, count)
		if before then
			changed.fire(player, count, before)
		end
	end

	-- Whether Roblox has the two as friends; nil when it did not answer. Yields.
	local function areFriends(player: Player, other: Player): boolean?
		for attempt = 1, FriendConfig.CHECK_ATTEMPTS do
			local ok, result = pcall(player.IsFriendsWithAsync, player, other.UserId)
			if ok and type(result) == "boolean" then
				return result
			end
			warn(
				`[FriendService] Roblox did not say if {player.Name} and {other.Name} are friends (try {attempt}): {result}`
			)
			if attempt < FriendConfig.CHECK_ATTEMPTS then
				task.wait(FriendConfig.CHECK_RETRY_SECONDS)
			end
		end
		return nil
	end

	local function noteReferral(player: Player)
		local ok, data = pcall(player.GetJoinData, player)
		-- The referral's inviter is not in the engine's type of the join data.
		local referredBy = if ok and type(data) == "table" then (data :: any).ReferredByPlayerId else nil
		if type(referredBy) == "number" and referredBy ~= 0 then
			joinedByInvite.fire(player)
		end
	end

	local function onAdded(player: Player)
		present[player] = true
		publish(player)
		noteReferral(player)
		for _, other in Players:GetPlayers() do
			if other ~= player and present[other] then
				task.spawn(function()
					if areFriends(player, other) and present[player] and present[other] then
						circle.link(player.UserId, other.UserId)
						publish(player)
						publish(other)
					end
				end)
			end
		end
	end

	local function onRemoving(player: Player)
		present[player] = nil
		published[player] = nil
		pretend[player] = nil
		inviteLimit.forget(tostring(player.UserId))
		for _, userId in circle.forget(player.UserId) do
			local friend = Players:GetPlayerByUserId(userId)
			if friend then
				publish(friend)
			end
		end
	end

	local function start()
		PlayerEvents.observe(onAdded, onRemoving)
		dependencies.scheduler.every(FriendConfig.METRICS_MINUTE_SECONDS, function()
			for player in present do
				local count = friendsHere(player)
				if count > 0 then
					playedMinute.fire(player, count)
				end
			end
		end)
	end

	return {
		name = "FriendService",
		start = start,
		friendsHere = friendsHere,
		changed = changed,
		playedMinute = playedMinute,
		joinedByInvite = joinedByInvite,
		invited = invited,
		reportInvites = function(player: Player, sent: number)
			if sent ~= sent or sent < 0 or sent % 1 ~= 0 then
				return
			end
			if not inviteLimit.allow(tostring(player.UserId), os.clock()) then
				return
			end
			invited.fire(player, sent)
		end,
		setPretend = function(player: Player, count: number)
			assert(count >= 0 and count % 1 == 0, "pretend friends come in whole players")
			pretend[player] = if count > 0 then count else nil
			publish(player)
		end,
	}
end

return table.freeze(FriendService)
