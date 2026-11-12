--!strict
-- Player versus player: the abilities. Every one is an input action in the flight context
-- (the server sees the press itself, no remote), aimed where the camera looks, checked against
-- Domain/Pvp's rules and counted, so the numbers say whether players fight at all.
--   Strike: a lunge along the aim, run by the simulation; whoever the attacker touches on the
--     way takes a guardian's hit, right at the touch.
--   Harpoon: the egg carrier nearest the crosshair in the aim assist's cone loses the egg toward
--     the shooter (decision 103).
--   Bomb: leaves with the thrower's velocity, homes on the target nearest the crosshair until it
--     reaches someone, then throws everyone around it (decision 103).
-- No shield (decision 060): the only defence is speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Abilities = require(ReplicatedStorage.Shared.Domain.Abilities)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local BombFlight = require(script.Parent.Parent.World.BombFlight)
local CarryService = require(script.Parent.CarryService)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local Flight = require(ReplicatedStorage.Shared.Domain.Flight)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local Homing = require(ReplicatedStorage.Shared.Domain.Homing)
local Knockback = require(script.Parent.Parent.Character.Knockback)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PlayerEvents = require(script.Parent.Parent.Runtime.PlayerEvents)
local Pvp = require(ReplicatedStorage.Shared.Domain.Pvp)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local PvpEffects = require(script.Parent.Parent.World.PvpEffects)
local PvpFx = require(ReplicatedStorage.Shared.Domain.PvpFx)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Vitals = require(ReplicatedStorage.Shared.Character.Vitals)

-- Input is polled at the guardians' rate: a press shorter than a tick is still a press, since
-- the action's state holds until it is read.
local TICK_SECONDS = 1 / 15
local LOG = RunService:IsStudio()

export type AbilityKind = "Strike" | "Harpoon" | "Bomb"
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

-- Something an attack can land on that is not a player: the star serpent, a test dummy.
export type Creature = {
	model: Model,
	root: BasePart,
	-- Its body's radius around `root`, studs: attacks land on its surface (0: a point).
	radius: number,
	-- True while it holds an egg (the harpoon only goes for egg carriers).
	isCarrying: () -> boolean,
	-- Takes a hit by `attacker` thrown along `direction`; returns true if an egg came loose.
	onHit: (direction: Vector3, attacker: Player) -> boolean,
	-- Loses the egg to `attacker`'s harpoon (no throw), launched along `launch`; returns true
	-- if an egg came loose.
	onHarpoon: (launch: Vector3, attacker: Player) -> boolean,
}

-- Something an attack can land on: a player's character, or a creature.
type Target = {
	model: Model,
	root: BasePart,
	player: Player?,
	radius: number,
	-- Why `attacker` may not attack it right now, or nil when they may.
	refusal: (attacker: Pvp.Side) -> Pvp.Refusal?,
	isCarrying: () -> boolean,
	onHit: (direction: Vector3, attacker: Player) -> boolean,
	onHarpoon: (launch: Vector3, attacker: Player) -> boolean,
}

export type PvpService = {
	name: string,
	start: () -> (),
	-- Registers a creature attacks can land on. It is forgotten when its model goes.
	addCreature: (creature: Creature) -> (),
	-- How many times each ability was used and how many of those landed, by ability name.
	getUsage: () -> { [string]: { used: number, hit: number } },
	-- Fires after an ability resolved: the player, the ability, whether it hit, whether an egg dropped.
	abilityUsed: Signal.Signal<Player, AbilityKind, boolean, boolean>,
	-- What every client draws (World/HarpoonVisual, World/BombVisual; NetService sends it).
	harpoonShot: Signal.Signal<Shot>,
	bombThrown: Signal.Signal<Throw>,
	bombExploded: Signal.Signal<Blast>,
}

-- A harpoon shot: where the hook flies (the target's surface, or the end of the reach on a
-- miss), the aim it was fired along, whether it hit and whether an egg came loose there.
export type Shot = { shooter: Player, target: Vector3, aim: Vector3, hit: boolean, egg: boolean }
-- A bomb thrown: it flies from `start` at `velocity` for at most `fuse` seconds, steering for
-- `target` (a root part) when it has one.
export type Throw = {
	id: number,
	thrower: Player,
	start: Vector3,
	velocity: Vector3,
	fuse: number,
	target: BasePart?,
}
-- The bomb `id` went off at `center`.
export type Blast = { id: number, center: Vector3 }

-- Bomb ids go round within the wire's u16.
local BOMB_ID_LIMIT = 65535

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
}
local ABILITY_ORDER: { AbilityKind } = { "Harpoon", "Bomb" }
local COOLDOWNS: { [AbilityKind]: number } = {
	Harpoon = PvpConfig.HARPOON.cooldownSeconds,
	Bomb = PvpConfig.BOMB.cooldownSeconds,
}

local PvpService = {}

local function toVector(v: Vector3): Abilities.Vector
	return { x = v.X, y = v.Y, z = v.Z }
end

local function fromVector(v: Abilities.Vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
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
	local creatures: { Target } = {}
	local usage: { [string]: { used: number, hit: number } } = {}
	local abilityUsed = Signal.new() :: Signal.Signal<Player, AbilityKind, boolean, boolean>
	local harpoonShot = Signal.new() :: Signal.Signal<Shot>
	local bombThrown = Signal.new() :: Signal.Signal<Throw>
	local bombExploded = Signal.new() :: Signal.Signal<Blast>
	local lastBombId = 0

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
		return {
			speed = dependencies.getSpeed(player),
			playSeconds = if data then data.playSeconds else 0,
			isInStation = not isInSpace(character),
			spawnedAt = if state then state.spawnedAt else 0,
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
			if humanoid and not Vitals.isAlive(humanoid) then
				continue
			end
			table.insert(targets, {
				model = character,
				root = root,
				player = other,
				radius = 0,
				refusal = function(attackerSide)
					return Pvp.refusal(attackerSide, sideOf(other, character), time(), PvpConfig.RULES)
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
		for _, creature in creatures do
			table.insert(targets, creature)
		end
		return targets
	end

	-- Where an attack from `from` meets the target: its surface toward `from` (a player is a
	-- point at the root).
	local function contactPoint(target: Target, from: Vector3): Abilities.Vector
		return Abilities.nearestPoint(toVector(target.root.Position), target.radius, toVector(from))
	end

	-- The target in the cone ahead of `root` that `choose` picks (Abilities.nearestInCone or
	-- Abilities.bestInCone), among those passing `filter`.
	local function findInCone(
		root: BasePart,
		direction: Vector3,
		targets: { Target },
		reach: number,
		halfAngle: number,
		filter: (Target) -> boolean,
		choose: typeof(Abilities.nearestInCone)
	): Target?
		local candidates: { { id: number, position: Abilities.Vector } } = {}
		for index, target in targets do
			if filter(target) then
				table.insert(candidates, { id = index, position = contactPoint(target, root.Position) })
			end
		end
		local index = choose(toVector(root.Position), toVector(direction), candidates, reach, halfAngle)
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
			anyone,
			Abilities.nearestInCone
		)
		if not target then
			return
		end
		lunge.touched = true
		local refusal = target.refusal(sideOf(player, character))
		if refusal then
			dependencies.notify(player, refusal)
			count("Strike", false)
			return
		end
		PvpEffects.strikeImpact(root.Position:Lerp(target.root.Position, 0.6))
		resolved(player, "Strike", true, target.onHit(aim, player))
	end

	local function watchLunges()
		for player, state in states do
			watchLunge(player, state)
		end
	end

	-- The harpoon: of the egg carriers in the aim assist's cone, the one nearest the crosshair
	-- that the rules let the shooter attack loses the egg, which flies toward the shooter.
	-- Nothing else happens to the carrier.
	local function harpoon(player: Player, state: PlayerState)
		local character, root, direction = prepare(player, state, "Harpoon")
		if not character or not root or not direction then
			return
		end
		local attacker = sideOf(player, character)
		local targets = targetsFor(player)
		local function find(filter: (Target) -> boolean): Target?
			return findInCone(
				root,
				direction,
				targets,
				PvpConfig.HARPOON.rangeStuds,
				PvpConfig.HARPOON.halfAngleRadians,
				filter,
				Abilities.bestInCone
			)
		end
		local target = find(function(candidate)
			return candidate.isCarrying() and candidate.refusal(attacker) == nil
		end)
		if not target then
			-- Only carriers the rules protect were in the cone: say why, and the harpoon stays.
			local protected = find(function(candidate)
				return candidate.isCarrying()
			end)
			local refusal = if protected then protected.refusal(attacker) else nil
			if refusal then
				dependencies.notify(player, refusal)
				count("Harpoon", false)
				return
			end
			local discount = PvpConfig.HARPOON.cooldownSeconds - PvpConfig.HARPOON.missCooldownSeconds
			state.lastUsedAt.Harpoon = time() - discount
			local reach = root.Position + direction * PvpConfig.HARPOON.rangeStuds
			harpoonShot.fire({ shooter = player, target = reach, aim = direction, hit = false, egg = false })
			resolved(player, "Harpoon", false, false)
			return
		end
		state.lastUsedAt.Harpoon = time()
		local toShooter = root.Position - target.root.Position
		local launch = (if toShooter.Magnitude > 1e-3 then toShooter.Unit else -direction) * EggConfig.DROP_SPEED
		local landing = fromVector(contactPoint(target, root.Position))
		-- The egg is out before the clients hear of the shot, so the hook finds it there.
		local dropped = target.onHarpoon(launch, player)
		harpoonShot.fire({ shooter = player, target = landing, aim = direction, hit = true, egg = dropped })
		resolved(player, "Harpoon", true, dropped)
	end

	-- The bomb goes off: everyone around it is thrown outward and their eggs come loose; the
	-- thrower is spared, and so is anyone the rules protect.
	-- At the blast everyone in its radius is struck; then, while the ring wave grows and holds
	-- (PvpConfig.BOMB_WAVE, drawn the same on every client), so is whoever flies into the ring.
	-- Each target once; the bomb's outcome is counted when the wave is over.
	local function explode(player: Player, character: Model, center: Vector3)
		if character.Parent == nil then
			return
		end
		local attacker = sideOf(player, character)
		local struck: { [Model]: boolean } = {}
		local hit, dropped = false, false
		local function sweep(radius: number)
			local targets: { [Model]: Target } = {}
			local candidates: { { id: Model, position: Abilities.Vector } } = {}
			for _, target in targetsFor(player) do
				targets[target.model] = target
				table.insert(candidates, { id = target.model, position = contactPoint(target, center) })
			end
			for _, model in Abilities.waveStep(toVector(center), candidates, radius, struck) do
				local target = targets[model]
				if target.refusal(attacker) then
					continue
				end
				local away = target.root.Position - center
				local push = if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis
				hit = true
				dropped = target.onHit(push, player) or dropped
			end
		end
		sweep(PvpConfig.BOMB.radiusStuds)
		local elapsed = 0
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			local reach = PvpFx.waveReach(elapsed, PvpConfig.BOMB.radiusStuds, PvpConfig.BOMB_WAVE)
			if reach and character.Parent ~= nil then
				sweep(reach)
				return
			end
			connection:Disconnect()
			resolved(player, "Bomb", hit, dropped)
		end)
	end

	-- The steering for a bomb homing on `target` (Domain/Homing), the target's velocity read from
	-- how it moved (a test dummy is anchored and moved by hand). It flies straight on once the
	-- target is gone or the rules protect it (back under a dome).
	local function steering(target: Target, attacker: Pvp.Side)
		local last = target.root.Position
		local lastVelocity = target.root.AssemblyLinearVelocity
		return function(position: Vector3, velocity: Vector3, deltaTime: number): Vector3
			if target.root.Parent == nil or target.refusal(attacker) then
				return velocity
			end
			local now = target.root.Position
			if deltaTime > 0 then
				lastVelocity = (now - last) / deltaTime
			end
			last = now
			return Homing.steer(
				position,
				velocity,
				now,
				lastVelocity,
				PvpConfig.BOMB.throwSpeed,
				PvpConfig.BOMB.steerAcceleration,
				deltaTime
			)
		end
	end

	-- The bomb leaves ahead of the thrower with their velocity, homes on the target nearest the
	-- crosshair that the rules let them attack, and goes off on reaching anyone or at the end
	-- of its fuse.
	local function bomb(player: Player, state: PlayerState)
		local character, root, direction = prepare(player, state, "Bomb")
		if not character or not root or not direction then
			return
		end
		state.lastUsedAt.Bomb = time()
		local attacker = sideOf(player, character)
		local start = root.Position + direction * PvpConfig.BOMB_START_STUDS
		local homing = findInCone(
			root,
			direction,
			targetsFor(player),
			PvpConfig.BOMB.homingRangeStuds,
			PvpConfig.BOMB.homingHalfAngleRadians,
			function(candidate)
				return candidate.refusal(attacker) == nil
			end,
			Abilities.bestInCone
		)
		-- Goes off early when it reaches someone (protected or not), so a throw at a player lands
		-- on them. Checked along the whole step, against how each target moved over it.
		local seen: { [Model]: Vector3 } = {}
		local function meets(from: Vector3, to: Vector3): Vector3?
			local met: Vector3? = nil
			local soonest = math.huge
			for _, target in targetsFor(player) do
				local now = target.root.Position
				local before = seen[target.model] or now
				seen[target.model] = now
				local distance, share = Homing.closestApproach(from, to, before, now)
				if distance - target.radius <= PvpConfig.BOMB.contactStuds and share < soonest then
					met = from:Lerp(to, share)
					soonest = share
				end
			end
			return met
		end
		lastBombId = lastBombId % BOMB_ID_LIMIT + 1
		local id = lastBombId
		local function onExplode(center: Vector3)
			bombExploded.fire({ id = id, center = center })
			explode(player, character, center)
		end
		local velocity = Homing.launchVelocity(root.AssemblyLinearVelocity, direction, PvpConfig.BOMB.throwSpeed)
		-- At a target faster than the thrower it leaves closing on them at the throw speed all the
		-- same, so a fleeing carrier can be caught by a slower chaser.
		local toTarget = if homing then homing.root.Position - start else nil
		if homing and toTarget and toTarget.Magnitude > 1e-3 then
			velocity = Homing.ensureClosing(
				velocity,
				toTarget.Unit,
				homing.root.AssemblyLinearVelocity,
				PvpConfig.BOMB.throwSpeed
			)
		end
		local fuse = PvpConfig.BOMB.fuseSeconds
		bombThrown.fire({
			id = id,
			thrower = player,
			start = start,
			velocity = velocity,
			fuse = fuse,
			target = if homing then homing.root else nil,
		})
		BombFlight.launch({
			start = start,
			velocity = velocity,
			fuseSeconds = fuse,
			steer = if homing then steering(homing, attacker) else nil,
			meets = meets,
			onExplode = onExplode,
		})
	end

	local ABILITIES: { [AbilityKind]: (Player, PlayerState) -> () } = {
		Harpoon = harpoon,
		Bomb = bomb,
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

	local function addCreature(creature: Creature)
		local target: Target = {
			model = creature.model,
			root = creature.root,
			player = nil,
			radius = creature.radius,
			refusal = Pvp.creatureRefusal,
			isCarrying = creature.isCarrying,
			onHit = creature.onHit,
			onHarpoon = creature.onHarpoon,
		}
		table.insert(creatures, target)
		creature.model.Destroying:Once(function()
			local index = table.find(creatures, target)
			if index then
				table.remove(creatures, index)
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
		addCreature = addCreature,
		getUsage = function()
			return usage
		end,
		abilityUsed = abilityUsed,
		harpoonShot = harpoonShot,
		bombThrown = bombThrown,
		bombExploded = bombExploded,
	}
end

return table.freeze(PvpService)
