--!strict
-- What happens to eggs and to the player carrying one, heard (docs/design/SOUND.md): an egg
-- taken in hand, a hit that stuns the player, a delivered egg (one more egg in the incubator
-- or its queue: the bay window cheers at the same moment), and an egg coming loose near by.
-- The carried egg and the hit are written by the server onto the predicted character, which
-- gives no changed signals on the client: polled, like the HUD does.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local SoundLooks = require(ReplicatedStorage.Shared.Config.SoundLooks)
local SoundPlayer = require(script.Parent.Parent.Audio.SoundPlayer)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Dependencies = {
	profile: ProfileState.ProfileState,
}

export type EggSoundController = {
	name: string,
	start: () -> (),
}

local EggSoundController = {}

function EggSoundController.new(dependencies: Dependencies): EggSoundController
	local player = Players.LocalPlayer
	local profile = dependencies.profile

	local function start()
		local lastCharacter: Model? = nil
		local wasCarrying = false
		local wasStunned = false
		RunService.Heartbeat:Connect(function()
			local character = player.Character
			local isCarrying = character ~= nil and character:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE) ~= nil
			local by = character and character:GetAttribute(GuardianConfig.HIT_BY_ATTRIBUTE)
			-- Hitting oneself is the strike's own miss stall: no "ouch" for that.
			local isStunned = character ~= nil
				and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) ~= nil
				and by ~= player.Name
			if character == lastCharacter then
				if isCarrying and not wasCarrying then
					SoundPlayer.play("EggGrab")
				end
				if isStunned and not wasStunned then
					SoundPlayer.play("HitMe")
				end
			end
			lastCharacter = character
			wasCarrying = isCarrying
			wasStunned = isStunned
		end)

		local eggCount: number? = nil
		Vide.root(function()
			Vide.effect(function()
				if not profile.loaded() then
					return
				end
				local bay = profile.bay()
				local count = #bay.incubator + #bay.waiting
				local before = eggCount
				eggCount = count
				if before and count > before then
					SoundPlayer.play("Delivery")
				end
			end)
		end)

		CollectionService:GetInstanceAddedSignal(EggConfig.LOOSE_EGG_TAG):Connect(function(egg)
			local droppedAt = egg:GetAttribute(EggConfig.LOOSE_EGG_DROPPED_AT_ATTRIBUTE)
			if
				egg:IsA("BasePart")
				and type(droppedAt) == "number"
				and workspace:GetServerTimeNow() - droppedAt <= SoundLooks.FRESH_DROP_SECONDS
			then
				SoundPlayer.play("EggDrop", { at = egg })
			end
		end)
	end

	return {
		name = "EggSoundController",
		start = start,
	}
end

return table.freeze(EggSoundController)
