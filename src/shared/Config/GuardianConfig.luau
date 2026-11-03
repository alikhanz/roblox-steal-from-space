--!strict
-- Guardians of the nests: which nests get which guardian, how they chase and what a catch does.
-- Every guardian behaves the same; kinds differ in look (GuardianLooks) and posts in speed.
-- Pure Luau: the balance calculator and tests load it in Lune.

local AlienConfig = require("./AlienConfig")
local BigNum = require("../Domain/BigNum")
local EggConfig = require("./EggConfig")
local GuardianBrain = require("../Domain/GuardianBrain")
local Speed = require("../Domain/Speed")
-- selene: allow(unused_variable) -- only its type is used, to keep name keys checked.
local Strings = require("../Locale/Strings")

export type KindId = "SlimeWarden" | "CrabDrone"

export type Kind = {
	read nameKey: keyof<typeof(Strings)>,
}

-- A post is a guardian placed at a nest: its kind and its speed stat. Posts are handed out to
-- nests from the nearest to the station outwards, so farther nests get faster guardians.
export type Post = {
	read kind: KindId,
	read speed: BigNum.BigNum,
}

local KINDS: { [KindId]: Kind } = {
	SlimeWarden = { nameKey = "guardian.slimeWarden.title" },
	CrabDrone = { nameKey = "guardian.crabDrone.title" },
}

-- Guardian k has speed FIRST_SPEED * SPEED_GROWTH^(k-1) (see GAME_DESIGN, pacing).
local FIRST_SPEED = BigNum.fromNumber(10)
local SPEED_GROWTH = BigNum.fromNumber(3)

local function speedOfPost(index: number): BigNum.BigNum
	return BigNum.mul(FIRST_SPEED, BigNum.pow(SPEED_GROWTH, index - 1))
end

local DEBRIS_BELT_POSTS: { Post } = {
	{ kind = "SlimeWarden", speed = speedOfPost(1) },
	{ kind = "CrabDrone", speed = speedOfPost(2) },
	{ kind = "CrabDrone", speed = speedOfPost(3) },
}
-- Post k's eggs hatch into grade k: the two lists must agree.
assert(
	#DEBRIS_BELT_POSTS == AlienConfig.DEBRIS_BELT_GRADES,
	"GuardianConfig.DEBRIS_BELT_POSTS and AlienConfig.DEBRIS_BELT_GRADES disagree"
)

local BRAIN: GuardianBrain.Tuning = {
	aggroDelaySeconds = 1,
	leashRadius = 220,
	maxChaseSeconds = 25,
	homeRadius = 4,
	catchRadius = 7,
}

return table.freeze({
	KINDS = table.freeze(KINDS),
	FIRST_SPEED = FIRST_SPEED,
	SPEED_GROWTH = SPEED_GROWTH,
	DEBRIS_BELT_POSTS = table.freeze(DEBRIS_BELT_POSTS),
	BRAIN = table.freeze(BRAIN),
	-- The recommended speed over a guardian assumes an egg of this weight: a common one of the
	-- typical size. Lighter eggs need less, heavier ones more; that is part of the gamble.
	TYPICAL_WEIGHT = Speed.eggWeight(
		EggConfig.RARITIES.Common.weight,
		EggConfig.SIZES[EggConfig.TYPICAL_SIZE].weightFactor
	),
	-- A sleeping guardian hovers this far above its nest's egg, studs.
	HOVER_HEIGHT = 8,
	-- Guardians never come closer to the dome sphere than this, studs.
	DOME_MARGIN = 6,
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
	KIND_ATTRIBUTE = "Kind",
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
})
