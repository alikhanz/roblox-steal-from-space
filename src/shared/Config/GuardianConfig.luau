--!strict
-- Guardians of the nests: what each kind looks like, which nests get which guardian, how they
-- chase and what a catch does. Every guardian behaves the same; kinds differ in look and speed.

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
	read bodyShape: Enum.PartType,
	read bodySize: Vector3,
	read color: Color3,
}

-- A post is a guardian placed at a nest: its kind and its speed stat. Posts are handed out to
-- nests from the nearest to the station outwards, so farther nests get faster guardians.
export type Post = {
	read kind: KindId,
	read speed: BigNum.BigNum,
	-- Overrides the kind's color, so same-kind guardians of different tiers are told apart.
	read color: Color3?,
}

local KINDS: { [KindId]: Kind } = {
	SlimeWarden = {
		nameKey = "guardian.slimeWarden.title",
		bodyShape = Enum.PartType.Ball,
		bodySize = Vector3.new(6, 5, 6),
		color = Color3.fromRGB(120, 220, 90),
	},
	CrabDrone = {
		nameKey = "guardian.crabDrone.title",
		bodyShape = Enum.PartType.Block,
		bodySize = Vector3.new(7, 3, 5),
		color = Color3.fromRGB(230, 90, 70),
	},
}

-- Guardian k has speed 10 * 3^(k-1) (see GAME_DESIGN, pacing).
local DEBRIS_BELT_POSTS: { Post } = {
	{ kind = "SlimeWarden", speed = BigNum.fromNumber(10) },
	{ kind = "CrabDrone", speed = BigNum.fromNumber(30) },
	{ kind = "CrabDrone", speed = BigNum.fromNumber(90), color = Color3.fromRGB(150, 60, 200) },
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

local EYE_COLORS: { [GuardianBrain.State]: Color3 } = {
	Sleep = Color3.fromRGB(70, 70, 90),
	Chase = Color3.fromRGB(255, 40, 40),
	Return = Color3.fromRGB(255, 170, 40),
}

return table.freeze({
	KINDS = table.freeze(KINDS),
	DEBRIS_BELT_POSTS = table.freeze(DEBRIS_BELT_POSTS),
	BRAIN = table.freeze(BRAIN),
	EYE_COLORS = table.freeze(EYE_COLORS),
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
