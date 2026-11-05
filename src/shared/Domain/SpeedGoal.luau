--!strict
-- The player's next speed goal: the nearest guardian they cannot outrun yet (its recommended
-- stat is above theirs), and how far along the way to it they are. Pure: the recommended stats
-- come in, from the station outwards (GuardianConfig.POSTS).

local BigNum = require("./BigNum")

local SpeedGoal = {}

export type Goal = {
	-- The post of the goal (an index into the list passed in).
	post: number,
	-- Its recommended stat.
	target: BigNum.BigNum,
	-- 0..1 from the post before's recommended stat (or nothing, for the first) to the target,
	-- on the log scale, as the stat grows tenfold at a time.
	progress: number,
}

-- The first post whose recommended stat is above `stat`; nil when every one is within reach.
function SpeedGoal.next(stat: BigNum.BigNum, recommended: { BigNum.BigNum }): Goal?
	for post, target in recommended do
		if BigNum.lessThan(stat, target) then
			local from = if post > 1 then recommended[post - 1] else nil
			return { post = post, target = target, progress = SpeedGoal.progress(stat, from, target) }
		end
	end
	return nil
end

-- How far `stat` is from `from` to `to`, 0..1, on the log scale; from nothing it is the share
-- of the way from 1.
function SpeedGoal.progress(stat: BigNum.BigNum, from: BigNum.BigNum?, to: BigNum.BigNum): number
	if BigNum.isZero(stat) or BigNum.isNegative(stat) then
		return 0
	end
	local low = if from and not BigNum.isZero(from) then BigNum.log10(from) else 0
	local high = BigNum.log10(to)
	if high <= low then
		return if BigNum.lessThan(stat, to) then 0 else 1
	end
	return math.clamp((BigNum.log10(stat) - low) / (high - low), 0, 1)
end

return table.freeze(SpeedGoal)
