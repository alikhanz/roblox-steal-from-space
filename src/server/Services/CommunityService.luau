--!strict
-- The gift for joining the game's Roblox community (decision 098, Domain/CommunityGift). Only the
-- server asks Roblox whether a player is in the community: when their profile activates, when
-- they finish the tutorial, and when the client says Roblox's join prompt went through. Found in
-- it, the player gets the gift once per profile. Whether it is taken travels as a player
-- attribute (CommunityConfig.GIFT_TAKEN_ATTRIBUTE) for the invitation on the client.
--
-- Membership comes from GroupService:GetGroupsAsync, not Player:IsInGroupAsync: the latter caches
-- its first answer on the server, so a player who joins in the game would stay "not a member"
-- until they rejoin (the prompt clears only the client's cache).

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CommunityConfig = require(ReplicatedStorage.Shared.Config.CommunityConfig)
local CommunityGift = require(ReplicatedStorage.Shared.Domain.CommunityGift)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local RateLimit = require(ReplicatedStorage.Shared.Domain.RateLimit)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Tutorial = require(ReplicatedStorage.Shared.Domain.Tutorial)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

export type Notice = "NotInCommunity" | "TooFast"
-- What started a check: the profile activating or the tutorial ending (Auto), or the client
-- after Roblox's join prompt (Prompt).
export type CheckSource = "Auto" | "Prompt"

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- The tutorial reached progress `progress` (TutorialService.advanced).
	tutorialAdvanced: Signal.Signal<Player, number>,
	publishSpeed: (player: Player) -> (),
	-- A refusal for a toast on the client (NetService.notify).
	notify: (player: Player, notice: Notice) -> (),
}

export type CommunityService = {
	name: string,
	start: () -> (),
	-- The gift was paid: the speed stat it added.
	rewarded: Signal.Signal<Player, BigNum.BigNum>,
	-- Roblox answered a check: whether the player is in the community.
	checked: Signal.Signal<Player, boolean, CheckSource>,
	-- The client is about to show Roblox's join prompt.
	prompted: Signal.Signal<Player>,
	-- The client says the prompt went through: checks with Roblox, never on the client's word.
	joined: (player: Player) -> Notice?,
	notePrompt: (player: Player) -> Notice?,
	-- Studio command: the gift is not taken again, and this session's automatic checks are
	-- skipped, so a member sees the invitation (the prompt's check still asks Roblox).
	reset: (player: Player) -> boolean,
}

local CommunityService = {}

function CommunityService.new(dependencies: Dependencies): CommunityService
	local rewarded = Signal.new() :: Signal.Signal<Player, BigNum.BigNum>
	local checked = Signal.new() :: Signal.Signal<Player, boolean, CheckSource>
	local prompted = Signal.new() :: Signal.Signal<Player>
	local communityId = CommunityConfig.communityFor(game.GameId)
	local recheckLimit = RateLimit.new(1, CommunityConfig.RECHECK_SECONDS)
	-- Players with a check under way: one at a time each.
	local checking: { [Player]: boolean } = {}
	-- Players whose automatic checks are off for this session (Studio command).
	local skipAuto: { [Player]: boolean } = {}

	local function publish(player: Player)
		local data = dependencies.getData(player)
		if data then
			player:SetAttribute(CommunityConfig.GIFT_TAKEN_ATTRIBUTE, data.communityGiftTaken)
		end
	end

	-- Whether Roblox has the player in the community; nil when it did not answer.
	local function isMember(player: Player, community: number): boolean?
		for attempt = 1, CommunityConfig.CHECK_ATTEMPTS do
			local ok, result = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
			if ok and type(result) == "table" then
				return CommunityGift.isMember(result, community)
			end
			warn(`[CommunityService] Roblox did not list {player.Name}'s communities (try {attempt}): {result}`)
			if attempt < CommunityConfig.CHECK_ATTEMPTS then
				task.wait(CommunityConfig.CHECK_RETRY_SECONDS)
			end
		end
		return nil
	end

	local function isOffered(player: Player): boolean
		local data = dependencies.getData(player)
		return data ~= nil and CommunityGift.isOffered(data)
	end

	-- Asks Roblox and pays the gift to a member. Yields.
	local function check(player: Player, source: CheckSource)
		if not communityId or checking[player] or not isOffered(player) then
			return
		end
		checking[player] = true
		local member = isMember(player, communityId)
		checking[player] = nil
		if member ~= nil then
			checked.fire(player, member, source)
		end
		if not member then
			if source == "Prompt" then
				dependencies.notify(player, "NotInCommunity")
			end
			return
		end
		-- The wait may have outlived the session or a parallel payout: the profile decides again.
		local shown: BigNum.BigNum? = nil
		dependencies.update(player, function(data)
			if CommunityGift.claim(data, CommunityConfig.GIFT_TRAINED) then
				shown = CommunityGift.shown(CommunityConfig.GIFT_TRAINED, data.jetpackLevel, UpgradeConfig.TUNING)
			end
		end)
		if shown then
			dependencies.publishSpeed(player)
			publish(player)
			rewarded.fire(player, shown)
		end
	end

	local function autoCheck(player: Player)
		if not skipAuto[player] then
			check(player, "Auto")
		end
	end

	local function joined(player: Player): Notice?
		if not communityId or not isOffered(player) then
			return nil
		end
		if not recheckLimit.allow(tostring(player.UserId), os.clock()) then
			return "TooFast"
		end
		task.spawn(check, player, "Prompt")
		return nil
	end

	local function reset(player: Player): boolean
		local written = dependencies.update(player, function(data)
			data.communityGiftTaken = false
		end)
		if written then
			skipAuto[player] = true
			publish(player)
		end
		return written
	end

	local function start()
		dependencies.activated.connect(function(player)
			publish(player)
			task.spawn(autoCheck, player)
		end)
		dependencies.tutorialAdvanced.connect(function(player, progress)
			if progress >= Tutorial.DONE then
				task.spawn(autoCheck, player)
			end
		end)
		PlayerEvents.observe(function() end, function(player)
			checking[player] = nil
			skipAuto[player] = nil
			recheckLimit.forget(tostring(player.UserId))
		end)
	end

	return {
		name = "CommunityService",
		start = start,
		rewarded = rewarded,
		checked = checked,
		prompted = prompted,
		joined = joined,
		notePrompt = function(player: Player): Notice?
			if communityId and isOffered(player) then
				prompted.fire(player)
			end
			return nil
		end,
		reset = reset,
	}
end

return table.freeze(CommunityService)
