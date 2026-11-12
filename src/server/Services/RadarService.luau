--!strict
-- Publishes where every player is and what egg they carry, for everyone's markers
-- (docs/design/screens/markers.md): attributes on the Player, which reach every client however far
-- the character itself is streamed (the map is wider than the streaming radius). Twice a second,
-- and the position only once it has moved a little, so a player standing still sends nothing.
-- Clients draw a near character where it really is; the attribute is for the far ones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Radar = require(ReplicatedStorage.Shared.Domain.Radar)
local RadarConfig = require(ReplicatedStorage.Shared.Config.RadarConfig)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)

export type Dependencies = {
	scheduler: Scheduler.Scheduler,
}

export type RadarService = {
	name: string,
	start: () -> (),
}

local RadarService = {}

-- Where the player's living character stands, or nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

function RadarService.new(dependencies: Dependencies): RadarService
	local published: { [Player]: Vector3 } = {}

	local function publish(player: Player)
		local root = rootOf(player)
		if not root then
			published[player] = nil
			player:SetAttribute(RadarConfig.POSITION_ATTRIBUTE, nil)
			player:SetAttribute(RadarConfig.EGG_ATTRIBUTE, nil)
			return
		end
		local position = root.Position
		if Radar.shouldPublish(published[player], position) then
			published[player] = position
			player:SetAttribute(RadarConfig.POSITION_ATTRIBUTE, position)
		end
		-- The carry service keeps the egg in hand on the character (the server's own write).
		local carried = (root.Parent :: Instance):GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE)
		local rarity = if type(carried) == "string" then carried else nil
		if player:GetAttribute(RadarConfig.EGG_ATTRIBUTE) ~= rarity then
			player:SetAttribute(RadarConfig.EGG_ATTRIBUTE, rarity)
		end
	end

	local function start()
		local players: { [Player]: true } = {}
		PlayerEvents.observe(function(player)
			players[player] = true
		end, function(player)
			players[player] = nil
			published[player] = nil
		end)
		dependencies.scheduler.every(RadarConfig.PUBLISH_SECONDS, function()
			for player in players do
				publish(player)
			end
		end)
	end

	return {
		name = "RadarService",
		start = start,
	}
end

return table.freeze(RadarService)
