--!strict
-- Player versus player: the abilities. The strike is read from the input context like any
-- flight input (the server sees the press itself, no remote), aimed where the camera looks;
-- after a wind-up whoever is in the corridor ahead takes the same hit a guardian deals, and
-- their egg flies loose. Every use is checked against Domain/Pvp's rules and counted, so the
-- numbers say whether players fight at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Abilities = require(ReplicatedStorage.Shared.Domain.Abilities)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local Flight = require(ReplicatedStorage.Shared.Domain.Flight)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local Knockback = require(script.Parent.Parent.Character.Knockback)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Pvp = require(ReplicatedStorage.Shared.Domain.Pvp)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

-- Input is polled at the guardians' rate: a press shorter than a tick is still a press, since
-- the action's state holds until it is read.
local TICK_SECONDS = 1 / 15
local LOG = RunService:IsStudio()

export type AbilityKind = "Strike" | "Harpoon" | "Bomb" | "Shield" | "Dash"
export type Notice = Pvp.Refusal | "NotReady" | "NoProfile"

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	getSpeed: (player: Player) -> BigNum.BigNum,
	-- Knocks the carried egg loose; false when the player carried nothing.
	dropEgg: (player: Player, launch: Vector3?) -> boolean,
	-- Tells a player why an ability was refused.
	notify: (player: Player, notice: Notice) -> (),
	scheduler: Scheduler.Scheduler,
}

-- Something a strike can land on: a player's character, or a test dummy.
export type Target = {
	model: Model,
	root: BasePart,
	player: Player?,
	side: () -> Pvp.Side,
	-- Takes the hit; returns true if an egg came loose.
	onHit: (direction: Vector3) -> boolean,
}

export type PvpService = {
	name: string,
	start: () -> (),
	-- Registers a target that is not a player (playtests). It is forgotten when its model goes.
	addDummy: (model: Model, root: BasePart, onHit: (direction: Vector3) -> boolean) -> (),
	-- How many times each ability was used and how many of those landed, by ability name.
	getUsage: () -> { [string]: { used: number, hit: number } },
	-- Fires after an ability resolved: the player, the ability, whether it hit, whether an egg dropped.
	abilityUsed: Signal.Signal<Player, AbilityKind, boolean, boolean>,
}

type PlayerState = {
	lastStrikeAt: number,
	strikePressed: boolean,
	spawnedAt: number,
}

local PvpService = {}

local function toVector(v: Vector3): Abilities.Vector
	return { x = v.X, y = v.Y, z = v.Z }
end

local function isInSpace(character: Model): boolean
	return character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function PvpService.new(dependencies: Dependencies): PvpService
	local states: { [Player]: PlayerState } = {}
	local dummies: { Target } = {}
	local usage: { [string]: { used: number, hit: number } } = {}
	local abilityUsed = Signal.new() :: Signal.Signal<Player, AbilityKind, boolean, boolean>

	local function count(kind: AbilityKind, hit: boolean)
		local entry = usage[kind] or { used = 0, hit = 0 }
		entry.used += 1
		if hit then
			entry.hit += 1
		end
		usage[kind] = entry
	end

	local function sideOf(player: Player, character: Model): Pvp.Side
		local data = dependencies.getData(player)
		local state = states[player]
		local shieldUntil = character:GetAttribute(PvpConfig.SHIELD_UNTIL_ATTRIBUTE)
		return {
			speed = dependencies.getSpeed(player),
			playSeconds = if data then data.playSeconds else 0,
			isInStation = not isInSpace(character),
			spawnedAt = if state then state.spawnedAt else 0,
			shieldUntil = if type(shieldUntil) == "number" then shieldUntil else 0,
		}
	end

	-- The same hit a guardian deals: thrown along the strike, tumbling, egg knocked sideways.
	local function hitPlayer(victim: Player, character: Model, direction: Vector3, by: string): boolean
		local sideways = direction:Cross(Vector3.yAxis)
		sideways = if sideways.Magnitude > 1e-3 then sideways.Unit else Vector3.xAxis
		local launch = (sideways * 0.8 + direction * 0.6).Unit * EggConfig.DROP_SPEED
		local dropped = dependencies.dropEgg(victim, launch)
		Knockback.apply(
			character,
			direction * GuardianConfig.KNOCKBACK_SPEED,
			sideways,
			GuardianConfig.STUN_SECONDS,
			by
		)
		return dropped
	end

	local function playerTargets(except: Player): { Target }
		local targets: { Target } = {}
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local root = rootOf(character)
			if other == except or not character or not root then
				continue
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health <= 0 then
				continue
			end
			table.insert(targets, {
				model = character,
				root = root,
				player = other,
				side = function()
					return sideOf(other, character)
				end,
				onHit = function(direction)
					return hitPlayer(other, character, direction, except.Name)
				end,
			})
		end
		for _, dummy in dummies do
			table.insert(targets, dummy)
		end
		return targets
	end

	-- The wind-up is over: whoever stands in the corridor takes the hit, or the attacker
	-- overreaches and loses a moment of thrust.
	local function resolveStrike(player: Player, character: Model, direction: Vector3)
		local root = rootOf(character)
		if not root or character.Parent == nil or not isInSpace(character) then
			return
		end
		local attacker = sideOf(player, character)
		local targets = playerTargets(player)
		local candidates: { { id: number, position: Abilities.Vector } } = {}
		for index, target in targets do
			table.insert(candidates, { id = index, position = toVector(target.root.Position) })
		end
		local reach = PvpConfig.STRIKE.lungeStuds + PvpConfig.STRIKE.reachStuds
		local index = Abilities.nearestInCone(
			toVector(root.Position),
			toVector(direction),
			candidates,
			reach,
			PvpConfig.STRIKE.halfAngleRadians
		)
		local target = if index then targets[index] else nil
		if target then
			local refusal = Pvp.refusal(attacker, target.side(), time(), PvpConfig.RULES)
			if refusal then
				-- The notice says why; no "miss" on top of it.
				dependencies.notify(player, refusal)
				count("Strike", false)
				return
			end
			local away = target.root.Position - root.Position
			local push = if away.Magnitude > 1e-3 then away.Unit else direction
			local dropped = target.onHit(push)
			count("Strike", true)
			if LOG then
				local outcome = if dropped then "knocked the egg loose" else "no egg"
				print(`[PvpService] {player.Name} struck {target.model.Name}: {outcome}`)
			end
			abilityUsed.fire(player, "Strike", true, dropped)
			return
		end
		-- A miss: the attacker keeps their speed but cannot steer for a moment.
		Knockback.apply(
			character,
			root.AssemblyLinearVelocity,
			Vector3.zero,
			PvpConfig.STRIKE.missStallSeconds,
			player.Name
		)
		count("Strike", false)
		abilityUsed.fire(player, "Strike", false, false)
	end

	local function strike(player: Player, state: PlayerState)
		local character = player.Character
		local root = rootOf(character)
		if not character or not root then
			return
		end
		if not dependencies.getData(player) then
			dependencies.notify(player, "NoProfile")
			return
		end
		if not isInSpace(character) then
			dependencies.notify(player, "AttackerInStation")
			return
		end
		if Knockback.isStunned(character) then
			return
		end
		if not Abilities.isReady(state.lastStrikeAt, time(), PvpConfig.STRIKE.cooldownSeconds) then
			dependencies.notify(player, "NotReady")
			return
		end
		local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
		local aim = if context then FlightInputs.readAim(context) else nil
		local sanitized = Flight.sanitizeAim(aim or root.CFrame.LookVector)
		local direction = if sanitized and sanitized.Magnitude > 1e-3 then sanitized.Unit else root.CFrame.LookVector
		state.lastStrikeAt = time()
		task.delay(PvpConfig.STRIKE.windupSeconds, resolveStrike, player, character, direction)
	end

	local function tick()
		for player, state in states do
			local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
			local pressed = context ~= nil and FlightInputs.isPressed(context, FlightInputs.STRIKE)
			if pressed and not state.strikePressed then
				strike(player, state)
			end
			state.strikePressed = pressed
		end
	end

	local function watch(player: Player)
		local state: PlayerState = { lastStrikeAt = 0, strikePressed = false, spawnedAt = time() }
		states[player] = state
		player.CharacterAdded:Connect(function()
			state.spawnedAt = time()
		end)
	end

	local function addDummy(model: Model, root: BasePart, onHit: (direction: Vector3) -> boolean)
		-- A seasoned, very fast target: no rule ever shields it.
		local seasoned: Pvp.Side = {
			speed = BigNum.new(1, 30),
			playSeconds = math.huge,
			isInStation = false,
			spawnedAt = -math.huge,
			shieldUntil = 0,
		}
		local target: Target = {
			model = model,
			root = root,
			player = nil,
			side = function()
				return seasoned
			end,
			onHit = onHit,
		}
		table.insert(dummies, target)
		model.Destroying:Once(function()
			local index = table.find(dummies, target)
			if index then
				table.remove(dummies, index)
			end
		end)
	end

	local function start()
		PlayerEvents.observe(watch, function(player)
			states[player] = nil
		end)
		dependencies.scheduler.every(TICK_SECONDS, tick)
	end

	return {
		name = "PvpService",
		start = start,
		addDummy = addDummy,
		getUsage = function()
			return usage
		end,
		abilityUsed = abilityUsed,
	}
end

return table.freeze(PvpService)
