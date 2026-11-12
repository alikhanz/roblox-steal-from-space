--!strict
-- Which sounds play (docs/design/SOUND.md, "Как проигрывается"): a phone mixes only a few at
-- once, so every new sound asks for a voice. Pure rules, no Roblox: the client's SoundPlayer
-- keeps the voices and acts on the answers.

local SoundVoices = {}

-- A sound that is playing: its name, how much it matters (higher wins) and when it started.
export type Voice = {
	read name: string,
	read priority: number,
	read startedAt: number,
}

export type Rules = {
	-- Voices at most, loops included.
	read maxVoices: number,
	-- Copies of one sound at most; one more replaces its oldest copy.
	read maxCopies: number,
	-- The same sound does not start again sooner than this, seconds.
	read repeatSeconds: number,
}

-- Play or not, and which playing voice (an index into the list) to stop first.
export type Admission = {
	play: boolean,
	evict: number?,
}

-- May sound `name` of `priority` start at `now`, with `voices` playing?
function SoundVoices.admit(voices: { Voice }, name: string, priority: number, now: number, rules: Rules): Admission
	local copies = 0
	local newestCopyAt = -math.huge
	local oldestCopy: number? = nil
	for index, voice in voices do
		if voice.name == name then
			copies += 1
			newestCopyAt = math.max(newestCopyAt, voice.startedAt)
			if not oldestCopy or voice.startedAt < voices[oldestCopy].startedAt then
				oldestCopy = index
			end
		end
	end
	if copies > 0 and now - newestCopyAt < rules.repeatSeconds then
		return { play = false }
	end
	if oldestCopy and copies >= rules.maxCopies then
		return { play = true, evict = oldestCopy }
	end
	if #voices < rules.maxVoices then
		return { play = true }
	end
	-- Full: the least important voice gives way, the oldest among equals, if it matters less.
	local weakest: number? = nil
	for index, voice in voices do
		local current = if weakest then voices[weakest] else nil
		if
			not current
			or voice.priority < current.priority
			or (voice.priority == current.priority and voice.startedAt < current.startedAt)
		then
			weakest = index
		end
	end
	if weakest and voices[weakest].priority < priority then
		return { play = true, evict = weakest }
	end
	return { play = false }
end

-- Up to `count` of `items` nearest to the listener and no further than `reach`, nearest first.
function SoundVoices.nearest<T>(items: { T }, distanceOf: (T) -> number, count: number, reach: number): { T }
	local near: { T } = {}
	local distances: { [number]: number } = {}
	for _, item in items do
		local distance = distanceOf(item)
		if distance <= reach then
			table.insert(near, item)
			distances[#near] = distance
		end
	end
	local order: { number } = {}
	for index in near do
		table.insert(order, index)
	end
	table.sort(order, function(a: number, b: number): boolean
		return distances[a] < distances[b]
	end)
	local chosen: { T } = {}
	for position = 1, math.min(count, #order) do
		chosen[position] = near[order[position]]
	end
	return chosen
end

export type OxygenBeep = {
	-- Beeping starts below this share of a full tank.
	read below: number,
	-- Seconds between beeps: just under `below`, and at an empty tank.
	read slowest: number,
	read fastest: number,
}

-- Seconds between low-oxygen beeps at `fraction` of a full tank; nil while there is enough.
function SoundVoices.oxygenBeepInterval(fraction: number, beep: OxygenBeep): number?
	if fraction >= beep.below then
		return nil
	end
	local share = math.clamp(fraction / beep.below, 0, 1)
	return beep.fastest + (beep.slowest - beep.fastest) * share
end

export type Jet = {
	-- Volume and pitch (playback speed) of the jetpack's hiss hovering, and at top speed.
	read idleVolume: number,
	read fullVolume: number,
	read idleSpeed: number,
	read fullSpeed: number,
}

-- The jetpack's hiss at `thrust` (0 hovering .. 1 top speed): its volume and playback speed.
function SoundVoices.jetMix(thrust: number, jet: Jet): (number, number)
	local share = math.clamp(thrust, 0, 1)
	return jet.idleVolume + (jet.fullVolume - jet.idleVolume) * share,
		jet.idleSpeed + (jet.fullSpeed - jet.idleSpeed) * share
end

export type Chase = {
	-- How near a guardian chasing the player is, from 0 (far behind, or not gaining) to 1 (about to
	-- catch): by the time it needs to reach the player at the speed it closes in, full at
	-- `nearSeconds`, nothing from `farSeconds`; and by plain distance, full within
	-- `nearDistance` studs, nothing from `farDistance` (one level with the thief is still close).
	read nearSeconds: number,
	read farSeconds: number,
	read nearDistance: number,
	read farDistance: number,
	-- The siren's loop at nothing and at full: its share of full volume and playback speed.
	read quietShare: number,
	read slowSpeed: number,
	read fastSpeed: number,
	-- The level eases to a new value over this many seconds (the guardian's motion arrives in steps).
	read easeSeconds: number,
}

local function fall(value: number, near: number, far: number): number
	return 1 - math.clamp((value - near) / (far - near), 0, 1)
end

-- How near a chasing guardian `distance` studs away, closing in at `closingSpeed` studs per
-- second (negative: falling behind), is: 0..1 (see Chase).
function SoundVoices.approachLevel(distance: number, closingSpeed: number, chase: Chase): number
	local byDistance = fall(distance, chase.nearDistance, chase.farDistance)
	if closingSpeed <= 0 then
		return byDistance
	end
	return math.max(byDistance, fall(distance / closingSpeed, chase.nearSeconds, chase.farSeconds))
end

-- The siren's volume share and playback speed at an approach `level` (approachLevel): it grows
-- louder and quicker as the guardian closes in.
function SoundVoices.chaseMix(level: number, chase: Chase): (number, number)
	local share = math.clamp(level, 0, 1)
	return chase.quietShare + (1 - chase.quietShare) * share,
		chase.slowSpeed + (chase.fastSpeed - chase.slowSpeed) * share
end

-- Playback speed of a hatch for the alien's tier: `lowest` for the first tier of `tierCount`,
-- `highest` for the last — a rarer alien sounds higher.
function SoundVoices.tierSpeed(tierPosition: number, tierCount: number, lowest: number, highest: number): number
	if tierCount <= 1 then
		return lowest
	end
	local share = math.clamp((tierPosition - 1) / (tierCount - 1), 0, 1)
	return lowest + (highest - lowest) * share
end

return table.freeze(SoundVoices)
