--!strict
-- The guardians: one per nest, asleep until its egg is carried off, then a straight chase after
-- the thief. Server-owned physics movers without a Humanoid, not predicted on clients; the logic
-- ticks at 15 Hz through the shared Scheduler. A catch is a distance check on the server; the
-- knockback is handed to the simulation through character attributes so both sides apply it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Bounds = require(ReplicatedStorage.Shared.Domain.Bounds)
local CarryService = require(script.Parent.CarryService)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local GuardianBrain = require(ReplicatedStorage.Shared.Domain.GuardianBrain)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local GuardianModel = require(script.Parent.Parent.World.GuardianModel)
local Knockback = require(script.Parent.Parent.Character.Knockback)
local Prey = require(script.Parent.Parent.Character.Prey)
local Pursuit = require(ReplicatedStorage.Shared.Domain.Pursuit)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local TopSpeed = require(ReplicatedStorage.Shared.Simulation.TopSpeed)
local WorldService = require(script.Parent.WorldService)

local FOLDER_NAME = "Guardians"

export type Dependencies = {
	getNestSites: () -> { WorldService.NestSite },
	-- The post of a nest (NestService ranks nests by distance).
	getNestGrade: (nestId: string) -> number?,
	-- Nests that come and go (meteor craters): each gets a guardian of its post while it lasts.
	nestAdded: Signal.Signal<WorldService.NestSite>,
	nestRemoved: Signal.Signal<string>,
	findCarriers: (nestId: string) -> { Player },
	-- Where the eggs of `nestId` lie knocked out (empty while the egg is in the nest or carried).
	findLooseEggs: (nestId: string) -> { Vector3 },
	getCarried: (player: Player) -> CarryService.Carried?,
	dropEgg: (player: Player, launch: Vector3?, reason: CarryService.LossReason?) -> boolean,
	getSpeed: (player: Player) -> BigNum.BigNum,
	scheduler: Scheduler.Scheduler,
}

export type GuardianService = {
	name: string,
	start: () -> (),
}

type Guardian = {
	nestId: string,
	post: GuardianConfig.Post,
	model: Model,
	body: BasePart,
	velocity: LinearVelocity,
	align: AlignOrientation,
	-- Over the nest.
	nestHome: Vector3,
	-- Where the guardian keeps watch: over its egg, wherever it lies (see followEgg).
	home: Vector3,
	-- Flight speed on the way home and while settling, studs per second.
	cruiseSpeed: number,
	state: GuardianBrain.State,
	-- The thief it goes after, while someone carries one of its eggs.
	target: Player?,
	stolenSeconds: number,
	catchReadyAt: number,
}

local GuardianService = {}

function GuardianService.new(dependencies: Dependencies): GuardianService
	local guardians: { Guardian } = {}

	local function carriedWeight(player: Player): number
		local carried = dependencies.getCarried(player)
		if not carried then
			return 0
		end
		return Speed.eggWeight(EggConfig.RARITIES[carried.rarity].weight, EggConfig.SIZES[carried.size].weightFactor)
	end

	-- How fast this guardian flies after this thief right now (see Speed.chaseSpeed).
	local function chaseSpeedFor(guardian: Guardian, player: Player, character: Model): number
		-- The thief's actual top speed (slow mode included), so the chase feels the same either way.
		local flightSpeed = TopSpeed.of(character)
		local weight = carriedWeight(player)
		local thiefFlightSpeed = flightSpeed * Speed.carryMultiplier(weight)
		local thiefSpeedWithEgg = Speed.withEgg(dependencies.getSpeed(player), weight)
		return Speed.chaseSpeed(thiefFlightSpeed, guardian.post.speed, thiefSpeedWithEgg, SpeedConfig.CHASE)
	end

	local function move(guardian: Guardian, velocity: Vector3)
		local station = StationConfig.STATION
		local limited = Bounds.keepOutside(
			guardian.body.Position,
			velocity,
			station.domeCenter,
			StationConfig.BORDER_RADIUS + GuardianConfig.BORDER_MARGIN
		)
		guardian.velocity.VectorVelocity = limited
		if limited.Magnitude > 1 then
			guardian.align.CFrame = CFrame.lookAlong(Vector3.zero, limited.Unit)
		end
	end

	-- The strike: the thief is thrown and tumbles, the egg flies off sideways, the guardian lunges.
	local function catchThief(guardian: Guardian, player: Player, character: Model, root: BasePart)
		local strike = Prey.strike(guardian.body.Position, root)
		if not dependencies.dropEgg(player, strike.eggLaunch, "Guardian") then
			return
		end

		Knockback.apply(
			character,
			strike.direction * GuardianConfig.KNOCKBACK_SPEED,
			strike.sideways,
			GuardianConfig.STUN_SECONDS,
			GuardianConfig.HIT_BY_GUARDIAN
		)

		guardian.velocity.VectorVelocity = strike.direction * GuardianConfig.LUNGE_SPEED
		guardian.model:SetAttribute(GuardianConfig.LAST_CATCH_ATTRIBUTE, time())
		guardian.catchReadyAt = time() + GuardianConfig.CATCH_COOLDOWN_SECONDS
	end

	local function setState(guardian: Guardian, state: GuardianBrain.State)
		if guardian.state == state then
			return
		end
		guardian.state = state
		guardian.model:SetAttribute(GuardianConfig.STATE_ATTRIBUTE, state)
	end

	-- Guardians never cross the station border, so an egg lying inside it is out of their hands.
	local function isOutOfReach(position: Vector3): boolean
		local station = StationConfig.STATION
		local reach = StationConfig.BORDER_RADIUS + GuardianConfig.BORDER_MARGIN
		return (position - station.domeCenter).Magnitude <= reach
	end

	-- The station border is where every chase ends: a thief inside it, or on the platform, is safe.
	local function isThiefSafe(character: Model, root: BasePart): boolean
		local station = StationConfig.STATION
		return not Prey.inSpace(character)
			or (root.Position - station.domeCenter).Magnitude <= StationConfig.BORDER_RADIUS
	end

	-- A guardian guards its egg, not a spot: knocked out of a thief's hands, the egg lies where
	-- it fell and the guardian settles over it, so taking it again is the same deal as taking it
	-- from the nest. While an egg is carried the watch point stays where the egg last lay, even
	-- with more of its eggs lying about (a meteor shower): the guardian does not turn away to
	-- them while a thief gets off. Once its egg is back in the nest, so is the guardian.
	-- With several loose eggs and nobody carrying, the nearest is watched.
	local function followEgg(guardian: Guardian, carrier: Player?)
		if carrier then
			return
		end
		local nearest: Vector3? = nil
		local nearestDistance = math.huge
		for _, position in dependencies.findLooseEggs(guardian.nestId) do
			local distance = (position - guardian.body.Position).Magnitude
			if distance < nearestDistance and not isOutOfReach(position) then
				nearest, nearestDistance = position, distance
			end
		end
		guardian.home = if nearest then nearest + Vector3.yAxis * GuardianConfig.HOVER_HEIGHT else guardian.nestHome
	end

	-- Whom the guardian goes after among the thieves carrying its eggs: the same one until it is
	-- caught or safe, then the nearest (Domain/GuardianBrain.pickTarget).
	local function chooseTarget(guardian: Guardian): Player?
		local candidates: { GuardianBrain.Candidate<Player> } = {}
		for _, player in dependencies.findCarriers(guardian.nestId) do
			local character, root = Prey.root(player)
			if character and root then
				table.insert(candidates, {
					who = player,
					distance = (root.Position - guardian.body.Position).Magnitude,
					safe = isThiefSafe(character, root),
				})
			end
		end
		guardian.target = GuardianBrain.pickTarget(guardian.target, candidates)
		return guardian.target
	end

	local function tickGuardian(guardian: Guardian, deltaTime: number)
		local carrier = chooseTarget(guardian)
		local character: Model?, root: BasePart? = nil, nil
		if carrier then
			character, root = Prey.root(carrier)
		end
		followEgg(guardian, carrier)
		guardian.stolenSeconds = if root then guardian.stolenSeconds + deltaTime else 0

		local situation: GuardianBrain.Situation = {
			hasTarget = root ~= nil,
			stolenSeconds = guardian.stolenSeconds,
			targetSafe = character ~= nil and root ~= nil and isThiefSafe(character, root),
			distanceToHome = (guardian.body.Position - guardian.home).Magnitude,
		}
		setState(guardian, GuardianBrain.next(guardian.state, situation, GuardianConfig.BRAIN))

		if guardian.state == "Chase" and carrier and character and root then
			local speed = chaseSpeedFor(guardian, carrier, character)
			local goal = Pursuit.interceptPoint(
				guardian.body.Position,
				root.Position,
				root.AssemblyLinearVelocity,
				speed,
				GuardianConfig.MAX_LEAD_SECONDS
			)
			move(guardian, Pursuit.seekVelocity(guardian.body.Position, goal, speed, 0))

			local distance = (root.Position - guardian.body.Position).Magnitude
			if
				time() >= guardian.catchReadyAt
				and GuardianBrain.canCatch(guardian.state, distance, GuardianConfig.BRAIN)
			then
				catchThief(guardian, carrier, character, root)
			end
		else
			-- Returning, or asleep and holding its spot.
			move(
				guardian,
				Pursuit.seekVelocity(
					guardian.body.Position,
					guardian.home,
					guardian.cruiseSpeed,
					GuardianConfig.ARRIVE_RADIUS
				)
			)
		end
	end

	local function tick(deltaTime: number)
		for _, guardian in guardians do
			tickGuardian(guardian, deltaTime)
		end
	end

	local function place(site: WorldService.NestSite, post: GuardianConfig.Post, folder: Instance)
		local model = GuardianModel.build(GuardianLooks.KINDS[post.kind], GuardianLooks.POSTS[post.id])
		local body = model.PrimaryPart :: BasePart
		local home = site.eggCFrame.Position + Vector3.yAxis * GuardianConfig.HOVER_HEIGHT
		model:PivotTo(CFrame.new(home))

		local recommended = post.recommended
		model:SetAttribute(GuardianConfig.POST_ATTRIBUTE, post.id)
		model:SetAttribute(GuardianConfig.STATE_ATTRIBUTE, "Sleep")
		model:SetAttribute(GuardianConfig.RECOMMENDED_MANTISSA_ATTRIBUTE, recommended.mantissa)
		model:SetAttribute(GuardianConfig.RECOMMENDED_EXPONENT_ATTRIBUTE, recommended.exponent)
		CollectionService:AddTag(model, GuardianConfig.TAG)
		model.Parent = folder

		-- Under Server Authority the server simulates everything (network ownership is gone);
		-- clients must not predict guardians either, they just see the replicated motion.
		RunService:SetPredictionMode(model, Enum.PredictionMode.Off)

		local guardian: Guardian = {
			nestId = site.id,
			post = post,
			model = model,
			body = body,
			velocity = body:FindFirstChild(GuardianConfig.VELOCITY_NAME) :: LinearVelocity,
			align = body:FindFirstChild(GuardianConfig.ALIGN_NAME) :: AlignOrientation,
			nestHome = home,
			home = home,
			cruiseSpeed = Speed.flightSpeed(post.speed, SpeedConfig.FLIGHT),
			state = "Sleep",
			target = nil,
			stolenSeconds = 0,
			catchReadyAt = 0,
		}
		table.insert(guardians, guardian)
	end

	local function start()
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = workspace:FindFirstChild("World") or workspace

		local function guard(site: WorldService.NestSite)
			local postIndex = dependencies.getNestGrade(site.id)
			local post = postIndex and GuardianConfig.POSTS[postIndex]
			if not postIndex or not post then
				warn(`[GuardianService] {site.id} has no post; no guardian`)
				return
			end
			place(site, post, folder)
		end

		for _, site in dependencies.getNestSites() do
			guard(site)
		end
		dependencies.nestAdded.connect(guard)
		dependencies.nestRemoved.connect(function(nestId)
			for index, guardian in guardians do
				if guardian.nestId == nestId then
					table.remove(guardians, index)
					guardian.model:Destroy()
					return
				end
			end
		end)

		dependencies.scheduler.every(GuardianConfig.TICK_SECONDS, tick)
	end

	return {
		name = "GuardianService",
		start = start,
	}
end

return table.freeze(GuardianService)
