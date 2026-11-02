--!strict
-- Starts systems (server services or client controllers) in two phases:
--   1. init  — every system, in order. Wiring only: must not yield or touch players.
--   2. start — every system, each in its own thread. Connect events and begin work here.
--
-- Pure Luau: the caller supplies `spawn` (task.spawn in the game, a direct call in tests).

-- Read-only fields, so any service or controller with these members (required or not) fits.
export type System = {
	read name: string,
	read init: (() -> ())?,
	read start: (() -> ())?,
}

export type Spawn = (callback: () -> ()) -> ()

local Lifecycle = {}

local function runInit(system: System)
	local init = system.init
	if not init then
		return
	end
	local thread = coroutine.create(init)
	local ok, err = coroutine.resume(thread)
	if not ok then
		error(`{system.name}.init failed: {err}`, 0)
	end
	if coroutine.status(thread) ~= "dead" then
		error(`{system.name}.init must not yield`, 0)
	end
end

function Lifecycle.run(systems: { System }, spawn: Spawn)
	local seen: { [string]: boolean } = {}
	for _, system in systems do
		assert(not seen[system.name], `Duplicate system name: {system.name}`)
		seen[system.name] = true
	end

	for _, system in systems do
		runInit(system)
	end

	for _, system in systems do
		local start = system.start
		if start then
			spawn(start)
		end
	end
end

return table.freeze(Lifecycle)
