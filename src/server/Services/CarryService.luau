--!strict
-- Owns eggs out of their nests: confirms grabs requested by the simulation, holds the egg in the
-- thief's arms, hands it to the bay at the station, drops the egg when its carrier is caught or
-- dies, and returns floating eggs to their nests after a while. Every egg belongs to a home
-- (Domain/EggHomes): the nest it was taken from (a meteor egg, to its crater), or the star
-- serpent for the star egg. The home's guardian guards it, its grade is the egg's, and the egg
-- goes back there when it leaves play.
-- Runs after each simulation step (PostSimulation): it creates and destroys instances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bounds = require(ReplicatedStorage.Shared.Domain.Bounds)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

-- Knocked-out eggs stay outside this sphere (see EggConfig.DOME_MARGIN).
local DOME_CENTER = StationConfig.STATION.domeCenter
local EGG_DOME_RADIUS = StationConfig.STATION.domeRadius + EggConfig.DOME_MARGIN

-- The server accepts a grab a little beyond the reach, for latency between client and server.
local REACH_TOLERANCE = 3
local LOOSE_FOLDER_NAME = "LooseEggs"
-- Carried egg position in front of the chest, relative to the UpperTorso.
local CARRY_OFFSET = CFrame.new(0, -0.2, -1.4)

-- An egg out of its nest, carried or floating loose.
export type Egg = {
	rarity: EggConfig.RarityId,
	size: EggConfig.SizeId,
	-- Its home (a nest, or another keeper's: Domain/EggHomes): its guardian guards the egg, and
	-- its grade is the egg's.
	nestId: string,
	-- The alien variant it hatches into.
	variant: AlienConfig.VariantId,
	-- Luck on top of its rarity's and size's (EggConfig.luckOf), carried to the bay; nil: none.
	luck: number?,
}

export type Dependencies = {
	-- Grabbing from a nest.
	takeNestEgg: (nestId: string) -> (EggConfig.RarityId?, EggConfig.SizeId?, AlienConfig.VariantId?),
	getNestEggCFrame: (nestId: string) -> CFrame?,
	-- The egg's home (EggHomes): takes back an egg that left play, hears of one that reached a
	-- bay (a nest then grows a new one), gives the grade.
	returnHomeEgg: (
		homeId: string,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		variant: AlienConfig.VariantId
	) -> (),
	homeEggDelivered: (homeId: string) -> (),
	getHomeGrade: (homeId: string) -> number?,
	-- Takes a delivered egg into the player's bay. False when the bay cannot take it yet (no
	-- active profile): the egg then stays in the thief's arms.
	deliverEgg: (
		player: Player,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		grade: number,
		variant: AlienConfig.VariantId?,
		luck: number?
	) -> boolean,
}

-- An egg as the other services see it: with its grade (nil if its nest has none).
export type Carried = Egg & { grade: number? }

-- Why a carried egg left the thief's hands without being delivered.
export type LossReason = "Guardian" | "Serpent" | "Pvp" | "Death" | "Left" | "Storm"
-- Where a grabbed egg came from.
export type GrabSource = "Nest" | "Loose"

export type CarryService = {
	name: string,
	start: () -> (),
	-- Knocks the carried egg loose, flying off at `launch` if given; `reason` says who did it
	-- (a death when not given). Returns true if dropped.
	dropEgg: (player: Player, launch: Vector3?, reason: LossReason?) -> boolean,
	-- Takes the carried egg out of play at once (no loose egg). Returns true if there was one.
	returnEgg: (player: Player, reason: LossReason) -> boolean,
	-- What the player carries, or nil when not carrying.
	getCarried: (player: Player) -> Carried?,
	-- Who carries an egg of `nestId` right now (several during a meteor shower).
	findCarriers: (nestId: string) -> { Player },
	-- Where the eggs of `nestId` lie knocked out (usually one; empty while the egg is in the
	-- nest or carried).
	findLooseEggs: (nestId: string) -> { Vector3 },
	-- Puts a floating egg at `position` (drifting off at `launch`) that returns to its home when
	-- it expires.
	spawnLooseEgg: (egg: Egg, position: Vector3, launch: Vector3?) -> (),
	-- Takes the floating eggs of `homeId` away at once, without returning them anywhere.
	removeLooseEggs: (homeId: string) -> (),
	-- The egg's journey, for analytics: taken, carried inside the station border (safe from
	-- guardians), delivered to the bay, or lost on the way.
	grabbed: Signal.Signal<Player, Carried, GrabSource>,
	reachedStation: Signal.Signal<Player, Carried>,
	delivered: Signal.Signal<Player, Carried>,
	lost: Signal.Signal<Player, Carried, LossReason>,
}

type CarriedEntry = {
	egg: Egg,
	model: Part,
	-- Already carried inside the station border once (reachedStation fired).
	reachedStation: boolean,
}

type LooseEgg = {
	egg: Egg,
	part: Part,
	expiresAt: number,
	-- Drift left from the knock-out; the egg coasts to a stop and tumbles meanwhile.
	velocity: Vector3,
}

-- Below this speed a knocked-out egg is considered at rest, studs per second.
local DRIFT_REST_SPEED = 0.5

local CarryService = {}

function CarryService.new(dependencies: Dependencies): CarryService
	local carried: { [Player]: CarriedEntry } = {}
	local loose: { [string]: LooseEgg } = {}
	local looseFolder: Folder? = nil
	local looseCounter = 0
	local grabbed = Signal.new() :: Signal.Signal<Player, Carried, GrabSource>
	local reachedStation = Signal.new() :: Signal.Signal<Player, Carried>
	local delivered = Signal.new() :: Signal.Signal<Player, Carried>
	local lost = Signal.new() :: Signal.Signal<Player, Carried, LossReason>

	local function publicOf(egg: Egg): Carried
		return {
			rarity = egg.rarity,
			size = egg.size,
			nestId = egg.nestId,
			variant = egg.variant,
			luck = egg.luck,
			grade = dependencies.getHomeGrade(egg.nestId),
		}
	end

	-- The egg leaves play without being delivered: back to its home.
	local function leavePlay(egg: Egg)
		dependencies.returnHomeEgg(egg.nestId, egg.rarity, egg.size, egg.variant)
	end

	local function clearGrab(character: Model)
		character:SetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE, 0)
		character:SetAttribute(EggConfig.GRAB_TARGET_ATTRIBUTE, nil)
	end

	local function giveEgg(player: Player, character: Model, egg: Egg)
		local torso = character:FindFirstChild("UpperTorso")
		if not torso or not torso:IsA("BasePart") then
			leavePlay(egg)
			return
		end
		local model = EggModel.build(egg.rarity, egg.size, { variant = egg.variant, luck = egg.luck })
		model.Name = "CarriedEgg"
		CollectionService:AddTag(model, EggConfig.CARRIED_EGG_TAG)
		model.CFrame = torso.CFrame * CARRY_OFFSET
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = model
		weld.Parent = model
		model.Parent = character

		carried[player] = { egg = egg, model = model, reachedStation = false }
		character:SetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE, egg.rarity)
		character:SetAttribute(EggConfig.CARRIED_SIZE_ATTRIBUTE, egg.size)
	end

	local function releaseCarried(player: Player): Egg?
		local entry = carried[player]
		if not entry then
			return nil
		end
		carried[player] = nil
		entry.model:Destroy()
		local character = player.Character
		if character then
			character:SetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE, nil)
			character:SetAttribute(EggConfig.CARRIED_SIZE_ATTRIBUTE, nil)
		end
		return entry.egg
	end

	-- `owner`: the player who dropped it.
	local function spawnLoose(egg: Egg, position: Vector3, launch: Vector3?, owner: Player?)
		local folder = looseFolder
		if not folder then
			leavePlay(egg)
			return
		end
		looseCounter += 1
		local part = EggModel.build(egg.rarity, egg.size, { variant = egg.variant, luck = egg.luck })
		part.Name = `LooseEgg{looseCounter}`
		part.Anchored = true
		-- An egg knocked loose inside the dome pops out through it.
		part.CFrame = CFrame.new(Bounds.pushOutside(position, DOME_CENTER, EGG_DOME_RADIUS))
		part:SetAttribute(EggConfig.LOOSE_EGG_GRADE_ATTRIBUTE, dependencies.getHomeGrade(egg.nestId))
		part:SetAttribute(EggConfig.LOOSE_EGG_DROPPED_BY_ATTRIBUTE, if owner then owner.UserId else nil)
		part.Parent = folder
		CollectionService:AddTag(part, EggConfig.LOOSE_EGG_TAG)
		loose[part.Name] = {
			egg = egg,
			part = part,
			expiresAt = os.clock() + EggConfig.LOOSE_SECONDS,
			velocity = launch or Vector3.zero,
		}
	end

	local function dropEgg(player: Player, launch: Vector3?, reason: LossReason?): boolean
		local egg = releaseCarried(player)
		if not egg then
			return false
		end
		lost.fire(player, publicOf(egg), reason or "Death")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			leavePlay(egg)
			return true
		end
		spawnLoose(egg, root.Position, launch, player)
		return true
	end

	local function returnEgg(player: Player, reason: LossReason): boolean
		local egg = releaseCarried(player)
		if not egg then
			return false
		end
		lost.fire(player, publicOf(egg), reason)
		leavePlay(egg)
		return true
	end

	-- Knocked-out eggs coast and tumble until they stop; they are anchored, so this moves them.
	-- The dome turns them aside: an egg drifting at the station slides along it, outside.
	local function driftLooseEggs(deltaTime: number)
		for _, entry in loose do
			if entry.velocity.Magnitude < DRIFT_REST_SPEED then
				continue
			end
			local part = entry.part
			entry.velocity = Bounds.keepOutside(part.Position, entry.velocity, DOME_CENTER, EGG_DOME_RADIUS)
			local spin = EggConfig.DROP_SPIN_RATE * deltaTime
			local moved = part.Position + entry.velocity * deltaTime
			part.CFrame = CFrame.new(Bounds.pushOutside(moved, DOME_CENTER, EGG_DOME_RADIUS))
				* part.CFrame.Rotation
				* CFrame.Angles(spin, spin * 0.6, 0)
			entry.velocity *= EggConfig.DROP_RETENTION_PER_SECOND ^ deltaTime
			if entry.velocity.Magnitude < DRIFT_REST_SPEED then
				entry.velocity = Vector3.zero
			end
		end
	end

	-- Confirms a grab the simulation completed: the egg must still be there and within reach.
	local function confirmGrab(player: Player, character: Model, root: BasePart)
		local progress = character:GetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE)
		local targetId = character:GetAttribute(EggConfig.GRAB_TARGET_ATTRIBUTE)
		if type(progress) ~= "number" or progress < 1 or type(targetId) ~= "string" then
			return
		end
		clearGrab(character)
		if carried[player] then
			return
		end

		local looseEgg = loose[targetId]
		if looseEgg then
			if (looseEgg.part.Position - root.Position).Magnitude <= EggConfig.GRAB_REACH + REACH_TOLERANCE then
				loose[targetId] = nil
				looseEgg.part:Destroy()
				giveEgg(player, character, looseEgg.egg)
				local entry = carried[player]
				if entry then
					grabbed.fire(player, publicOf(entry.egg), "Loose")
				end
			end
			return
		end

		local eggCFrame = dependencies.getNestEggCFrame(targetId)
		if not eggCFrame or (eggCFrame.Position - root.Position).Magnitude > EggConfig.GRAB_REACH + REACH_TOLERANCE then
			return
		end
		local rarity, size, variant = dependencies.takeNestEgg(targetId)
		if rarity and size and variant then
			giveEgg(player, character, { rarity = rarity, size = size, nestId = targetId, variant = variant })
			local entry = carried[player]
			if entry then
				grabbed.fire(player, publicOf(entry.egg), "Nest")
			end
		end
	end

	local function deliver(player: Player)
		local entry = carried[player]
		if not entry then
			return
		end
		local egg = entry.egg
		local grade = dependencies.getHomeGrade(egg.nestId)
		if not grade then
			warn(`[CarryService] {egg.nestId} has no grade; egg out of play`)
			releaseCarried(player)
			leavePlay(egg)
			return
		end
		if dependencies.deliverEgg(player, egg.rarity, egg.size, grade, egg.variant, egg.luck) then
			releaseCarried(player)
			dependencies.homeEggDelivered(egg.nestId)
			delivered.fire(player, publicOf(egg))
		end
	end

	local function postSimulation(deltaTime: number)
		driftLooseEggs(deltaTime)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not root or not root:IsA("BasePart") then
				continue
			end
			confirmGrab(player, character, root)
			local entry = carried[player]
			local insideBorder = (root.Position - DOME_CENTER).Magnitude <= StationConfig.BORDER_RADIUS
			if entry and not entry.reachedStation and insideBorder then
				entry.reachedStation = true
				reachedStation.fire(player, publicOf(entry.egg))
			end
			-- Back on the station platform with an egg: delivered.
			if carried[player] and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == false then
				deliver(player)
			end
		end

		local now = os.clock()
		for id, entry in loose do
			if now >= entry.expiresAt then
				loose[id] = nil
				entry.part:Destroy()
				leavePlay(entry.egg)
			end
		end
	end

	local function watchPlayer(player: Player)
		local function onCharacter(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					dropEgg(player, nil, "Death")
				end)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		-- After a death the egg is already gone; with it still in hands, the player is leaving.
		player.CharacterRemoving:Connect(function()
			dropEgg(player, nil, "Left")
		end)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end

	local function start()
		local world = workspace:FindFirstChild("World")
		local folder = Instance.new("Folder")
		folder.Name = LOOSE_FOLDER_NAME
		folder.Parent = world or workspace
		looseFolder = folder

		for _, player in Players:GetPlayers() do
			watchPlayer(player)
		end
		Players.PlayerAdded:Connect(watchPlayer)
		Players.PlayerRemoving:Connect(function(player)
			local egg = releaseCarried(player)
			if egg then
				lost.fire(player, publicOf(egg), "Left")
				leavePlay(egg)
			end
		end)
		RunService.PostSimulation:Connect(postSimulation)
	end

	return {
		name = "CarryService",
		start = start,
		dropEgg = dropEgg,
		returnEgg = returnEgg,
		getCarried = function(player: Player): Carried?
			local entry = carried[player]
			return if entry then publicOf(entry.egg) else nil
		end,
		findCarriers = function(nestId: string): { Player }
			local players = {}
			for player, entry in carried do
				if entry.egg.nestId == nestId then
					table.insert(players, player)
				end
			end
			return players
		end,
		findLooseEggs = function(nestId: string): { Vector3 }
			local positions = {}
			for _, entry in loose do
				if entry.egg.nestId == nestId then
					table.insert(positions, entry.part.Position)
				end
			end
			return positions
		end,
		spawnLooseEgg = function(egg: Egg, position: Vector3, launch: Vector3?)
			spawnLoose(egg, position, launch)
		end,
		removeLooseEggs = function(homeId: string)
			for id, entry in loose do
				if entry.egg.nestId == homeId then
					loose[id] = nil
					entry.part:Destroy()
				end
			end
		end,
		grabbed = grabbed,
		reachedStation = reachedStation,
		delivered = delivered,
		lost = lost,
	}
end

return table.freeze(CarryService)
