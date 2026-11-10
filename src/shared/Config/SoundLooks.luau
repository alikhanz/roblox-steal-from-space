--!strict
-- Every sound of the game (brief docs/design/SOUND.md): its asset, volume, group, how much it
-- matters and how far it carries. The files are made by assets/audio/sfx.py and uploaded to
-- Roblox per game (GAMES: an asset of one creator plays in another's game only once shared with
-- it, so Prod may get its own ids); the client plays them (client Audio/SoundPlayer). Which
-- sounds may play at once is Domain/SoundVoices.

local SoundVoices = require("../Domain/SoundVoices")

export type Name =
	"AlarmStart"
	| "AlarmLoop"
	| "EggGrab"
	| "Delivery"
	| "EggDrop"
	| "GuardianCatch"
	| "StrikeSwing"
	| "StrikeHit"
	| "HarpoonShot"
	| "HarpoonGrab"
	| "BombThrow"
	| "BombBoom"
	| "HitMe"
	| "JetLoop"
	| "JetStart"
	| "OxygenLow"
	| "OxygenRefill"
	| "EventWarning"
	| "StormStart"
	| "MeteorFall"
	| "SerpentAppear"
	| "SerpentHit"
	| "StarEggOut"
	| "Hatch"
	| "HatchRare"
	| "Crossbreed"
	| "BuyCoins"
	| "BuyRobux"
	| "Reward"
	| "TrainerOn"
	| "TrainerTick"
	| "WindowOpen"
	| "WindowClose"
	| "Toast"
	| "Denied"
	| "Click"

-- The volume groups under one master group: the world's sounds, the interface, the alarm.
export type Group = "World" | "Interface" | "Alarm"

export type Sound = {
	-- A Roblox asset every game may play (Roblox's own sounds); ours are in GAMES.
	read publicId: string?,
	read volume: number,
	read group: Group,
	-- Higher matters more when the voices run out (PRIORITY below).
	read priority: number,
	-- Played at a point in the world: full volume up to `near` studs from the camera, fading to
	-- nothing at `reach`, and not started at all further away. Without `reach` it only plays
	-- without a place (the player's own news).
	read near: number?,
	read reach: number?,
	read looped: boolean?,
}

-- How much a sound matters when the voices run out: the alarm and what happens to the player
-- first, the interface last.
local PRIORITY = table.freeze({
	ALARM = 6,
	ME = 5,
	MINE = 4,
	OTHERS = 3,
	AMBIENT = 2,
	INTERFACE = 1,
})

local function world(volume: number, priority: number, near: number, reach: number): Sound
	return { volume = volume, group = "World", priority = priority, near = near, reach = reach }
end

local function mine(volume: number, priority: number?): Sound
	return { volume = volume, group = "World", priority = priority or PRIORITY.MINE }
end

local function interface(volume: number): Sound
	return { volume = volume, group = "Interface", priority = PRIORITY.INTERFACE }
end

local SOUNDS: { [Name]: Sound } = {
	-- The chase: the start and the loop for the chased player; the loop also sounds from the
	-- guardian for everyone near.
	AlarmStart = { volume = 0.6, group = "Alarm", priority = PRIORITY.ALARM },
	AlarmLoop = {
		volume = 0.5,
		group = "Alarm",
		priority = PRIORITY.ALARM,
		near = 15,
		reach = 150,
		looped = true,
	},
	EggGrab = mine(0.5),
	Delivery = mine(0.6, PRIORITY.ME),
	EggDrop = world(0.6, PRIORITY.OTHERS, 12, 120),
	GuardianCatch = world(0.7, PRIORITY.OTHERS, 15, 150),

	StrikeSwing = world(0.5, PRIORITY.OTHERS, 12, 100),
	StrikeHit = world(0.7, PRIORITY.OTHERS, 12, 120),
	HarpoonShot = world(0.55, PRIORITY.OTHERS, 12, 120),
	HarpoonGrab = world(0.6, PRIORITY.OTHERS, 12, 120),
	BombThrow = world(0.5, PRIORITY.OTHERS, 12, 100),
	BombBoom = world(0.8, PRIORITY.OTHERS, 25, 250),
	HitMe = mine(0.7, PRIORITY.ME),

	JetLoop = {
		volume = 0.35,
		group = "World",
		priority = PRIORITY.AMBIENT,
		near = 15,
		reach = 60,
		looped = true,
	},
	JetStart = world(0.4, PRIORITY.AMBIENT, 15, 60),
	OxygenLow = mine(0.35, PRIORITY.ME),
	OxygenRefill = mine(0.4),

	EventWarning = mine(0.5),
	StormStart = mine(0.5),
	MeteorFall = world(0.7, PRIORITY.AMBIENT, 40, 400),
	SerpentAppear = mine(0.5),
	SerpentHit = world(0.6, PRIORITY.OTHERS, 20, 200),
	StarEggOut = world(0.6, PRIORITY.OTHERS, 25, 300),

	Hatch = mine(0.6),
	HatchRare = mine(0.5),
	Crossbreed = mine(0.55),
	BuyCoins = mine(0.5),
	BuyRobux = mine(0.6),
	Reward = mine(0.55),
	TrainerOn = mine(0.45),
	TrainerTick = mine(0.2, PRIORITY.AMBIENT),

	WindowOpen = interface(0.25),
	WindowClose = interface(0.2),
	Toast = interface(0.3),
	Denied = interface(0.35),
	-- Roblox_UI_Small_Click (Creator Store, creator Roblox): kept from the buttons' brief.
	Click = { publicId = "rbxassetid://15675032796", volume = 0.35, group = "Interface", priority = PRIORITY.INTERFACE },
}

for _, sound in SOUNDS do
	table.freeze(sound)
end

-- Our uploaded sounds by game (game.GameId): Dev; Prod once shared with it or uploaded there.
-- A sound missing here is silent (the player warns once). Upload list: docs/design/SOUND.md.
local GAMES: { [number]: { [Name]: string } } = {
	[10774871729] = {},
}

local RULES: SoundVoices.Rules = {
	-- A phone mixes few sounds at once without mud.
	maxVoices = 8,
	maxCopies = 3,
	repeatSeconds = 0.08,
}

local OXYGEN_BEEP: SoundVoices.OxygenBeep = {
	below = 0.25, -- OxygenConfig.LOW_FRACTION; a test keeps them equal
	slowest = 1.4,
	fastest = 0.35,
}

local JET: SoundVoices.Jet = {
	idleVolume = 0.35,
	fullVolume = 1,
	idleSpeed = 0.85,
	fullSpeed = 1.25,
}

local CHASE: SoundVoices.Chase = {
	alertSeconds = 1.0,
	settleSeconds = 0.4,
	loopShare = 0.6,
}

for _, ids in GAMES do
	table.freeze(ids)
end

local SoundLooks = {
	SOUNDS = table.freeze(SOUNDS),
	GAMES = table.freeze(GAMES),
	PRIORITY = PRIORITY,
	RULES = table.freeze(RULES),
	-- Volume of each group; the master group holds them all.
	GROUP_VOLUMES = table.freeze({ World = 1, Interface = 1, Alarm = 1 } :: { [Group]: number }),
	MASTER_VOLUME = 1,
	OXYGEN_BEEP = table.freeze(OXYGEN_BEEP),
	JET = table.freeze(JET),
	-- Other players' jetpacks heard at once at most (the own one always).
	OTHER_JETS = 2,
	CHASE = table.freeze(CHASE),
	-- Guardians chasing someone else heard at once at most.
	OTHER_ALARMS = 1,
	-- A one-shot frees its voice after this long even if it never ended (an asset that did not
	-- load), seconds; longer than the longest sound at its slowest.
	ONESHOT_LIMIT_SECONDS = 8,
	-- A loop that stops fades out over this long, seconds.
	FADE_SECONDS = 0.5,
	-- A hatch sounds this high for the lowest tier and the highest (playback speed).
	HATCH_SPEED = table.freeze({ lowest = 1, highest = 1.2 }),
	-- Tiers that add HatchRare to the hatch.
	RARE_TIERS = table.freeze({ Epic = true, Legendary = true } :: { [string]: boolean }),
	-- The trainer's payout blip at most this often, seconds.
	TRAINER_TICK_SECONDS = 1,
	-- A loose egg is news (EggDrop) only this soon after it came loose, seconds; older ones are
	-- streaming in.
	FRESH_DROP_SECONDS = 1,
}

-- The asset of sound `name` in game `gameId`, or nil if it has none there.
function SoundLooks.assetOf(gameId: number, name: Name): string?
	local ids = GAMES[gameId]
	return (ids and ids[name]) or SOUNDS[name].publicId
end

return table.freeze(SoundLooks)
