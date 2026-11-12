--!strict
-- The star serpent's hunt for its egg, on its event's clock (EventService, SerpentConfig,
-- decision 055). As the hunt is announced a zone past the first is picked at random
-- (SerpentConfig.ZONES) and a spot in the middle of its ring; when it starts the serpent comes
-- out there carrying the star egg, and it is that zone's serpent to the end, wherever it is
-- chased: its speed and its egg's grade are the zone's. What it does follows where the egg is
-- (Domain/SerpentHunt):
--   * egg inside: it winds through the whole guardians' band, past the station border and so
--     never into a dome (Domain/SerpentRoute), slowly while nobody is near, at
--     SerpentConfig.fleeSpeedIn from the nearest player in space; hits on its head (it is a PvP
--     creature) count up, and the last one knocks the egg out (Domain/StarEgg);
--   * egg out: it guards the egg like a guardian (Domain/GuardianBrain): over it while it lies
--     loose, after whoever carries it, at a guardian's chase speed with its stat
--     (Prey.chaseSpeed), throwing them and knocking it out, until they are inside the station
--     border, as a guardian does.
-- The egg's home is the serpent's (Domain/EggHomes, SerpentConfig.EGG_HOME_ID): it gives the
-- egg its grade, takes it back inside when it leaves play, and ends the event when it reaches a
-- bay. When the time is up the serpent leaves: with the egg if it is inside; a loose egg is
-- gone; an egg in hands stays there, and the home lasts until that egg is delivered or lost.
-- The clients follow it through the event's folder (EventService.setDetail) and its pin, which
-- follows the serpent, then the egg (EventService.movePlace).
--
-- The serpent's head is a server-owned physics mover, like a guardian, not predicted on clients;
-- the clients draw its body behind it. Attacks land on its head only (SerpentConfig.HIT_RADIUS):
-- catching up with the head of a fleeing serpent is the challenge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Bounds = require(ReplicatedStorage.Shared.Domain.Bounds)
local CarryService = require(script.Parent.CarryService)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggHomes = require(ReplicatedStorage.Shared.Domain.EggHomes)
local EventClock = require(ReplicatedStorage.Shared.Domain.EventClock)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local EventService = require(script.Parent.EventService)
local GuardianBrain = require(ReplicatedStorage.Shared.Domain.GuardianBrain)
local Knockback = require(script.Parent.Parent.Character.Knockback)
local Prey = require(script.Parent.Parent.Character.Prey)
local Pursuit = require(ReplicatedStorage.Shared.Domain.Pursuit)
local PvpService = require(script.Parent.PvpService)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SerpentHunt = require(ReplicatedStorage.Shared.Domain.SerpentHunt)
local SerpentModel = require(script.Parent.Parent.World.SerpentModel)
local SerpentRoute = require(ReplicatedStorage.Shared.Domain.SerpentRoute)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StarEgg = require(ReplicatedStorage.Shared.Domain.StarEgg)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local CENTER = StationConfig.PLATFORM_CENTER
local HOME_ID = SerpentConfig.EGG_HOME_ID
-- Where its route winds.
local BAND: SerpentRoute.Band = {
	center = CENTER,
	up = Vector3.yAxis,
	across = Vector3.xAxis,
	inner = SerpentConfig.INNER_RADIUS,
	outer = SerpentConfig.OUTER_RADIUS,
	height = SerpentConfig.ROUTE_HEIGHT,
}

export type Dependencies = {
	eventChanged: Signal.Signal<EventConfig.EventId, EventClock.Phase>,
	placeOf: (id: EventConfig.EventId) -> EventService.Place?,
	setPlacer: (id: EventConfig.EventId, placer: EventService.Placer) -> (),
	movePlace: (id: EventConfig.EventId, position: Vector3) -> (),
	setFollow: (id: EventConfig.EventId, part: BasePart?) -> (),
	setDetail: (id: EventConfig.EventId, name: string, value: string | number | boolean | nil) -> (),
	stopEvent: (id: EventConfig.EventId) -> (),
	homes: EggHomes.EggHomes,
	getCarried: (player: Player) -> CarryService.Carried?,
	findCarriers: (homeId: string) -> { Player },
	findLooseEggs: (homeId: string) -> { Vector3 },
	dropEgg: (player: Player, launch: Vector3?, reason: CarryService.LossReason?) -> boolean,
	spawnLooseEgg: (egg: CarryService.Egg, position: Vector3, launch: Vector3?) -> (),
	removeLooseEggs: (homeId: string) -> (),
	-- Brings the star egg home: the serpent's job is done.
	eggDelivered: Signal.Signal<Player, CarryService.Carried>,
	getSpeed: (player: Player) -> BigNum.BigNum,
	addCreature: (creature: PvpService.Creature) -> (),
	scheduler: Scheduler.Scheduler,
}

export type SerpentService = {
	name: string,
	start: () -> (),
	-- Hits on the serpent while the egg is inside, as if a player landed them (Studio command).
	-- Returns false when the serpent is not out or its egg is not inside.
	hit: (player: Player, direction: Vector3) -> boolean,
	-- Holds the serpent still at `position`, facing `facing` (Studio command: try the attacks on
	-- it); nil lets it go. Returns false when it is not out.
	hold: (position: Vector3?, facing: Vector3?) -> boolean,
	-- A player's attack landed on the serpent; true if it knocked the egg out.
	struck: Signal.Signal<Player, boolean>,
	-- It caught a player carrying its egg.
	caught: Signal.Signal<Player>,
	-- The star egg reached a bay.
	delivered: Signal.Signal<Player, CarryService.Carried>,
	-- The hunt's time ran out (not after a delivery): what became of the egg.
	ended: Signal.Signal<SerpentHunt.Ending>,
}

-- The serpent while it is out.
type Serpent = {
	model: Model,
	head: BasePart,
	velocity: LinearVelocity,
	align: AlignOrientation,
	-- The zone it came out in: its speed and its egg's grade, for the hunt.
	zone: ZoneConfig.ZoneId,
	-- Its winding route while it carries the egg (nil while it guards it), and where it flies.
	route: SerpentRoute.Route?,
	heading: Vector3,
	sincePin: number,
	-- Guarding the egg once it is out, like a guardian.
	brain: GuardianBrain.State,
	target: Player?,
	stolenSeconds: number,
	catchReadyAt: number,
	-- Where it keeps watch: over the egg where it last lay.
	watch: Vector3,
	-- Held still by a Studio command (`hold`).
	held: boolean,
}

local SerpentService = {}

-- A point at `radius` from the station at a random angle, within `height` above or below it.
local function aroundStation(random: Random, radius: number, height: number): Vector3
	local angle = random:NextNumber() * math.pi * 2
	local lift = random:NextNumber(-height, height)
	return CENTER + Vector3.new(math.cos(angle) * radius, lift, math.sin(angle) * radius)
end

local function distanceFromStation(position: Vector3): number
	return (position - CENTER).Magnitude
end

-- The serpent's zone for an event place: the place's zone if the serpent comes out there, the
-- nearest such zone if not (the Debris Belt, from a Studio start), the first one without a zone.
local function zoneOf(place: EventService.Place?): ZoneConfig.ZoneId
	local zones = SerpentConfig.ZONES
	local zone = if place then place.zone else nil
	if zone and table.find(zones, zone) then
		return zone
	end
	return zones[1]
end

-- A point in the middle of `zone`'s ring, at a random angle, level with the station.
local function inZoneMiddle(random: Random, zone: ZoneConfig.ZoneId): Vector3
	local ring = ZoneConfig.ZONES[zone]
	return aroundStation(random, (ring.ringMin + ring.ringMax) / 2, 0)
end

-- Out of its reach, as out of a guardian's: on the station, or inside its border.
local function isOutOfReach(character: Model, root: BasePart): boolean
	return not Prey.inSpace(character) or distanceFromStation(root.Position) <= StationConfig.BORDER_RADIUS
end

function SerpentService.new(dependencies: Dependencies): SerpentService
	local random = Random.new()
	local function roll(): number
		return random:NextNumber()
	end
	local struck = Signal.new() :: Signal.Signal<Player, boolean>
	local caught = Signal.new() :: Signal.Signal<Player>
	local delivered = Signal.new() :: Signal.Signal<Player, CarryService.Carried>
	local ended = Signal.new() :: Signal.Signal<SerpentHunt.Ending>

	local serpent: Serpent? = nil
	local hunt = SerpentHunt.start()
	-- The star egg out of the serpent (rolled as it is knocked out), nil while inside.
	local starEgg: StarEgg.Egg? = nil
	-- The egg's home is registered from the serpent's coming out until its egg is done with:
	-- delivered, gone, or taken away; past the hunt while a player still holds it or it lies
	-- unguarded for a while.
	local homeOpen = false
	-- Hunts so far, to tell a late callback of an old hunt from the current one.
	local huntCount = 0

	local function publish(by: Player?)
		if by then
			-- Before the egg's place, so the clients' announcement of the change names them.
			dependencies.setDetail("Serpent", SerpentConfig.EGG_BY_ATTRIBUTE, by.DisplayName)
		end
		dependencies.setDetail("Serpent", SerpentConfig.HITS_ATTRIBUTE, hunt.hits)
		dependencies.setDetail("Serpent", SerpentConfig.EGG_ATTRIBUTE, hunt.egg)
	end

	local function closeHome()
		if homeOpen then
			homeOpen = false
			dependencies.homes.unregister(HOME_ID)
		end
		starEgg = nil
	end

	-- Steers towards `velocity`, eased from the last tick's (SerpentConfig.STEER_RESPONSE): each
	-- tick's aim (fleeing the nearest player, sliding along its bounds) can turn sharply, and a
	-- long body snapping to it jerks.
	local function steer(current: Serpent, velocity: Vector3)
		local position = current.head.Position
		local eased = Pursuit.ease(
			current.velocity.VectorVelocity,
			velocity,
			SerpentConfig.STEER_RESPONSE,
			SerpentConfig.TICK_SECONDS
		)
		local inside = Bounds.keepOutside(position, eased, CENTER, SerpentConfig.INNER_RADIUS)
		local limited = Bounds.limitVelocity(position, inside, CENTER, SerpentConfig.OUTER_RADIUS)
		current.velocity.VectorVelocity = limited
		if limited.Magnitude > 1 then
			current.align.CFrame = CFrame.lookAlong(Vector3.zero, limited.Unit)
		end
	end

	-- The nearest player out in space within its flee radius, if any.
	local function nearestThreat(current: Serpent): BasePart?
		local nearest: BasePart? = nil
		local nearestDistance = SerpentConfig.FLEE_RADIUS
		for _, player in Players:GetPlayers() do
			local character, root = Prey.root(player)
			if character and root and Prey.inSpace(character) then
				local distance = (root.Position - current.head.Position).Magnitude
				if distance <= nearestDistance then
					nearest, nearestDistance = root, distance
				end
			end
		end
		return nearest
	end

	-- Carrying the egg: along its winding route, faster while someone is near.
	local function flee(current: Serpent, deltaTime: number)
		local position = current.head.Position
		local threat = nearestThreat(current)
		local speed = if threat then SerpentConfig.fleeSpeedIn(current.zone) else SerpentConfig.ROAM_SPEED
		local route: SerpentRoute.Route
		if current.route then
			route = current.route
		else
			-- Back on the route (just out, or its egg back inside): from where it flies now.
			local moving = current.velocity.VectorVelocity
			current.heading = if moving.Magnitude > 1 then moving.Unit else current.head.CFrame.LookVector
			route = SerpentRoute.start(BAND, SerpentConfig.ROUTE, position, roll)
		end
		local heading
		route, heading = SerpentRoute.step(
			route,
			BAND,
			SerpentConfig.ROUTE,
			position,
			current.heading,
			speed,
			deltaTime,
			roll,
			if threat then threat.Position else nil
		)
		current.route, current.heading = route, heading
		steer(current, heading * speed)
	end

	local function catchThief(current: Serpent, player: Player, character: Model, root: BasePart)
		local strike = Prey.strike(current.head.Position, root)
		if not dependencies.dropEgg(player, strike.eggLaunch, "Serpent") then
			return
		end
		Knockback.apply(
			character,
			strike.direction * SerpentConfig.KNOCKBACK_SPEED,
			strike.sideways,
			SerpentConfig.STUN_SECONDS,
			SerpentConfig.HIT_BY
		)
		current.catchReadyAt = time() + SerpentConfig.CATCH_COOLDOWN_SECONDS
		caught.fire(player)
	end

	-- Its egg is out: a guardian's watch over it (GuardianService does the same for nests).
	local function guard(current: Serpent, deltaTime: number)
		local candidates: { GuardianBrain.Candidate<Player> } = {}
		for _, player in dependencies.findCarriers(HOME_ID) do
			local character, root = Prey.root(player)
			if character and root then
				table.insert(candidates, {
					who = player,
					distance = (root.Position - current.head.Position).Magnitude,
					safe = isOutOfReach(character, root),
				})
			end
		end
		current.target = GuardianBrain.pickTarget(current.target, candidates)
		local carrier = current.target
		local character: Model?, root: BasePart? = nil, nil
		if carrier then
			character, root = Prey.root(carrier)
		else
			-- Nobody carries it: watch over where it lies (the nearest, should there be more).
			local nearestDistance = math.huge
			for _, position in dependencies.findLooseEggs(HOME_ID) do
				local distance = (position - current.head.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					current.watch = position + Vector3.yAxis * SerpentConfig.HOVER_HEIGHT
				end
			end
		end
		current.stolenSeconds = if root then current.stolenSeconds + deltaTime else 0

		local position = current.head.Position
		current.brain = GuardianBrain.next(current.brain, {
			hasTarget = root ~= nil,
			stolenSeconds = current.stolenSeconds,
			targetSafe = character ~= nil and root ~= nil and isOutOfReach(character, root),
			distanceToHome = (position - current.watch).Magnitude,
		}, SerpentConfig.BRAIN)

		if current.brain == "Chase" and carrier and character and root then
			local power = SerpentConfig.powerIn(current.zone)
			local speed =
				Prey.chaseSpeed(character, dependencies.getSpeed(carrier), dependencies.getCarried(carrier), power)
			local goal = Pursuit.interceptPoint(
				position,
				root.Position,
				root.AssemblyLinearVelocity,
				speed,
				SerpentConfig.MAX_LEAD_SECONDS
			)
			steer(current, Pursuit.seekVelocity(position, goal, speed, 0))
			local distance = (root.Position - position).Magnitude
			local ready = time() >= current.catchReadyAt
			if ready and GuardianBrain.canCatch(current.brain, distance, SerpentConfig.BRAIN) then
				catchThief(current, carrier, character, root)
			end
		else
			local speed = SerpentConfig.fleeSpeedIn(current.zone)
			steer(current, Pursuit.settleVelocity(position, current.watch, speed, SerpentConfig.SETTLE_SECONDS))
		end
	end

	-- Where its pin points: at the serpent while the egg is inside, at the egg once it is out
	-- (in a player's hands, or lying loose); and the moving part there, which clients follow
	-- every frame (nil for an egg lying loose: it barely moves).
	local function pinTarget(current: Serpent): (Vector3, BasePart?)
		if hunt.egg == "Out" then
			for _, player in dependencies.findCarriers(HOME_ID) do
				local _, root = Prey.root(player)
				if root then
					return root.Position, root
				end
			end
			local loose = dependencies.findLooseEggs(HOME_ID)[1]
			if loose then
				return loose, nil
			end
		end
		return current.head.Position, current.head
	end

	local function tick(deltaTime: number)
		local current = serpent
		if not current then
			return
		end
		local behavior = SerpentHunt.behavior(hunt)
		if current.held then
			current.velocity.VectorVelocity = Vector3.zero
		elseif behavior == "Flee" then
			flee(current, deltaTime)
		elseif behavior == "Guard" then
			current.route = nil
			guard(current, deltaTime)
		end

		current.sincePin += deltaTime
		if current.sincePin >= SerpentConfig.PIN_SECONDS then
			current.sincePin = 0
			local position, part = pinTarget(current)
			dependencies.movePlace("Serpent", position)
			dependencies.setFollow("Serpent", part)
		end
	end

	-- A hit on its head by `player`: counts while the egg is inside; the last one knocks it out,
	-- flying off along `launch`.
	local function takeHit(player: Player, launch: Vector3): boolean
		local current = serpent
		if not current or hunt.egg ~= "Inside" then
			return false
		end
		local knocked
		hunt, knocked = SerpentHunt.hit(hunt, SerpentConfig.HITS_TO_DROP)
		current.head:SetAttribute(SerpentConfig.LAST_HIT_ATTRIBUTE, workspace:GetServerTimeNow())
		if knocked then
			local position = current.head.Position
			local egg = StarEgg.roll(current.zone, random:NextNumber(), random:NextNumber())
			starEgg = egg
			dependencies.spawnLooseEgg({
				rarity = egg.rarity,
				size = egg.size,
				nestId = HOME_ID,
				variant = "Normal",
				luck = egg.luck,
			}, position, launch)
			-- It turns to guard the egg from where it is.
			current.brain = "Return"
			current.target = nil
			current.stolenSeconds = 0
			current.watch = position
		end
		publish(if knocked then player else nil)
		struck.fire(player, knocked)
		return knocked
	end

	local function comeOut()
		if serpent then
			return
		end
		-- A star egg still about from the last hunt is no longer the serpent's: one lying loose
		-- goes, one in hands stays a star egg nobody guards.
		dependencies.removeLooseEggs(HOME_ID)
		closeHome()
		huntCount += 1
		hunt = SerpentHunt.start()
		-- Its zone and spot were picked as the hunt was announced (a Studio start may name any
		-- zone: one it does not come out in counts as the nearest it does).
		local place = dependencies.placeOf("Serpent")
		local zone = zoneOf(place)
		local at = if place and place.zone == zone then place.position else inZoneMiddle(random, zone)
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
			zone = zone,
			route = nil,
			heading = head.CFrame.LookVector,
			sincePin = 0,
			brain = "Return",
			target = nil,
			stolenSeconds = 0,
			catchReadyAt = 0,
			watch = at,
			held = false,
		}

		homeOpen = true
		dependencies.homes.register(HOME_ID, {
			grade = function(): number?
				return if starEgg then starEgg.grade else nil
			end,
			-- Left play undelivered: back inside the serpent while it is out, else gone.
			returnEgg = function()
				if serpent then
					hunt = SerpentHunt.returned(hunt)
					starEgg = nil
					publish(nil)
				else
					closeHome()
				end
			end,
			delivered = function()
				hunt = SerpentHunt.delivered(hunt)
			end,
		})
		dependencies.addCreature({
			model = model,
			root = head,
			radius = SerpentConfig.HIT_RADIUS,
			isCarrying = function()
				return hunt.egg == "Inside"
			end,
			onHit = function(direction, attacker)
				return takeHit(attacker, direction * EggConfig.DROP_SPEED)
			end,
			onHarpoon = function(launch, attacker)
				return takeHit(attacker, launch)
			end,
		})
		dependencies.setDetail("Serpent", SerpentConfig.ENDING_ATTRIBUTE, nil)
		dependencies.setDetail("Serpent", SerpentConfig.EGG_BY_ATTRIBUTE, nil)
		publish(nil)
	end

	local function goAway()
		local current = serpent
		if not current then
			return
		end
		serpent = nil
		current.model:Destroy()
		if hunt.egg == "Delivered" then
			return
		end
		local ending = SerpentHunt.ending(hunt, #dependencies.findCarriers(HOME_ID) > 0)
		dependencies.setDetail("Serpent", SerpentConfig.ENDING_ATTRIBUTE, ending)
		if ending == "TookEgg" then
			closeHome()
		elseif ending == "EggLeft" then
			-- Unguarded for a little while; then gone, unless someone has it in hands by then (or
			-- the next hunt has begun).
			local thisHunt = huntCount
			task.delay(SerpentConfig.STAR_EGG_LINGER_SECONDS, function()
				if huntCount == thisHunt and homeOpen and #dependencies.findCarriers(HOME_ID) == 0 then
					dependencies.removeLooseEggs(HOME_ID)
					closeHome()
				end
			end)
		end
		ended.fire(ending)
	end

	local function onDelivered(player: Player, egg: CarryService.Carried)
		if egg.nestId ~= HOME_ID then
			return
		end
		closeHome()
		delivered.fire(player, egg)
		if serpent then
			publish(player)
			dependencies.stopEvent("Serpent")
		end
	end

	local function start()
		-- One zone past the first at random, named in the announcement.
		dependencies.setPlacer("Serpent", function(): EventService.Place?
			local zones = SerpentConfig.ZONES
			local zone = zones[random:NextInteger(1, #zones)]
			return { zone = zone, position = inZoneMiddle(random, zone) }
		end)
		dependencies.eventChanged.connect(function(id, phase)
			if id ~= "Serpent" then
				return
			end
			if phase == "Active" then
				comeOut()
			elseif phase == "Idle" then
				goAway()
			end
		end)
		dependencies.eggDelivered.connect(onDelivered)
		dependencies.scheduler.every(SerpentConfig.TICK_SECONDS, tick)
		Players.PlayerRemoving:Connect(function(player)
			if serpent and serpent.target == player then
				serpent.target = nil
			end
		end)
	end

	return {
		name = "SerpentService",
		start = start,
		hit = function(player: Player, direction: Vector3): boolean
			if not serpent or hunt.egg ~= "Inside" then
				return false
			end
			takeHit(player, direction * EggConfig.DROP_SPEED)
			return true
		end,
		hold = function(position: Vector3?, facing: Vector3?): boolean
			local current = serpent
			if not current then
				return false
			end
			current.held = position ~= nil
			if position then
				local look = if facing and facing.Magnitude > 1e-3 then position + facing else CENTER
				current.model:PivotTo(CFrame.lookAt(position, look))
				current.velocity.VectorVelocity = Vector3.zero
			end
			return true
		end,
		struck = struck,
		caught = caught,
		delivered = delivered,
		ended = ended,
	}
end

return table.freeze(SerpentService)
