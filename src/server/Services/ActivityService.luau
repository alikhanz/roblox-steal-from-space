--!strict
-- Keeps track of who is actually playing and who is away (Domain/Activity, ActivityConfig):
-- characters' positions once a second, and every command a player sends (NetService calls
-- `touch`). Other services ask `isActive` / `activeCount`; `changed` tells when a player goes
-- away or comes back, for whatever is built on it later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Activity = require(ReplicatedStorage.Shared.Domain.Activity)
local ActivityConfig = require(ReplicatedStorage.Shared.Config.ActivityConfig)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

export type Dependencies = {
	scheduler: Scheduler.Scheduler,
}

export type ActivityService = {
	name: string,
	start: () -> (),
	-- The player did something (a command).
	touch: (player: Player) -> (),
	isActive: (player: Player) -> boolean,
	-- Players on the server who are not away.
	activeCount: () -> number,
	idleSeconds: (player: Player) -> number,
	-- A player went away (false) or came back (true).
	changed: Signal.Signal<Player, boolean>,
}

type Tracked = {
	state: Activity.State,
	active: boolean,
}

local ActivityService = {}

local function now(): number
	return os.clock()
end

function ActivityService.new(dependencies: Dependencies): ActivityService
	local tracked: { [Player]: Tracked } = {}
	local changed = Signal.new() :: Signal.Signal<Player, boolean>

	local function refresh(player: Player, entry: Tracked)
		local active = Activity.isActive(entry.state, now(), ActivityConfig)
		if active ~= entry.active then
			entry.active = active
			changed.fire(player, active)
		end
	end

	local function sample()
		for player, entry in tracked do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local position = root.Position
				Activity.observe(entry.state, now(), position.X, position.Y, position.Z, ActivityConfig)
			end
			refresh(player, entry)
		end
	end

	local function track(player: Player)
		local entry: Tracked = { state = Activity.new(now()), active = true }
		tracked[player] = entry
		-- A respawn puts the character elsewhere: that is not the player moving.
		player.CharacterAdded:Connect(function()
			Activity.forgetAnchor(entry.state)
		end)
	end

	local function start()
		PlayerEvents.observe(track, function(player)
			tracked[player] = nil
		end)
		dependencies.scheduler.every(ActivityConfig.SAMPLE_SECONDS, sample)
	end

	return {
		name = "ActivityService",
		start = start,
		touch = function(player)
			local entry = tracked[player]
			if entry then
				Activity.touch(entry.state, now())
				refresh(player, entry)
			end
		end,
		isActive = function(player)
			local entry = tracked[player]
			return entry ~= nil and entry.active
		end,
		activeCount = function()
			local count = 0
			for _, entry in tracked do
				if entry.active then
					count += 1
				end
			end
			return count
		end,
		idleSeconds = function(player)
			local entry = tracked[player]
			return if entry then Activity.idleSeconds(entry.state, now()) else 0
		end,
		changed = changed,
	}
end

return table.freeze(ActivityService)
