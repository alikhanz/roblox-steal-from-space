--!strict
-- Flight's sounds (docs/design/SOUND.md):
--   * the jetpack's hiss while it runs (JetpackOn), louder and higher with speed — the local
--     player's own always, other players' only the nearest few (SoundLooks.OTHER_JETS); a puff as
--     it starts, and as it comes back after a stun;
--   * the low-oxygen beep in space, faster as the tank empties, and a breath once the tank
--     fills again under a dome;
--   * the jetpack stand: a clack as it straps the player in, a blip per payout of speed.
-- Character state is simulation state: polled a few times a second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local SoundLooks = require(ReplicatedStorage.Shared.Config.SoundLooks)
local SoundPlayer = require(script.Parent.Parent.Audio.SoundPlayer)
local SoundVoices = require(ReplicatedStorage.Shared.Domain.SoundVoices)
local Stand = require(ReplicatedStorage.Shared.Domain.Stand)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local TopSpeed = require(ReplicatedStorage.Shared.Simulation.TopSpeed)

-- The jetpacks' hiss follows their speed this often, seconds.
local STEP_SECONDS = 0.1

export type Dependencies = {
	profile: ProfileState.ProfileState,
}

export type FlightSoundController = {
	name: string,
	start: () -> (),
}

type Jet = {
	root: BasePart,
	thrust: number,
}

local FlightSoundController = {}

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function FlightSoundController.new(dependencies: Dependencies): FlightSoundController
	local localPlayer = Players.LocalPlayer
	local hisses: { [BasePart]: SoundPlayer.Loop } = {}
	-- Was each player's jetpack burning at the last step (to puff as it lights).
	local burning: { [Player]: boolean } = {}

	local function stepJets()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local own: Jet? = nil
		local others: { Jet } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = rootOf(character)
			local isBurning = character ~= nil
				and root ~= nil
				and character:GetAttribute(FlightConfig.JETPACK_ON_ATTRIBUTE) == true
				and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) == nil
			if isBurning and character and root then
				-- The own jetpack's start is caught every frame (stepOwnJet).
				if not burning[player] and player ~= localPlayer then
					SoundPlayer.play("JetStart", { at = root })
				end
				local top = TopSpeed.of(character)
				local jet = {
					root = root,
					thrust = if top > 0 then root.AssemblyLinearVelocity.Magnitude / top else 0,
				}
				if player == localPlayer then
					own = jet
				else
					table.insert(others, jet)
				end
			end
			burning[player] = isBurning or nil
		end

		local heard = SoundVoices.nearest(others, function(jet: Jet): number
			return (jet.root.Position - eye).Magnitude
		end, SoundLooks.OTHER_JETS, SoundLooks.SOUNDS.JetLoop.reach :: number)
		if own then
			table.insert(heard, own)
		end
		local kept: { [BasePart]: boolean } = {}
		for _, jet in heard do
			kept[jet.root] = true
			local hiss = hisses[jet.root]
			if not hiss or not hiss.isPlaying() then
				hiss = SoundPlayer.loop("JetLoop", { at = jet.root })
				hisses[jet.root] = hiss
			end
			if hiss then
				local volume, speed = SoundVoices.jetMix(jet.thrust, SoundLooks.JET)
				hiss.setVolume(volume)
				hiss.setSpeed(speed)
			end
		end
		for root, hiss in hisses do
			if not kept[root] then
				hiss.stop()
				hisses[root] = nil
			end
		end
	end

	-- The low-oxygen beep and the breath after it.
	local nextBeepAt = 0
	local wasLow = false
	local lastOxygen: number? = nil
	local function stepOxygen(now: number)
		local character = localPlayer.Character
		local oxygen = character and character:GetAttribute(OxygenConfig.ATTRIBUTE)
		local inSpace = character ~= nil and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
		if type(oxygen) ~= "number" then
			lastOxygen = nil
			return
		end
		local interval = if inSpace
			then SoundVoices.oxygenBeepInterval(oxygen / OxygenConfig.CAPACITY, SoundLooks.OXYGEN_BEEP)
			else nil
		if interval then
			wasLow = true
			if now >= nextBeepAt then
				SoundPlayer.play("OxygenLow")
				nextBeepAt = now + interval
			end
		elseif wasLow and not inSpace and lastOxygen and oxygen > lastOxygen then
			wasLow = false
			SoundPlayer.play("OxygenRefill")
		end
		lastOxygen = oxygen
	end

	-- The local player's jetpack lights: heard the frame it happens.
	local ownBurning = false
	local function stepOwnJet()
		local character = localPlayer.Character
		local root = rootOf(character)
		local isBurning = character ~= nil
			and root ~= nil
			and character:GetAttribute(FlightConfig.JETPACK_ON_ATTRIBUTE) == true
			and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) == nil
		if isBurning and not ownBurning and root then
			SoundPlayer.play("JetStart", { at = root })
		end
		ownBurning = isBurning
	end

	local wasOnStand = false
	local function stepStand()
		local character = localPlayer.Character
		local state = Stand.parse(character and character:GetAttribute(StandConfig.STATE_ATTRIBUTE))
		local isOn = state == "On"
		if isOn and not wasOnStand then
			SoundPlayer.play("TrainerOn")
		end
		wasOnStand = isOn
	end

	local function start()
		local lastTickAt = -math.huge
		-- The trainer's tick is the stand's sound: a flight trains quietly (decision 131).
		dependencies.profile.trained.connect(function(_gain, source)
			local now = os.clock()
			if source == "Stand" and now - lastTickAt >= SoundLooks.TRAINER_TICK_SECONDS then
				lastTickAt = now
				SoundPlayer.play("TrainerTick")
			end
		end)
		Players.PlayerRemoving:Connect(function(player)
			burning[player] = nil
		end)
		local waited = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			-- What the player does is heard at once; the loops follow a few times a second.
			stepOwnJet()
			stepStand()
			waited += deltaTime
			if waited < STEP_SECONDS then
				return
			end
			waited = 0
			stepJets()
			stepOxygen(os.clock())
		end)
	end

	return {
		name = "FlightSoundController",
		start = start,
	}
end

return table.freeze(FlightSoundController)
