--!strict
-- The guardians' sounds (docs/design/SOUND.md). A guardian that chases the local player
-- (its Target attribute) sounds the alarm, and so does the star serpent guarding its knocked-out
-- egg (it chases like a guardian and keeps the same attribute): a sharp start, then the siren on a loop that grows
-- from quiet to loud and quick as the guardian closes in ("it's coming!": SoundVoices.approachLevel,
-- by how soon it would reach the player and how near it is), fading out when the chase ends.
-- A guardian chasing someone else sounds the siren from itself, heard only near (the nearest
-- SoundLooks.OTHER_ALARMS). A guardian's catch knocks where it is.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SoundLooks = require(ReplicatedStorage.Shared.Config.SoundLooks)
local SoundPlayer = require(script.Parent.Parent.Audio.SoundPlayer)
local SoundVoices = require(ReplicatedStorage.Shared.Domain.SoundVoices)

-- The siren's volume and the others' sirens follow the chase this often, seconds (a chase
-- starting or ending is heard at once: the Target attribute's signal).
local STEP_SECONDS = 0.1
local WORLD_WAIT_TIMEOUT = 30

export type AlarmSoundController = {
	name: string,
	start: () -> (),
}

local AlarmSoundController = {}

local function bodyOf(model: Instance): BasePart?
	local body = model:FindFirstChild(GuardianConfig.BODY_NAME)
	return if body and body:IsA("BasePart") then body else nil
end

-- The star serpent while it is out, and the head it flies by.
local function serpentOf(): (Instance?, BasePart?)
	local world = workspace:FindFirstChild("World")
	local model = world and world:FindFirstChild(SerpentConfig.MODEL_NAME)
	local head = model and model:FindFirstChild(SerpentConfig.HEAD_NAME)
	return model, if head and head:IsA("BasePart") then head else nil
end

-- Everything that may chase a thief: the guardians and the serpent, with the part it moves by.
local function allChasers(): { { model: Instance, body: BasePart? } }
	local list = {}
	for _, model in CollectionService:GetTagged(GuardianConfig.TAG) do
		table.insert(list, { model = model, body = bodyOf(model) })
	end
	local serpent, head = serpentOf()
	if serpent then
		table.insert(list, { model = serpent, body = head })
	end
	return list
end

function AlarmSoundController.new(): AlarmSoundController
	local player = Players.LocalPlayer
	-- The local player's chase: its siren and how near the nearest chaser is, eased (0..1).
	local isChaseOn = false
	local ownSiren: SoundPlayer.Loop? = nil
	local approach = 0
	-- Sirens of guardians chasing others.
	local otherSirens: { [Instance]: SoundPlayer.Loop } = {}

	-- How near the nearest of `chasers` (bodies of guardians chasing the local player) is, 0..1.
	local function nearestApproach(chasers: { BasePart }): number
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return 0
		end
		local level = 0
		for _, body in chasers do
			local offset = root.Position - body.Position
			local distance = offset.Magnitude
			local closing = if distance > 1e-3
				then (body.AssemblyLinearVelocity - root.AssemblyLinearVelocity):Dot(offset / distance)
				else 0
			level = math.max(level, SoundVoices.approachLevel(distance, closing, SoundLooks.CHASE))
		end
		return level
	end

	-- `isChased`: some guardian chases the local player; `chasers`: the bodies of those this client
	-- has (a far one may not have streamed in: its siren then stays quiet).
	local function stepOwnChase(isChased: boolean, chasers: { BasePart }, deltaTime: number)
		if not isChased then
			isChaseOn = false
			approach = 0
			if ownSiren then
				ownSiren.stop()
				ownSiren = nil
			end
			return
		end
		local target = nearestApproach(chasers)
		if not isChaseOn then
			isChaseOn = true
			approach = target
			SoundPlayer.play("AlarmStart")
		end
		approach += (target - approach) * (1 - math.exp(-3 * deltaTime / SoundLooks.CHASE.easeSeconds))
		-- (Re)started if a more important sound took its voice.
		if not ownSiren or not ownSiren.isPlaying() then
			ownSiren = SoundPlayer.loop("AlarmLoop")
		end
		local siren = ownSiren
		if siren then
			local volume, speed = SoundVoices.chaseMix(approach, SoundLooks.CHASE)
			siren.setVolume(volume)
			siren.setSpeed(speed)
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
						SoundPlayer.loop("AlarmLoop", { at = body, volume = SoundLooks.OTHER_ALARM_SHARE })
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

	local lastStep = os.clock()
	local function step()
		local now = os.clock()
		local deltaTime = now - lastStep
		lastStep = now
		local isChased = false
		local mine: { BasePart } = {}
		local others: { BasePart } = {}
		for _, chaser in allChasers() do
			local target = chaser.model:GetAttribute(GuardianConfig.TARGET_ATTRIBUTE)
			if type(target) ~= "number" then
				continue
			end
			isChased = isChased or target == player.UserId
			local body = chaser.body
			if body then
				table.insert(if target == player.UserId then mine else others, body)
			end
		end
		stepOwnChase(isChased, mine, deltaTime)
		-- The player's own alarm covers the others'.
		stepOtherChases(if isChased then {} else others)
	end

	local function watchGuardian(model: Instance)
		-- The alarm sounds the moment a chase starts, not at the next step.
		model:GetAttributeChangedSignal(GuardianConfig.TARGET_ATTRIBUTE):Connect(step)
		model:GetAttributeChangedSignal(GuardianConfig.LAST_CATCH_ATTRIBUTE):Connect(function()
			local body = bodyOf(model)
			if body then
				SoundPlayer.play("GuardianCatch", { at = body })
			end
		end)
	end

	local function start()
		CollectionService:GetInstanceAddedSignal(GuardianConfig.TAG):Connect(watchGuardian)
		for _, model in CollectionService:GetTagged(GuardianConfig.TAG) do
			watchGuardian(model)
		end
		-- The serpent's chase starts at once too.
		local function watchSerpent(model: Instance)
			if model.Name == SerpentConfig.MODEL_NAME then
				model:GetAttributeChangedSignal(GuardianConfig.TARGET_ATTRIBUTE):Connect(step)
			end
		end
		task.spawn(function()
			local world = workspace:WaitForChild("World", WORLD_WAIT_TIMEOUT)
			if not world then
				warn("[AlarmSoundController] No workspace.World; the serpent's chase is heard a step late")
				return
			end
			world.ChildAdded:Connect(watchSerpent)
			local serpent = serpentOf()
			if serpent then
				watchSerpent(serpent)
			end
		end)
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
