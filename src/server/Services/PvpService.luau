--!strict
-- Player versus player: the abilities. Every one is an input action in the flight context
-- (the server sees the press itself, no remote), aimed where the camera looks, checked against
-- Domain/Pvp's rules and counted, so the numbers say whether players fight at all.
--   Strike: a lunge along the aim, run by the simulation; whoever the attacker touches on the
--     way takes a guardian's hit, right at the touch.
--   Harpoon: the nearest egg carrier in a narrow cone loses the egg toward the shooter.
--   Bomb: flies ahead until it reaches someone, then throws everyone around it.
--   Shield: nothing lands on the player for a while.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Abilities = require(ReplicatedStorage.Shared.Domain.Abilities)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CarryService = require(script.Parent.CarryService)
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
local PvpEffects = require(script.Parent.Parent.World.PvpEffects)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

-- Input is polled at the guardians' rate: a press shorter than a tick is still a press, since
-- the action's state holds until it is read.
local TICK_SECONDS = 1 / 15
local LOG = RunService:IsStudio()

export type AbilityKind = "Strike" | "Harpoon" | "Bomb" | "Shield"
export type Notice = Pvp.Refusal | "NotReady" | "NoProfile"

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	getSpeed: (player: Player) -> BigNum.BigNum,
	-- True while the player carries an egg.
	isCarrying: (player: Player) -> boolean,
	-- Knocks the carried egg loose; false when the player carried nothing.
	dropEgg: (player: Player, launch: Vector3?, reason: CarryService.LossReason?) -> boolean,
	-- Tells a player why an ability was refused.
	notify: (player: Player, notice: Notice) -> (),
	scheduler: Scheduler.Scheduler,
}

-- Something an attack can land on: a player's character, or a test dummy.
export type Target = {
	model: Model,
	root: BasePart,
	player: Player?,
	side: () -> Pvp.Side,
	isCarrying: () -> boolean,
	-- Takes a hit thrown along `direction`; returns true if an egg came loose.
	onHit: (direction: Vector3) -> boolean,
	-- Loses the egg (no throw), launched along `launch`; returns true if an egg came loose.
	onHarpoon: (launch: Vector3) -> boolean,
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
	lastUsedAt: { [AbilityKind]: number },
	pressed: { [AbilityKind]: boolean },
	spawnedAt: number,
	-- The strike's lunge in progress: whether it already touched someone (one hit per lunge).
	lunge: { touched: boolean }?,
}

-- The abilities started by a press here; the strike starts in the simulation instead.
local INPUT_ACTIONS: { [AbilityKind]: string } = {
	Harpoon = FlightInputs.HARPOON,
	Bomb = FlightInputs.BOMB,
	Shield = FlightInputs.SHIELD,
}
local ABILITY_ORDER: { AbilityKind } = { "Harpoon", "Bomb", "Shield" }
local COOLDOWNS: { [AbilityKind]: number } = {
	Harpoon = PvpConfig.HARPOON.cooldownSeconds,
	Bomb = PvpConfig.BOMB.cooldownSeconds,
	Shield = PvpConfig.SHIELD.cooldownSeconds,
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

-- A unit vector at a right angle to `direction`, for the tumble axis and the egg's launch.
local function sidewaysOf(direction: Vector3): Vector3
	local sideways = direction:Cross(Vector3.yAxis)
	return if sideways.Magnitude > 1e-3 then sideways.Unit else Vector3.xAxis
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

	local function resolved(player: Player, kind: AbilityKind, hit: boolean, droppedEgg: boolean)
		count(kind, hit)
		abilityUsed.fire(player, kind, hit, droppedEgg)
		if LOG then
			local outcome = if not hit then "missed" elseif droppedEgg then "hit, egg loose" else "hit"
			print(`[PvpService] {player.Name} {kind}: {outcome}`)
		end
	end

	local function sideOf(player: Player, character: Model): Pvp.Side
		local data = dependencies.getData(player)
		local state = states[player]
		-- The shield's end is kept in server time (the simulation on every client reads it);
		-- the rules run on the server clock.
		local shieldUntil = character:GetAttribute(PvpConfig.SHIELD_UNTIL_ATTRIBUTE)
		local shieldLeft = if type(shieldUntil) == "number" then shieldUntil - workspace:GetServerTimeNow() else 0
		return {
			speed = dependencies.getSpeed(player),
			playSeconds = if data then data.playSeconds else 0,
			isInStation = not isInSpace(character),
			spawnedAt = if state then state.spawnedAt else 0,
			shieldUntil = time() + shieldLeft,
		}
	end

	-- The same hit a guardian deals: thrown along `direction`, tumbling, the egg knocked on
	-- along the blow and a little aside, so it is plainly the hit that sent it flying.
	local function hitPlayer(victim: Player, character: Model, direction: Vector3, by: string): boolean
		local sideways = sidewaysOf(direction)
		local launch = (direction * 0.85 + sideways * 0.5).Unit * EggConfig.DROP_SPEED
		local dropped = dependencies.dropEgg(victim, launch, "Pvp")
		Knockback.apply(
			character,
			direction * GuardianConfig.KNOCKBACK_SPEED,
			sideways,
			GuardianConfig.STUN_SECONDS,
			by
		)
		return dropped
	end

	local function targetsFor(attacker: Player): { Target }
		local targets: { Target } = {}
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local root = rootOf(character)
			if other == attacker or not character or not root then
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
				isCarrying = function()
					return dependencies.isCarrying(other)
				end,
				onHit = function(direction)
					return hitPlayer(other, character, direction, attacker.Name)
				end,
				onHarpoon = function(launch)
					return dependencies.dropEgg(other, launch, "Pvp")
				end,
			})
		end
		for _, dummy in dummies do
			table.insert(targets, dummy)
		end
		return targets
	end

	-- The nearest target in the cone ahead of `root`, among those passing `filter`.
	local function findInCone(
		root: BasePart,
		direction: Vector3,
		targets: { Target },
		reach: number,
		halfAngle: number,
		filter: (Target) -> boolean
	): Target?
		local candidates: { { id: number, position: Abilities.Vector } } = {}
		for index, target in targets do
			if filter(target) then
				table.insert(candidates, { id = index, position = toVector(target.root.Position) })
			end
		end
		local index =
			Abilities.nearestInCone(toVector(root.Position), toVector(direction), candidates, reach, halfAngle)
		return if index then targets[index] else nil
	end

	-- Where the player aims right now: the camera direction their input context carries, or
	-- where the character faces if it carries none.
	local function aimOf(player: Player, root: BasePart): Vector3
		local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
		local aim = if context then FlightInputs.readAim(context) else nil
		local sanitized = Flight.sanitizeAim(aim or root.CFrame.LookVector)
		return if sanitized and sanitized.Magnitude > 1e-3 then sanitized.Unit else root.CFrame.LookVector
	end

	-- Shared preamble of every attack: a live character out in space, off cooldown. Returns
	-- the character, its root and the aim, or nil after telling the player why not.
	local function prepare(player: Player, state: PlayerState, kind: AbilityKind): (Model?, BasePart?, Vector3?)
		local character = player.Character
		local root = rootOf(character)
		if not character or not root then
			return nil, nil, nil
		end
		if not dependencies.getData(player) then
			dependencies.notify(player, "NoProfile")
			return nil, nil, nil
		end
		if not isInSpace(character) then
			dependencies.notify(player, "AttackerInStation")
			return nil, nil, nil
		end
		if Knockback.isStunned(character) then
			return nil, nil, nil
		end
		if not Abilities.isReady(state.lastUsedAt[kind] or 0, time(), COOLDOWNS[kind]) then
			dependencies.notify(player, "NotReady")
			return nil, nil, nil
		end
		return character, root, aimOf(player, root)
	end

	-- The strike: the simulation lunges the attacker along the aim (PvpConfig.STRIKE_* attributes);
	-- here, every frame of the lunge, the first target touched takes the hit, an impact flash
	-- marks the spot and the egg flies off along the strike. No touch by the end is a miss.
	local function watchLunge(player: Player, state: PlayerState)
		local character = player.Character
		local root = rootOf(character)
		local left = character and character:GetAttribute(PvpConfig.STRIKE_LUNGE_ATTRIBUTE)
		if not character or not root or type(left) ~= "number" or left <= 0 then
			if state.lunge and not state.lunge.touched then
				resolved(player, "Strike", false, false)
			end
			state.lunge = nil
			return
		end
		local lunge = state.lunge or { touched = false }
		state.lunge = lunge
		local aim = character:GetAttribute(PvpConfig.STRIKE_AIM_ATTRIBUTE)
		if lunge.touched or typeof(aim) ~= "Vector3" or Knockback.isStunned(character) then
			return
		end
		local function anyone()
			return true
		end
		local target = findInCone(
			root,
			aim,
			targetsFor(player),
			PvpConfig.STRIKE.contactStuds,
			PvpConfig.STRIKE.contactHalfAngleRadians,
			anyone
		)
		if not target then
			return
		end
		lunge.touched = true
		local refusal = Pvp.refusal(sideOf(player, character), target.side(), time(), PvpConfig.RULES)
		if refusal then
			dependencies.notify(player, refusal)
			count("Strike", false)
			return
		end
		PvpEffects.strikeImpact(root.Position:Lerp(target.root.Position, 0.6))
		resolved(player, "Strike", true, target.onHit(aim))
	end

	local function watchLunges()
		for player, state in states do
			watchLunge(player, state)
		end
	end

	-- The harpoon: the nearest egg carrier in a narrow cone loses the egg, which flies toward
	-- the shooter. Nothing else happens to the carrier.
	local function harpoon(player: Player, state: PlayerState)
		local character, root, direction = prepare(player, state, "Harpoon")
		if not character or not root or not direction then
			return
		end
		local attacker = sideOf(player, character)
		local target = findInCone(
			root,
			direction,
			targetsFor(player),
			PvpConfig.HARPOON.rangeStuds,
			PvpConfig.HARPOON.halfAngleRadians,
			function(candidate)
				return candidate.isCarrying()
			end
		)
		if not target then
			local discount = PvpConfig.HARPOON.cooldownSeconds - PvpConfig.HARPOON.missCooldownSeconds
			state.lastUsedAt.Harpoon = time() - discount
			PvpEffects.harpoonBeam(root, root.Position + direction * PvpConfig.HARPOON.rangeStuds)
			resolved(player, "Harpoon", false, false)
			return
		end
		local refusal = Pvp.refusal(attacker, target.side(), time(), PvpConfig.RULES)
		if refusal then
			dependencies.notify(player, refusal)
			count("Harpoon", false)
			return
		end
		state.lastUsedAt.Harpoon = time()
		local toShooter = root.Position - target.root.Position
		local launch = (if toShooter.Magnitude > 1e-3 then toShooter.Unit else -direction) * EggConfig.DROP_SPEED
		PvpEffects.harpoonBeam(root, target.root.Position)
		resolved(player, "Harpoon", true, target.onHarpoon(launch))
	end

	-- The bomb flies straight ahead for the fuse, then everyone around it is thrown outward
	-- and their eggs come loose; the thrower is spared, and so is anyone the rules protect.
	local function explode(player: Player, character: Model, center: Vector3)
		PvpEffects.bombFlash(center, PvpConfig.BOMB.radiusStuds)
		if character.Parent == nil then
			return
		end
		local attacker = sideOf(player, character)
		local targets = targetsFor(player)
		local candidates: { { id: number, position: Abilities.Vector } } = {}
		for index, target in targets do
			table.insert(candidates, { id = index, position = toVector(target.root.Position) })
		end
		local hit, dropped = false, false
		for _, index in Abilities.withinRadius(toVector(center), candidates, PvpConfig.BOMB.radiusStuds) do
			local target = targets[index]
			if Pvp.refusal(attacker, target.side(), time(), PvpConfig.RULES) then
				continue
			end
			local away = target.root.Position - center
			local push = if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis
			hit = true
			dropped = target.onHit(push) or dropped
		end
		resolved(player, "Bomb", hit, dropped)
	end

	local function bomb(player: Player, state: PlayerState)
		local character, root, direction = prepare(player, state, "Bomb")
		if not character or not root or not direction then
			return
		end
		state.lastUsedAt.Bomb = time()
		local start = root.Position + direction * 3
		-- Goes off early when it reaches someone, so a throw at a player lands on them.
		local function touches(position: Vector3): boolean
			for _, target in targetsFor(player) do
				if (target.root.Position - position).Magnitude <= PvpConfig.BOMB.contactStuds then
					return true
				end
			end
			return false
		end
		local function onExplode(center: Vector3)
			explode(player, character, center)
		end
		local velocity = direction * PvpConfig.BOMB.throwSpeed
		PvpEffects.throwBomb(start, velocity, PvpConfig.BOMB.fuseSeconds, touches, onExplode)
	end

	-- The shield: nothing lands on the player for a while. Written in server time for the
	-- rules and every client's view.
	local function shield(player: Player, state: PlayerState)
		local character = prepare(player, state, "Shield")
		if not character then
			return
		end
		state.lastUsedAt.Shield = time()
		local until_ = workspace:GetServerTimeNow() + PvpConfig.SHIELD.seconds
		character:SetAttribute(PvpConfig.SHIELD_UNTIL_ATTRIBUTE, until_)
		PvpEffects.shieldBubble(character, PvpConfig.SHIELD.seconds)
		resolved(player, "Shield", true, false)
	end

	local ABILITIES: { [AbilityKind]: (Player, PlayerState) -> () } = {
		Harpoon = harpoon,
		Bomb = bomb,
		Shield = shield,
	}

	-- Seconds of newbie protection left, on the player for every client's view: the sign over
	-- a newbie, and the newbie's own HUD. Written only when the whole second changes.
	local function publishNewbie(player: Player)
		local data = dependencies.getData(player)
		if not data then
			return
		end
		local left = math.max(math.ceil(PvpConfig.RULES.newbieSeconds - data.playSeconds), 0)
		if player:GetAttribute(PvpConfig.NEWBIE_ATTRIBUTE) ~= left then
			player:SetAttribute(PvpConfig.NEWBIE_ATTRIBUTE, left)
		end
	end

	local function tick()
		for player, state in states do
			publishNewbie(player)
			local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
			for _, kind in ABILITY_ORDER do
				local pressed = context ~= nil and FlightInputs.isPressed(context, INPUT_ACTIONS[kind])
				if pressed and not state.pressed[kind] then
					ABILITIES[kind](player, state)
				end
				state.pressed[kind] = pressed
			end
		end
	end

	local function watch(player: Player)
		local state: PlayerState = { lastUsedAt = {}, pressed = {}, spawnedAt = time() }
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
			isCarrying = function()
				return true
			end,
			onHit = onHit,
			onHarpoon = onHit,
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
		-- Every frame, right after the simulation moved everyone: a lunge is short and fast.
		RunService.PostSimulation:Connect(watchLunges)
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
