--!strict
-- One tick source for many periodic jobs, each at its own rate (guardians ~15 Hz, respawns
-- 10 Hz, income 1 Hz). The owner drives `step` from a single Heartbeat connection.
--
-- Pure Luau: no Roblox globals, so it is tested in Lune.

export type Job = (deltaTime: number) -> ()

export type Scheduler = {
	-- Runs `job` about every `intervalSeconds` (0 = every step) with the time since its last run.
	-- Returns a function that cancels the job.
	every: (intervalSeconds: number, job: Job) -> () -> (),
	step: (deltaTime: number) -> (),
}

type Entry = {
	interval: number,
	job: Job,
	elapsed: number,
	cancelled: boolean,
}

local Scheduler = {}

function Scheduler.new(): Scheduler
	local entries: { Entry } = {}

	local function every(intervalSeconds: number, job: Job): () -> ()
		assert(intervalSeconds >= 0, "Scheduler interval must not be negative")
		local entry: Entry = { interval = intervalSeconds, job = job, elapsed = 0, cancelled = false }
		table.insert(entries, entry)
		return function()
			entry.cancelled = true
		end
	end

	local function step(deltaTime: number)
		-- Iterate backwards so cancelled jobs can be removed in place.
		for index = #entries, 1, -1 do
			local entry = entries[index]
			if entry.cancelled then
				table.remove(entries, index)
				continue
			end
			entry.elapsed += deltaTime
			-- A slow frame runs a job once with the whole elapsed time, never in a catch-up burst.
			if entry.elapsed >= entry.interval then
				local elapsed = entry.elapsed
				entry.elapsed = 0
				entry.job(elapsed)
			end
		end
	end

	return { every = every, step = step }
end

return table.freeze(Scheduler)
