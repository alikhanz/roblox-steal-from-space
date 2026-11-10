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

local function start(name: Name, options: Options?, looped: boolean): (Sound?, () -> ())
	local spec = SoundLooks.SOUNDS[name]
	local noop = function() end
	local id = SoundLooks.assetOf(game.GameId, name)
	if not id then
		if not warnedMissing[name] then
			warnedMissing[name] = true
			warn(`[SoundPlayer] {name} has no asset for this game (SoundLooks.GAMES); silent`)
		end
		return nil, noop
	end
	local at = options and options.at
	if at then
		local reach = spec.reach
		assert(reach and spec.near, `[SoundPlayer] {name} is not a world sound (no reach in SoundLooks)`)
		if not isInReach(at, reach) then
			return nil, noop
		end
	end

	local now = os.clock()
	local admission = SoundVoices.admit(voices, name, spec.priority, now, SoundLooks.RULES)
	if not admission.play then
		return nil, noop
	end
	if admission.evict then
		stoppers[voices[admission.evict]]()
	end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = spec.volume * (options and options.volume or 1)
	sound.PlaybackSpeed = options and options.speed or 1
	sound.Looped = looped
	sound.SoundGroup = groupOf(spec.group)

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
	local function stop()
		if stopped then
			return
		end
		stopped = true
		local index = table.find(voices, voice)
		if index then
			table.remove(voices, index)
		end
		stoppers[voice] = nil
		sound:Destroy()
		if holder then
			holder:Destroy()
		end
	end
	table.insert(voices, voice)
	stoppers[voice] = stop
	-- Gone with the part it was on (a character that left, a guardian streamed out).
	sound.Destroying:Once(stop)
	if not looped then
		sound.Ended:Once(stop)
		-- An asset that never loads never ends: free the voice anyway.
		task.delay(SoundLooks.ONESHOT_LIMIT_SECONDS, stop)
	end
	sound:Play()
	return sound, stop
end

-- Plays `name` once; false if it did not start (beyond reach, or no voice for it).
function SoundPlayer.play(name: Name, options: Options?): boolean
	local sound = start(name, options, false)
	return sound ~= nil
end

-- Starts `name` looping; nil if it did not start.
function SoundPlayer.loop(name: Name, options: Options?): Loop?
	local sound, stopNow = start(name, options, true)
	if not sound then
		return nil
	end
	local playing = sound :: Sound
	local base = SoundLooks.SOUNDS[name].volume
	local fading = false
	return {
		setVolume = function(share: number)
			if not fading and playing.Parent then
				playing.Volume = base * share
			end
		end,
		setSpeed = function(speed: number)
			if playing.Parent then
				playing.PlaybackSpeed = speed
			end
		end,
		stop = function(fadeSeconds: number?)
			if fading or not playing.Parent then
				return
			end
			local seconds = fadeSeconds or SoundLooks.FADE_SECONDS
			if seconds <= 0 then
				stopNow()
				return
			end
			fading = true
			local tween = TweenService:Create(playing, TweenInfo.new(seconds), { Volume = 0 })
			tween.Completed:Once(function()
				stopNow()
			end)
			tween:Play()
		end,
		isPlaying = function()
			return playing.Parent ~= nil and not fading
		end,
	}
end

-- Loads every uploaded sound ahead, so the first of each plays on time. Yields.
function SoundPlayer.preload()
	local sounds: { Instance } = {}
	for name in SoundLooks.SOUNDS do
		local id = SoundLooks.assetOf(game.GameId, name)
		if id then
			local sound = Instance.new("Sound")
			sound.SoundId = id
			table.insert(sounds, sound)
		end
	end
	local ok, problem = pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
	if not ok then
		warn(`[SoundPlayer] Preloading sounds failed: {problem}`)
	end
	for _, sound in sounds do
		sound:Destroy()
	end
end

return table.freeze(SoundPlayer)
