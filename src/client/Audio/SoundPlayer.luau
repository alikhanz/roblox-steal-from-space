--!strict
-- Plays the game's sounds on this client (brief docs/design/SOUND.md). Every sound is named in
-- SoundLooks; this keeps the few voices a phone mixes at once (Domain/SoundVoices decides which
-- sound gives way), places a sound heard in the world at its point or on its part so it fades
-- with distance, and does not start one beyond its reach at all. All of them go through one
-- master SoundGroup with a group per kind (world, interface, alarm).
-- One player per client, so its voices live in the module.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundLooks = require(ReplicatedStorage.Shared.Config.SoundLooks)
local SoundVoices = require(ReplicatedStorage.Shared.Domain.SoundVoices)

export type Name = SoundLooks.Name
-- Where a sound is heard from: a point, or a part or attachment it follows.
export type Where = Vector3 | BasePart | Attachment
export type Options = {
	at: Where?,
	-- Playback speed (pitch); 1 by default.
	speed: number?,
	-- Share of the sound's own volume; 1 by default.
	volume: number?,
}
-- A looping sound while it plays; the voice may be taken by a more important sound, then it
-- stops by itself (isPlaying turns false).
export type Loop = {
	setVolume: (share: number) -> (),
	setSpeed: (speed: number) -> (),
	stop: (fadeSeconds: number?) -> (),
	isPlaying: () -> boolean,
}

local SoundPlayer = {}

local voices: { SoundVoices.Voice } = {}
-- How to stop each playing voice.
local stoppers: { [SoundVoices.Voice]: () -> () } = {}
local groups: { [SoundLooks.Group]: SoundGroup } = {}
local warnedMissing: { [string]: boolean } = {}

local function groupOf(group: SoundLooks.Group): SoundGroup
	local found = groups[group]
	if found then
		return found
	end
	local master = SoundService:FindFirstChild("GameSounds")
	if not master then
		local made = Instance.new("SoundGroup")
		made.Name = "GameSounds"
		made.Volume = SoundLooks.MASTER_VOLUME
		made.Parent = SoundService
		master = made
	end
	local made = Instance.new("SoundGroup")
	made.Name = group
	made.Volume = SoundLooks.GROUP_VOLUMES[group]
	made.Parent = master
	groups[group] = made
	return made
end

local function positionOf(where: Where): Vector3
	if typeof(where) == "Vector3" then
		return where
	elseif where:IsA("Attachment") then
		return (where :: Attachment).WorldPosition
	end
	return (where :: BasePart).Position
end

local function isInReach(where: Where, reach: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - positionOf(where)).Magnitude <= reach
end

-- Ready sounds by name, loaded and silent in SoundService: a sound starts at once instead of
-- waiting for its asset, and frequent sounds are not made and destroyed each time.
local idle: { [Name]: { Sound } } = {}

local function make(name: Name, id: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.SoundGroup = groupOf(SoundLooks.SOUNDS[name].group)
	sound.Parent = SoundService
	return sound
end

local function acquire(name: Name, id: string): Sound
	local list = idle[name]
	local sound = list and table.remove(list)
	return sound or make(name, id)
end

-- Back to the ready ones, unless it is being destroyed (its part went) or enough wait already.
local function release(name: Name, sound: Sound, isDestroyed: boolean)
	if isDestroyed then
		return
	end
	sound:Stop()
	local list = idle[name]
	if not list then
		list = {}
		idle[name] = list
	end
	if #list >= SoundLooks.RULES.maxCopies then
		sound:Destroy()
		return
	end
	sound.Parent = SoundService
	table.insert(list, sound)
end

-- A sound playing: stop it, and whether it is stopped.
type Playing = {
	sound: Sound,
	stop: () -> (),
	isStopped: () -> boolean,
}

local function start(name: Name, options: Options?, looped: boolean): Playing?
	local spec = SoundLooks.SOUNDS[name]
	local id = SoundLooks.assetOf(game.GameId, name)
	if not id then
		if not warnedMissing[name] then
			warnedMissing[name] = true
			warn(`[SoundPlayer] {name} has no asset for this game (SoundLooks.GAMES); silent`)
		end
		return nil
	end
	local at = options and options.at
	if at then
		local reach = spec.reach
		assert(reach and spec.near, `[SoundPlayer] {name} is not a world sound (no reach in SoundLooks)`)
		if not isInReach(at, reach) then
			return nil
		end
	end

	local now = os.clock()
	local admission = SoundVoices.admit(voices, name, spec.priority, now, SoundLooks.RULES)
	if not admission.play then
		return nil
	end
	if admission.evict then
		stoppers[voices[admission.evict]]()
	end

	local sound = acquire(name, id)
	sound.Volume = spec.volume * (options and options.volume or 1)
	sound.PlaybackSpeed = options and options.speed or 1
	sound.Looped = looped
	sound.TimePosition = 0

	local holder: Attachment? = nil
	if at then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = spec.near :: number
		sound.RollOffMaxDistance = spec.reach :: number
		if typeof(at) == "Vector3" then
			local point = Instance.new("Attachment")
			point.Name = `{name}Sound`
			point.Position = at
			point.Parent = workspace.Terrain
			holder = point
			sound.Parent = point
		else
			sound.Parent = at
		end
	else
		sound.Parent = SoundService
	end

	local stopped = false
	local voice: SoundVoices.Voice = { name = name, priority = spec.priority, startedAt = now }
	local connections: { RBXScriptConnection } = {}
	local function finish(isDestroyed: boolean)
		if stopped then
			return
		end
		stopped = true
		local index = table.find(voices, voice)
		if index then
			table.remove(voices, index)
		end
		stoppers[voice] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		release(name, sound, isDestroyed)
		if holder then
			holder:Destroy()
		end
	end
	local function stop()
		finish(false)
	end
	table.insert(voices, voice)
	stoppers[voice] = stop
	-- Gone with the part it was on (a character that left, a guardian streamed out).
	table.insert(
		connections,
		sound.Destroying:Connect(function()
			finish(true)
		end)
	)
	if not looped then
		table.insert(connections, sound.Ended:Connect(stop))
		-- An asset that never loads never ends: free the voice anyway.
		task.delay(SoundLooks.ONESHOT_LIMIT_SECONDS, stop)
	end
	sound:Play()
	return {
		sound = sound,
		stop = stop,
		isStopped = function()
			return stopped
		end,
	}
end

-- Plays `name` once; false if it did not start (beyond reach, or no voice for it).
function SoundPlayer.play(name: Name, options: Options?): boolean
	return start(name, options, false) ~= nil
end

-- Starts `name` looping; nil if it did not start.
function SoundPlayer.loop(name: Name, options: Options?): Loop?
	local playing = start(name, options, true)
	if not playing then
		return nil
	end
	local sound = playing.sound
	local base = SoundLooks.SOUNDS[name].volume
	local fading = false
	return {
		setVolume = function(share: number)
			if not fading and not playing.isStopped() then
				sound.Volume = base * share
			end
		end,
		setSpeed = function(speed: number)
			if not playing.isStopped() then
				sound.PlaybackSpeed = speed
			end
		end,
		stop = function(fadeSeconds: number?)
			if fading or playing.isStopped() then
				return
			end
			local seconds = fadeSeconds or SoundLooks.FADE_SECONDS
			if seconds <= 0 then
				playing.stop()
				return
			end
			fading = true
			local tween = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 })
			tween.Completed:Once(function()
				playing.stop()
			end)
			tween:Play()
		end,
		isPlaying = function()
			return not fading and not playing.isStopped()
		end,
	}
end

-- Loads every sound of this game ahead and keeps a few of each ready, so even quick repeats
-- (clicks) start at once. Yields.
function SoundPlayer.preload()
	local sounds: { Instance } = {}
	for name in SoundLooks.SOUNDS do
		local id = SoundLooks.assetOf(game.GameId, name)
		if id then
			for _ = 1, SoundLooks.READY_COPIES do
				local sound = make(name, id)
				release(name, sound, false)
				table.insert(sounds, sound)
			end
		end
	end
	local ok, problem = pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
	if not ok then
		warn(`[SoundPlayer] Preloading sounds failed: {problem}`)
	end
end

return table.freeze(SoundPlayer)
