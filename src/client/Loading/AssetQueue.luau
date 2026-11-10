--!strict
-- The client's preloads in one place (Domain/LoadOrder, LoadConfig). Every
-- ContentProvider:PreloadAsync puts its assets at the front of the download queue, so the client
-- asks for the player's own jetpack straight away (`now`) and holds every other preload (`later`)
-- until it is in (`open`, from JetpackLoadController); then they go one at a time by priority, so a
-- burst of them (pets on every island) cannot crowd out what the player sees first.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadConfig = require(ReplicatedStorage.Shared.Config.LoadConfig)
local LoadOrder = require(ReplicatedStorage.Shared.Domain.LoadOrder)

export type Asset = Instance | string

type Job = {
	label: string,
	assets: { Asset },
}

local AssetQueue = {}

local queue = LoadOrder.new() :: LoadOrder.Queue<Job>
local isOpen = false
local isDraining = false

-- Asks for `assets` and yields until each has resolved. A failure is logged, never raised: an
-- asset that did not load must not stop the caller.
local function preload(label: string, assets: { Asset })
	if #assets == 0 then
		return
	end
	local ok, problem = pcall(ContentProvider.PreloadAsync, ContentProvider, assets)
	if not ok then
		warn(`[AssetQueue] Preloading {label} failed: {problem}`)
	end
end

-- Runs the queue one preload at a time. One that takes too long stops holding up the next, but
-- goes on loading.
local function drain()
	if isDraining then
		return
	end
	isDraining = true
	task.spawn(function()
		while true do
			local job = LoadOrder.pop(queue)
			if not job then
				break
			end
			local isDone = false
			task.spawn(function()
				preload(job.label, job.assets)
				isDone = true
			end)
			local started = os.clock()
			while not isDone and os.clock() - started < LoadConfig.JOB_SECONDS do
				task.wait()
			end
		end
		isDraining = false
	end)
end

-- Asks for `assets` at once, ahead of the queue (the player's own jetpack). Yields until they resolve.
function AssetQueue.now(label: string, assets: { Asset })
	preload(label, assets)
end

-- Asks for `assets` once the player's own jetpack is in, after anything of a higher `priority`
-- (LoadConfig.PRIORITY). Does not yield.
function AssetQueue.later(label: string, priority: number, assets: { Asset })
	if #assets == 0 then
		return
	end
	LoadOrder.push(queue, priority, { label = label, assets = assets })
	if isOpen then
		drain()
	end
end

-- The player's own jetpack is in (or the wait is over): the queue may run.
function AssetQueue.open()
	if isOpen then
		return
	end
	isOpen = true
	drain()
end

function AssetQueue.isOpen(): boolean
	return isOpen
end

return table.freeze(AssetQueue)
