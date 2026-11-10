--!strict
-- The guardians' sounds (docs/design/SOUND.md). A guardian that chases the local player
-- (its Target attribute) sounds the alarm: a sharp start, then the siren on a loop, full at first
-- and quieter as the chase goes on (SoundVoices.chaseLevel), fading out when the chase ends.
-- A guardian chasing someone else sounds the siren from itself, heard only near (the nearest
-- SoundLooks.OTHER_ALARMS). A guardian's catch knocks where it is.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local SoundLooks = require(ReplicatedStorage.Shared.Config.SoundLooks)
local SoundPlayer = require(script.Parent.Parent.Audio.SoundPlayer)
local SoundVoices = require(ReplicatedStorage.Shared.Domain.SoundVoices)

-- The sounds follow the chase this often, seconds.
local STEP_SECONDS = 0.1

export type AlarmSoundController = {
	name: string,
	start: () -> (),
}

local AlarmSoundController = {}

local function bodyOf(model: Instance): BasePart?
	local body = model:FindFirstChild(GuardianConfig.BODY_NAME)
	return if body and body:IsA("BasePart") then body else nil
end

function AlarmSoundController.new(): AlarmSoundController
	local player = Players.LocalPlayer
	-- The local player's chase: when it started and its siren.
	local chaseStartedAt: number? = nil
	local ownSiren: SoundPlayer.Loop? = nil
	-- Sirens of guardians chasing others.
	local otherSirens: { [Instance]: SoundPlayer.Loop } = {}

	local function stepOwnChase(isChased: boolean, now: number)
		if not isChased then
			chaseStartedAt = nil
			if ownSiren then
				ownSiren.stop()
				ownSiren = nil
			end
			return
		end
		if not chaseStartedAt then
			chaseStartedAt = now
			SoundPlayer.play("AlarmStart")
		end
		-- (Re)started if a more important sound took its voice.
		if not ownSiren or not ownSiren.isPlaying() then
			ownSiren = SoundPlayer.loop("AlarmLoop")
		end
		local siren = ownSiren
		if siren then
			siren.setVolume(SoundVoices.chaseLevel(now - (chaseStartedAt :: number), SoundLooks.CHASE))
		end
	end

	local function stepOtherChases(chasers: { BasePart })
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else nil
		local heard: { [Instance]: boolean } = {}
		if eye then
			local reach = SoundLooks.SOUNDS.AlarmLoop.reach :: number
			local nearest = SoundVoices.nearest(chasers, function(body: BasePart): number
				return (body.Position - eye).Magnitude
			end, SoundLooks.OTHER_ALARMS, reach)
			for _, body in nearest do
				heard[body] = true
				local siren = otherSirens[body]
				if not siren or not siren.isPlaying() then
					otherSirens[body] =
						SoundPlayer.loop("AlarmLoop", { at = body, volume = SoundLooks.CHASE.loopShare })
				end
			end
		end
		for body, siren in otherSirens do
			if not heard[body] then
				siren.stop()
				otherSirens[body] = nil
			end
		end
	end

	local function step()
		local now = os.clock()
		local isChased = false
		local chasers: { BasePart } = {}
		for _, model in CollectionService:GetTagged(GuardianConfig.TAG) do
			local target = model:GetAttribute(GuardianConfig.TARGET_ATTRIBUTE)
			if target == player.UserId then
				isChased = true
			elseif type(target) == "number" then
				local body = bodyOf(model)
				if body then
					table.insert(chasers, body)
				end
			end
		end
		stepOwnChase(isChased, now)
		-- The player's own alarm covers the others'.
		stepOtherChases(if isChased then {} else chasers)
	end

	local function watchCatches(model: Instance)
		model:GetAttributeChangedSignal(GuardianConfig.LAST_CATCH_ATTRIBUTE):Connect(function()
			local body = bodyOf(model)
			if body then
				SoundPlayer.play("GuardianCatch", { at = body })
			end
		end)
	end

	local function start()
		CollectionService:GetInstanceAddedSignal(GuardianConfig.TAG):Connect(watchCatches)
		for _, model in CollectionService:GetTagged(GuardianConfig.TAG) do
			watchCatches(model)
		end
		local waited = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			waited += deltaTime
			if waited < STEP_SECONDS then
				return
			end
			waited = 0
			step()
		end)
	end

	return {
		name = "AlarmSoundController",
		start = start,
	}
end

return table.freeze(AlarmSoundController)
