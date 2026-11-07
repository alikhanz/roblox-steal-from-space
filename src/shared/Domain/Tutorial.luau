--!strict
-- The tutorial (decision 065): the first loop a new player goes through, one hint at a time.
-- The profile keeps how many milestones are passed (delivered an egg, hatched it, trained to
-- the next guardian, delivered from a stronger one); what the player is told to do now follows
-- from that and from whether they carry an egg, so a lost egg simply brings back "steal".
-- Pure Luau.

local BigNum = require("./BigNum")

local Tutorial = {}

-- What the player is told to do. Steal and CarryHome come twice: for the first guardian and,
-- after training, for a stronger one.
export type Hint = "Steal" | "CarryHome" | "Hatch" | "Train" | "StealStronger" | "CarryHomeStronger" | "Done"

-- Milestones passed, the number kept in the profile.
Tutorial.NOT_STARTED = 0
Tutorial.DELIVERED = 1
Tutorial.HATCHED = 2
Tutorial.TRAINED = 3
Tutorial.DONE = 4

-- What to do now, after `progress` milestones, carrying an egg or not.
function Tutorial.hint(progress: number, carrying: boolean): Hint
	if progress <= Tutorial.NOT_STARTED then
		return if carrying then "CarryHome" else "Steal"
	elseif progress == Tutorial.DELIVERED then
		return "Hatch"
	elseif progress == Tutorial.HATCHED then
		return "Train"
	elseif progress == Tutorial.TRAINED then
		return if carrying then "CarryHomeStronger" else "StealStronger"
	end
	return "Done"
end

-- The progress after an egg of guardian `grade` is delivered: the first egg of any guardian, then
-- one of `strongerGrade` or farther.
function Tutorial.afterDelivery(progress: number, grade: number, strongerGrade: number): number
	if progress == Tutorial.NOT_STARTED then
		return Tutorial.DELIVERED
	elseif progress == Tutorial.TRAINED and grade >= strongerGrade then
		return Tutorial.DONE
	end
	return progress
end

-- The progress after an alien hatched.
function Tutorial.afterHatch(progress: number): number
	return if progress == Tutorial.DELIVERED then Tutorial.HATCHED else progress
end

-- The progress once the player's speed stat is `reached` (true when it is at the stronger
-- guardian's recommendation or above): whenever that holds on the training step.
function Tutorial.afterSpeed(progress: number, reached: boolean): number
	return if progress == Tutorial.HATCHED and reached then Tutorial.TRAINED else progress
end

-- How long an egg delivered at `progress` warms: the very first one is quick, so the hatch step
-- is not a wait.
function Tutorial.hatchSeconds(progress: number, seconds: number, firstEggSeconds: number): number
	return if progress == Tutorial.NOT_STARTED then math.min(seconds, firstEggSeconds) else seconds
end

-- The progress of a profile from before the tutorial: done for a player who has already
-- delivered from the stronger guardian or farther (`bestPost`), from the start otherwise.
function Tutorial.fromBestPost(bestPost: number, strongerGrade: number): number
	return if bestPost >= strongerGrade then Tutorial.DONE else Tutorial.NOT_STARTED
end

-- The steps the player sees counted (the dots of the hint panel): steal, carry home, hatch,
-- train, steal from a stronger guardian (carrying that egg home is still the last step).
Tutorial.STEP_COUNT = 5

local STEPS: { [Hint]: number } = {
	Steal = 1,
	CarryHome = 2,
	Hatch = 3,
	Train = 4,
	StealStronger = 5,
	CarryHomeStronger = 5,
}

-- Whether a stealing step leads the player back to the egg they dropped rather than to a nest:
-- its guardian (of `grade`; nil for a keeper with none) counts for the step (at least
-- `stepGrade`) and is one the player outruns (their `speed` at least its `recommended`).
function Tutorial.backToDropped(
	grade: number?,
	stepGrade: number,
	speed: BigNum.BigNum,
	recommended: BigNum.BigNum
): boolean
	return grade ~= nil and grade >= stepGrade and not BigNum.lessThan(speed, recommended)
end

-- The step `hint` belongs to, 1..STEP_COUNT; nil once the tutorial is done.
function Tutorial.stepOf(hint: Hint): number?
	return STEPS[hint]
end

return table.freeze(Tutorial)
