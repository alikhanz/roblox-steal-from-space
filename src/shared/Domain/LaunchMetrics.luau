--!strict
-- The numbers the launch watches (decisions 126, 131, 143), as analytics fields: where a session
-- ends (the best post beaten, the speed goal, how long it lasted, whether it was the first), and
-- the day-1 wall, the time from the first delivery from post 10 to the first from post 11. The
-- wall's start is kept in the profile, so it survives leaving and rejoining. Pure Luau.

local MetricsConfig = require("../Config/MetricsConfig")

local LaunchMetrics = {}

-- In the profile: when the player first delivered from the wall's first post. `startedAt` is
-- server time, 0 while they have not; `startedPlaySeconds` is their play time then.
export type Wall = {
	startedAt: number,
	startedPlaySeconds: number,
}

-- How long the wall took, seconds: in real time and in time in the game.
export type WallCrossing = {
	realSeconds: number,
	playSeconds: number,
}

function LaunchMetrics.emptyWall(): Wall
	return { startedAt = 0, startedPlaySeconds = 0 }
end

-- The label of the range `seconds` falls in.
function LaunchMetrics.rangeOf(seconds: number, ranges: { MetricsConfig.Range }): string
	for _, range in ranges do
		if seconds < range.limit then
			return range.label
		end
	end
	return ranges[#ranges].label
end

-- The fields of a session's end: the best post beaten (0: none yet), the speed goal's post (nil:
-- every guardian is within reach), and its length, marked "First" for the account's first.
function LaunchMetrics.sessionFields(bestPost: number, goalPost: number?, isFirst: boolean, seconds: number): { string }
	local length = LaunchMetrics.rangeOf(seconds, MetricsConfig.SESSION_RANGES)
	return {
		`Best - {bestPost}`,
		if goalPost then `Goal - {goalPost}` else "Goal - None",
		`{if isFirst then "First" else "Return"} - {length}`,
	}
end

-- A delivery raised the best post from `before` to `after` at server time `now`, with
-- `playSeconds` played: starts the wall on first reaching its first post and returns how long it
-- took on first reaching its last. Both can happen at once (an egg from past the wall), which
-- took no time. A wall that started before it was measured (a profile from before v26 already
-- past post 10) has no start and reports nothing.
function LaunchMetrics.passWall(
	wall: Wall,
	before: number,
	after: number,
	now: number,
	playSeconds: number
): WallCrossing?
	local from, to = MetricsConfig.WALL_FROM_POST, MetricsConfig.WALL_TO_POST
	if before < from and after >= from and wall.startedAt == 0 then
		wall.startedAt = now
		wall.startedPlaySeconds = playSeconds
	end
	if before >= to or after < to or wall.startedAt == 0 then
		return nil
	end
	return {
		realSeconds = math.max(now - wall.startedAt, 0),
		playSeconds = math.max(playSeconds - wall.startedPlaySeconds, 0),
	}
end

-- The fields of a crossed wall: its real time and its time in the game.
function LaunchMetrics.wallFields(crossing: WallCrossing): { string }
	return {
		LaunchMetrics.rangeOf(crossing.realSeconds, MetricsConfig.WALL_REAL_RANGES),
		LaunchMetrics.rangeOf(crossing.playSeconds, MetricsConfig.WALL_PLAY_RANGES),
	}
end

return table.freeze(LaunchMetrics)
