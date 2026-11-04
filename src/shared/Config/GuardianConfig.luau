--!strict
-- Guardians of the nests: the 24 posts (one guardian each, six per zone), how they chase and
-- what a catch does. Every guardian behaves the same; posts differ in name, speed and look
-- (GuardianLooks), and share a few body kinds. Pure Luau: the balance calculator and tests
-- load it in Lune.

local AlienConfig = require("./AlienConfig")
local BigNum = require("../Domain/BigNum")
local EggConfig = require("./EggConfig")
local GuardianBrain = require("../Domain/GuardianBrain")
local Speed = require("../Domain/Speed")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")
local ZoneConfig = require("./ZoneConfig")

-- Body kinds: the models guardians are built from.
export type KindId = "SlimeWarden" | "CrabDrone" | "IceWorm" | "DevourerSwarm" | "StarRay" | "SpaceWhale"

export type PostId =
	"SlimeWarden"
	| "CrabDrone"
	| "VioletCrab"
	| "AcidSlime"
	| "RustyCrab"
	| "SlimeKing"
	| "IceWorm"
	| "SnowCrab"
	| "FrostSlime"
	| "CrystalWorm"
	| "IceRay"
	| "WormMother"
	| "DevourerSwarm"
	| "StarRay"
	| "FireSlime"
	| "RedSwarm"
	| "LightningRay"
	| "DevourerQueen"
	| "ShadowWorm"
	| "BlackRay"
	| "VoidSwarm"
	| "GravityCrab"
	| "WhaleCalf"
	| "SpaceWhale"

-- A post is one guardian at its nests: its name, body kind, zone, the speed the sign over it
-- recommends and its own speed stat. Post k (counted from the station outwards) guards grade k.
export type Post = {
	read id: PostId,
	read index: number,
	read zone: ZoneConfig.ZoneId,
	read kind: KindId,
	read nameKey: keyof<typeof(Strings)>,
	-- The stat that flies level with this guardian while carrying a typical egg: what the
	-- player sees (see recommendedFor). A new player at the starting speed sees "10" over the
	-- first guardian and goes for it.
	read recommended: BigNum.BigNum,
	read speed: BigNum.BigNum,
}

-- Guardian k recommends FIRST_RECOMMENDED times the product of the first k-1 steps, where step
-- i is RECOMMENDED_GROWTH_START * RECOMMENDED_GROWTH_DECAY^(i-1): the first guardians are far
-- apart (a new one is a real jump) and the last ones close together, so progress keeps
-- coming late in the game. With 24 posts the last one lands near a trillion.
local FIRST_RECOMMENDED = BigNum.fromNumber(10)
local RECOMMENDED_GROWTH_START = 4.2
local RECOMMENDED_GROWTH_DECAY = 0.97

local function recommendedFor(index: number): BigNum.BigNum
	assert(index >= 1 and index % 1 == 0, `post index must be a whole number, got {index}`)
	local value = FIRST_RECOMMENDED
	for step = 1, index - 1 do
		value = BigNum.mul(value, BigNum.fromNumber(RECOMMENDED_GROWTH_START * RECOMMENDED_GROWTH_DECAY ^ (step - 1)))
	end
	return value
end

-- The recommended speed over a guardian assumes an egg of this weight: a common one of the
-- typical size. Lighter eggs need less, heavier ones more; that is part of the gamble.
local TYPICAL_WEIGHT =
	Speed.eggWeight(EggConfig.RARITIES.Common.weight, EggConfig.SIZES[EggConfig.TYPICAL_SIZE].weightFactor)

-- Posts in order from the station outwards: six per zone (ZoneConfig.ZONE_ORDER).
local POST_LIST: { { id: PostId, kind: KindId, nameKey: keyof<typeof(Strings)> } } = {
	-- Debris Belt
	{ id = "SlimeWarden", kind = "SlimeWarden", nameKey = "guardian.slimeWarden.title" },
	{ id = "CrabDrone", kind = "CrabDrone", nameKey = "guardian.crabDrone.title" },
	{ id = "VioletCrab", kind = "CrabDrone", nameKey = "guardian.violetCrab.title" },
	{ id = "AcidSlime", kind = "SlimeWarden", nameKey = "guardian.acidSlime.title" },
	{ id = "RustyCrab", kind = "CrabDrone", nameKey = "guardian.rustyCrab.title" },
	{ id = "SlimeKing", kind = "SlimeWarden", nameKey = "guardian.slimeKing.title" },
	-- Ice Rings
	{ id = "IceWorm", kind = "IceWorm", nameKey = "guardian.iceWorm.title" },
	{ id = "SnowCrab", kind = "CrabDrone", nameKey = "guardian.snowCrab.title" },
	{ id = "FrostSlime", kind = "SlimeWarden", nameKey = "guardian.frostSlime.title" },
	{ id = "CrystalWorm", kind = "IceWorm", nameKey = "guardian.crystalWorm.title" },
	{ id = "IceRay", kind = "StarRay", nameKey = "guardian.iceRay.title" },
	{ id = "WormMother", kind = "IceWorm", nameKey = "guardian.wormMother.title" },
	-- Red Nebula
	{ id = "DevourerSwarm", kind = "DevourerSwarm", nameKey = "guardian.devourerSwarm.title" },
	{ id = "StarRay", kind = "StarRay", nameKey = "guardian.starRay.title" },
	{ id = "FireSlime", kind = "SlimeWarden", nameKey = "guardian.fireSlime.title" },
	{ id = "RedSwarm", kind = "DevourerSwarm", nameKey = "guardian.redSwarm.title" },
	{ id = "LightningRay", kind = "StarRay", nameKey = "guardian.lightningRay.title" },
	{ id = "DevourerQueen", kind = "DevourerSwarm", nameKey = "guardian.devourerQueen.title" },
	-- Event Horizon
	{ id = "ShadowWorm", kind = "IceWorm", nameKey = "guardian.shadowWorm.title" },
	{ id = "BlackRay", kind = "StarRay", nameKey = "guardian.blackRay.title" },
	{ id = "VoidSwarm", kind = "DevourerSwarm", nameKey = "guardian.voidSwarm.title" },
	{ id = "GravityCrab", kind = "CrabDrone", nameKey = "guardian.gravityCrab.title" },
	{ id = "WhaleCalf", kind = "SpaceWhale", nameKey = "guardian.whaleCalf.title" },
	{ id = "SpaceWhale", kind = "SpaceWhale", nameKey = "guardian.spaceWhale.title" },
}
assert(#POST_LIST == ZoneConfig.POST_COUNT, "GuardianConfig posts and ZoneConfig.POST_COUNT disagree")
-- Post k's eggs hatch into grade k: the two lists must agree.
assert(#POST_LIST == #AlienConfig.GRADES, "GuardianConfig posts and AlienConfig.GRADES disagree")

local POSTS: { Post } = {}
local POSTS_BY_ID: { [PostId]: Post } = {}
for index, entry in POST_LIST do
	local recommended = recommendedFor(index)
	local zone = ZoneConfig.zoneOfPost(index)
	local post: Post = table.freeze({
		id = entry.id,
		index = index,
		zone = zone,
		kind = entry.kind,
		nameKey = entry.nameKey,
		recommended = recommended,
		speed = Speed.withEgg(recommended, TYPICAL_WEIGHT),
	})
	POSTS[index] = post
	assert(not POSTS_BY_ID[entry.id], `guardian post {entry.id} repeats`)
	POSTS_BY_ID[entry.id] = post
end

local BRAIN: GuardianBrain.Tuning = {
	aggroDelaySeconds = 1,
	homeRadius = 4,
	catchRadius = 7,
}

return table.freeze({
	FIRST_RECOMMENDED = FIRST_RECOMMENDED,
	RECOMMENDED_GROWTH_START = RECOMMENDED_GROWTH_START,
	RECOMMENDED_GROWTH_DECAY = RECOMMENDED_GROWTH_DECAY,
	-- The recommendation over post `index`, for any index (the calculator looks past the list).
	recommendedFor = recommendedFor,
	-- Every post, from the station outwards; POSTS[k] guards grade k.
	POSTS = table.freeze(POSTS),
	POSTS_BY_ID = table.freeze(POSTS_BY_ID),
	BRAIN = table.freeze(BRAIN),
	TYPICAL_WEIGHT = TYPICAL_WEIGHT,
	-- A sleeping guardian hovers this far above its nest's egg, studs.
	HOVER_HEIGHT = 8,
	-- Guardians never come closer to the station border than this, studs.
	BORDER_MARGIN = 6,
	-- How far ahead of a moving thief a guardian aims, at most, seconds.
	MAX_LEAD_SECONDS = 1.5,
	-- Guardians ease into their resting spot within this distance, studs.
	ARRIVE_RADIUS = 6,
	-- Logic rate: 15 updates per second (CONVENTIONS, performance: guardians at 10-20 Hz).
	TICK_SECONDS = 1 / 15,
	-- Force budget of the movers: enough to cancel gravity and turn sharply.
	MAX_FORCE = 1e6,
	ALIGN_RESPONSIVENESS = 20,
	-- A caught thief is thrown away at this speed, tumbles and cannot steer for the stun.
	KNOCKBACK_SPEED = 60,
	STUN_SECONDS = 1.2,
	TUMBLE_SPIN_RATE = math.rad(540),
	-- The guardian's strike: a short dash into the thief on the catch, studs per second.
	LUNGE_SPEED = 90,
	-- One catch per this many seconds: a drop is never followed by an instant second hit.
	CATCH_COOLDOWN_SECONDS = 2,

	TAG = "Guardian",
	-- Guardian model attributes (replicated for the client view).
	POST_ATTRIBUTE = "Post",
	STATE_ATTRIBUTE = "State",
	-- Server clock of the last catch; clients play the strike when it changes.
	LAST_CATCH_ATTRIBUTE = "LastCatchAt",
	RECOMMENDED_MANTISSA_ATTRIBUTE = "RecommendedMantissa",
	RECOMMENDED_EXPONENT_ATTRIBUTE = "RecommendedExponent",
	-- Instance names inside a guardian model.
	BODY_NAME = "Body",
	EYE_NAME = "Eye",
	VELOCITY_NAME = "GuardianVelocity",
	ALIGN_NAME = "GuardianAlign",
	-- Character attributes of a catch. The server sets the velocity and spin axis for the stun
	-- and clears them when it ends (their presence is the stun: no clocks to agree on); the
	-- simulation applies them and keeps the tumble angle, which is predicted state.
	HIT_VELOCITY_ATTRIBUTE = "HitVelocity",
	HIT_AXIS_ATTRIBUTE = "HitAxis",
	HIT_ANGLE_ATTRIBUTE = "HitAngle",
	-- Who dealt the hit: HIT_BY_GUARDIAN or a player's name (the HUD words it differently).
	HIT_BY_ATTRIBUTE = "HitBy",
	HIT_BY_GUARDIAN = "Guardian",
})
