--!strict
-- The client's view of its ability cooldowns: a cooldown starts when the server reports the
-- ability resolved (AbilityResult), so the clocks agree. The strike runs in the simulation, so
-- its cooldown is read straight from the predicted character. Read by the HUD chips and buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileState = require(script.Parent.ProfileState)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

-- The clock source ticks this often: cooldown text shows tenths of a second.
local CLOCK_INTERVAL = 0.1

export type Kind = ProfileState.AbilityKind

export type AbilityState = {
	name: string,
	start: () -> (),
	-- Seconds until the ability is ready again; 0 when ready. Reactive.
	left: (kind: ProfileState.AbilityKind) -> number,
	isCooling: (kind: ProfileState.AbilityKind) -> boolean,
}

local AbilityState = {}

local function cooldownFor(kind: ProfileState.AbilityKind, hit: boolean): number
	if kind == "Harpoon" then
		return if hit then PvpConfig.HARPOON.cooldownSeconds else PvpConfig.HARPOON.missCooldownSeconds
	elseif kind == "Bomb" then
		return PvpConfig.BOMB.cooldownSeconds
	end
	return PvpConfig.STRIKE.cooldownSeconds
end

function AbilityState.new(profile: ProfileState.ProfileState): AbilityState
	local readyAt: { [string]: Vide.Source<number> } = {}
	local clock = source(os.clock())

	local function readyAtOf(kind: ProfileState.AbilityKind): Vide.Source<number>
		local existing = readyAt[kind]
		if existing then
			return existing
		end
		local created = source(0)
		readyAt[kind] = created
		return created
	end

	local function left(kind: ProfileState.AbilityKind): number
		return math.max(readyAtOf(kind)() - clock(), 0)
	end

	local function start()
		profile.abilityResult.connect(function(kind, hit)
			if kind ~= "Strike" then
				readyAtOf(kind)(os.clock() + cooldownFor(kind, hit))
			end
		end)
		local sinceTick = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			sinceTick += deltaTime
			if sinceTick >= CLOCK_INTERVAL then
				sinceTick = 0
				local now = os.clock()
				local character = Players.LocalPlayer.Character
				local strikeLeft = character and character:GetAttribute(PvpConfig.STRIKE_COOLDOWN_ATTRIBUTE)
				readyAtOf("Strike")(if type(strikeLeft) == "number" then now + strikeLeft else 0)
				clock(now)
			end
		end)
	end

	return {
		name = "AbilityState",
		start = start,
		left = left,
		isCooling = function(kind)
			return left(kind) > 0
		end,
	}
end

return table.freeze(AbilityState)
