--!strict
-- The star serpent's hunt, on its event's clock (EventService, SerpentConfig). As the hunt is
-- announced, a spot in the Event Horizon is picked; when it starts the serpent comes out there
-- and goes after everyone out in space past the first zone: the same one until it is caught or
-- gets away (Domain/GuardianBrain.pickTarget), as fast as a guardian with the speed stat of the
-- middle guardian of that player's zone would be (SerpentConfig.powerAt, Prey.chaseSpeed). A catch is a guardian's: the player is thrown and the egg knocked out; then the
-- serpent leaves them alone for a while. With nobody to hunt it roams. Its pin follows it
-- (EventService.movePlace). Eggs delivered while it hunts hatch luckier (`deliveryLuck`).
--
-- The serpent's head is a server-owned physics mover, like a guardian, not predicted on clients;
-- the clients draw its body behind it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Bounds = require(ReplicatedStorage.Shared.Domain.Bounds)
local CarryService = require(script.Parent.CarryService)
local EventClock = require(ReplicatedStorage.Shared.Domain.EventClock)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local EventService = require(script.Parent.EventService)
local GuardianBrain = require(ReplicatedStorage.Shared.Domain.GuardianBrain)
local Knockback = require(script.Parent.Parent.Character.Knockback)
local Prey = require(script.Parent.Parent.Character.Prey)
local Pursuit = require(ReplicatedStorage.Shared.Domain.Pursuit)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SerpentModel = require(script.Parent.Parent.World.SerpentModel)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local CENTER = StationConfig.PLATFORM_CENTER
-- A roaming serpent picks its next spot once it is this close to the last one, studs.
local ROAM_ARRIVE_RADIUS = 30
-- Roams between the first zone past its hunting line and the last zone's outer edge.
local ROAM_MIN_RADIUS = ZoneConfig.ZONES.IceRings.ringMin
local ROAM_MAX_RADIUS = ZoneConfig.ZONES.EventHorizon.ringMax
local ROAM_HEIGHT = ZoneConfig.ZONES.EventHorizon.heightSpread

export type Dependencies = {
	eventChanged: Signal.Signal<EventConfig.EventId, EventClock.Phase>,
	placeOf: (id: EventConfig.EventId) -> EventService.Place?,
	setPlacer: (id: EventConfig.EventId, placer: EventService.Placer) -> (),
	movePlace: (id: EventConfig.EventId, position: Vector3) -> (),
	getCarried: (player: Player) -> CarryService.Carried?,
	dropEgg: (player: Player, launch: Vector3?, reason: CarryService.LossReason?) -> boolean,
	getSpeed: (player: Player) -> BigNum.BigNum,
	scheduler: Scheduler.Scheduler,
}

export type SerpentService = {
	name: string,
	start: () -> (),
	-- Extra luck for an egg delivered right now: SerpentConfig.EGG_LUCK while it hunts, else 0.
	deliveryLuck: () -> number,
	-- It caught a player; true if that knocked an egg out of their hands.
	caught: Signal.Signal<Player, boolean>,
}

-- The serpent while it is out.
type Serpent = {
	model: Model,
	head: BasePart,
	velocity: LinearVelocity,
	align: AlignOrientation,
	target: Player?,
	-- Players it caught, left alone until this time().
	spared: { [Player]: number },
	roamGoal: Vector3?,
	sincePin: number,
}

local SerpentService = {}

-- A point at `radius` from the station at a random angle, within `height` above or below it.
local function aroundStation(random: Random, radius: number, height: number): Vector3
	local angle = random:NextNumber() * math.pi * 2
	local lift = random:NextNumber(-height, height)
	return CENTER + Vector3.new(math.cos(angle) * radius, lift, math.sin(angle) * radius)
end

-- Out of its reach: on the station, or within the first zone.
local function isOutOfReach(character: Model, root: BasePart): boolean
	return not Prey.inSpace(character) or (root.Position - CENTER).Magnitude <= SerpentConfig.HUNT_RADIUS
end

function SerpentService.new(dependencies: Dependencies): SerpentService
	local random = Random.new()
	local caught = Signal.new() :: Signal.Signal<Player, boolean>
	local serpent: Serpent? = nil
	local hunting = false

	local function pickPlace(): EventService.Place?
		return { zone = "EventHorizon", position = aroundStation(random, SerpentConfig.SPAWN_RADIUS, 0) }
	end

	local function steer(current: Serpent, velocity: Vector3)
		local limited = Bounds.keepOutside(current.head.Position, velocity, CENTER, SerpentConfig.HUNT_RADIUS)
		current.velocity.VectorVelocity = limited
		if limited.Magnitude > 1 then
			current.align.CFrame = CFrame.lookAlong(Vector3.zero, limited.Unit)
		end
	end

	-- Whom it goes after: players out in space past the first zone that it has not just caught.
	local function chooseTarget(current: Serpent): Player?
		local now = time()
		local candidates: { GuardianBrain.Candidate<Player> } = {}
		for _, player in Players:GetPlayers() do
			local character, root = Prey.root(player)
			local sparedUntil = current.spared[player]
			if character and root and not isOutOfReach(character, root) and not (sparedUntil and now < sparedUntil) then
				table.insert(candidates, {
					who = player,
					distance = (root.Position - current.head.Position).Magnitude,
					safe = false,
				})
			end
		end
		current.target = GuardianBrain.pickTarget(current.target, candidates)
		return current.target
	end

	local function catch(current: Serpent, player: Player, character: Model, root: BasePart)
		local strike = Prey.strike(current.head.Position, root)
		local dropped = dependencies.dropEgg(player, strike.eggLaunch, "Serpent")
		Knockback.apply(
			character,
			strike.direction * SerpentConfig.KNOCKBACK_SPEED,
			strike.sideways,
			SerpentConfig.STUN_SECONDS,
			SerpentConfig.HIT_BY
		)
		current.spared[player] = time() + SerpentConfig.SPARE_SECONDS
		current.target = nil
		caught.fire(player, dropped)
	end

	-- Where a roaming serpent heads: the same spot until it gets there, then a new one.
	local function roamGoal(current: Serpent): Vector3
		local goal = current.roamGoal
		if goal and (goal - current.head.Position).Magnitude > ROAM_ARRIVE_RADIUS then
			return goal
		end
		local fresh = aroundStation(random, random:NextNumber(ROAM_MIN_RADIUS, ROAM_MAX_RADIUS), ROAM_HEIGHT)
		current.roamGoal = fresh
		return fresh
	end

	local function roam(current: Serpent)
		local goal = roamGoal(current)
		steer(current, Pursuit.seekVelocity(current.head.Position, goal, SerpentConfig.ROAM_SPEED, ROAM_ARRIVE_RADIUS))
	end

	local function tick(deltaTime: number)
		local current = serpent
		if not current then
			return
		end
		local prey = chooseTarget(current)
		local character: Model?, root: BasePart? = nil, nil
		if prey then
			character, root = Prey.root(prey)
		end
		if prey and character and root then
			local position = current.head.Position
			local power = SerpentConfig.powerAt((root.Position - CENTER).Magnitude)
			local speed = Prey.chaseSpeed(character, dependencies.getSpeed(prey), dependencies.getCarried(prey), power)
			local goal = Pursuit.interceptPoint(
				position,
				root.Position,
				root.AssemblyLinearVelocity,
				speed,
				SerpentConfig.MAX_LEAD_SECONDS
			)
			steer(current, Pursuit.seekVelocity(position, goal, speed, 0))
			if (root.Position - position).Magnitude <= SerpentConfig.CATCH_RADIUS then
				catch(current, prey, character, root)
			end
		else
			roam(current)
		end

		current.sincePin += deltaTime
		if current.sincePin >= SerpentConfig.PIN_SECONDS then
			current.sincePin = 0
			dependencies.movePlace("Serpent", current.head.Position)
		end
	end

	local function comeOut()
		if serpent then
			return
		end
		local place = dependencies.placeOf("Serpent")
		local at = if place then place.position else aroundStation(random, SerpentConfig.SPAWN_RADIUS, 0)
		local model = SerpentModel.build()
		model:PivotTo(CFrame.lookAt(at, CENTER))
		model.Parent = workspace:FindFirstChild("World") or workspace
		-- Under Server Authority the server simulates it; clients only see the motion.
		RunService:SetPredictionMode(model, Enum.PredictionMode.Off)
		local head = model.PrimaryPart :: BasePart
		serpent = {
			model = model,
			head = head,
			velocity = head:FindFirstChild(SerpentConfig.VELOCITY_NAME) :: LinearVelocity,
			align = head:FindFirstChild(SerpentConfig.ALIGN_NAME) :: AlignOrientation,
			target = nil,
			spared = {},
			roamGoal = nil,
			sincePin = 0,
		}
	end

	local function goAway()
		local current = serpent
		serpent = nil
		if current then
			current.model:Destroy()
		end
	end

	local function start()
		dependencies.setPlacer("Serpent", pickPlace)
		dependencies.eventChanged.connect(function(id, phase)
			if id ~= "Serpent" then
				return
			end
			hunting = phase == "Active"
			if hunting then
				comeOut()
			elseif phase == "Idle" then
				goAway()
			end
		end)
		dependencies.scheduler.every(SerpentConfig.TICK_SECONDS, tick)
		Players.PlayerRemoving:Connect(function(player)
			if serpent then
				serpent.spared[player] = nil
				if serpent.target == player then
					serpent.target = nil
				end
			end
		end)
	end

	return {
		name = "SerpentService",
		start = start,
		deliveryLuck = function(): number
			return if hunting then SerpentConfig.EGG_LUCK else 0
		end,
		caught = caught,
	}
end

return table.freeze(SerpentService)
