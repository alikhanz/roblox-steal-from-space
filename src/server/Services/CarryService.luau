--!strict
-- Owns eggs once they leave a nest: confirms grabs requested by the simulation, holds the egg
-- in the thief's arms, hands it to the bay at the station, drops the egg when its carrier is
-- caught or dies, and returns floating eggs to their nests after a while.
-- Runs after each simulation step (PostSimulation): it creates and destroys instances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bounds = require(ReplicatedStorage.Shared.Domain.Bounds)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

-- Knocked-out eggs stay outside this sphere (see EggConfig.DOME_MARGIN).
local DOME_CENTER = StationConfig.STATION.domeCenter
local EGG_DOME_RADIUS = StationConfig.STATION.domeRadius + EggConfig.DOME_MARGIN

-- The server accepts a grab a little beyond the reach, for latency between client and server.
local REACH_TOLERANCE = 3
local LOOSE_FOLDER_NAME = "LooseEggs"
-- Carried egg position in front of the chest, relative to the UpperTorso.
local CARRY_OFFSET = CFrame.new(0, -0.2, -1.4)

export type Dependencies = {
	takeNestEgg: (nestId: string) -> (EggConfig.RarityId?, EggConfig.SizeId?),
	returnNestEgg: (nestId: string, rarity: EggConfig.RarityId, size: EggConfig.SizeId) -> (),
	-- The egg of `nestId` reached a bay: its nest may grow a new one.
	nestEggDelivered: (nestId: string) -> (),
	getNestEggCFrame: (nestId: string) -> CFrame?,
	getNestGrade: (nestId: string) -> number?,
	-- Takes a delivered egg into the player's bay. False when the bay cannot take it yet (no
	-- active profile): the egg then stays in the thief's arms.
	deliverEgg: (player: Player, rarity: EggConfig.RarityId, size: EggConfig.SizeId, grade: number) -> boolean,
}

export type Carried = {
	rarity: EggConfig.RarityId,
	size: EggConfig.SizeId,
	nestId: string,
}

export type CarryService = {
	name: string,
	start: () -> (),
	-- Knocks the carried egg loose (when a guardian catches the carrier), flying off at `launch`
	-- if given. Returns true if dropped.
	dropEgg: (player: Player, launch: Vector3?) -> boolean,
	-- What the player carries, or nil when not carrying.
	getCarried: (player: Player) -> Carried?,
	-- Who carries the egg of `nestId` right now, or nil.
	findCarrier: (nestId: string) -> Player?,
	-- Where the eggs of `nestId` lie knocked out (usually one; empty while the egg is in the
	-- nest or carried).
	findLooseEggs: (nestId: string) -> { Vector3 },
	-- Puts a floating egg at `position` that returns to `nestId` when it expires.
	spawnLooseEgg: (
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		nestId: string,
		position: Vector3,
		launch: Vector3?
	) -> (),
}

type CarriedEntry = {
	rarity: EggConfig.RarityId,
	size: EggConfig.SizeId,
	nestId: string,
	model: Part,
}

type LooseEgg = {
	rarity: EggConfig.RarityId,
	size: EggConfig.SizeId,
	nestId: string,
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

	local function clearGrab(character: Model)
		character:SetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE, 0)
		character:SetAttribute(EggConfig.GRAB_TARGET_ATTRIBUTE, nil)
	end

	local function giveEgg(
		player: Player,
		character: Model,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		nestId: string
	)
		local torso = character:FindFirstChild("UpperTorso")
		if not torso or not torso:IsA("BasePart") then
			dependencies.returnNestEgg(nestId, rarity, size)
			return
		end
		local egg = EggModel.build(rarity, size)
		egg.Name = "CarriedEgg"
		CollectionService:AddTag(egg, EggConfig.CARRIED_EGG_TAG)
		egg.CFrame = torso.CFrame * CARRY_OFFSET
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = egg
		weld.Parent = egg
		egg.Parent = character

		carried[player] = { rarity = rarity, size = size, nestId = nestId, model = egg }
		character:SetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE, rarity)
		character:SetAttribute(EggConfig.CARRIED_SIZE_ATTRIBUTE, size)
	end

	local function releaseCarried(player: Player): CarriedEntry?
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
		return entry
	end

	local function spawnLoose(
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		nestId: string,
		position: Vector3,
		launch: Vector3?
	)
		local folder = looseFolder
		if not folder then
			dependencies.returnNestEgg(nestId, rarity, size)
			return
		end
		looseCounter += 1
		local part = EggModel.build(rarity, size)
		part.Name = `LooseEgg{looseCounter}`
		part.Anchored = true
		-- An egg knocked loose inside the dome pops out through it.
		part.CFrame = CFrame.new(Bounds.pushOutside(position, DOME_CENTER, EGG_DOME_RADIUS))
		part.Parent = folder
		CollectionService:AddTag(part, EggConfig.LOOSE_EGG_TAG)
		loose[part.Name] = {
			rarity = rarity,
			size = size,
			nestId = nestId,
			part = part,
			expiresAt = os.clock() + EggConfig.LOOSE_SECONDS,
			velocity = launch or Vector3.zero,
		}
	end

	local function dropEgg(player: Player, launch: Vector3?): boolean
		local entry = releaseCarried(player)
		if not entry then
			return false
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			dependencies.returnNestEgg(entry.nestId, entry.rarity, entry.size)
			return true
		end
		spawnLoose(entry.rarity, entry.size, entry.nestId, root.Position, launch)
		return true
	end

	-- Knocked-out eggs coast and tumble until they stop; they are anchored, so this moves them.
	-- The dome turns them aside: an egg drifting at the station slides along it, outside.
	local function driftLooseEggs(deltaTime: number)
		for _, egg in loose do
			if egg.velocity.Magnitude < DRIFT_REST_SPEED then
				continue
			end
			egg.velocity = Bounds.keepOutside(egg.part.Position, egg.velocity, DOME_CENTER, EGG_DOME_RADIUS)
			local spin = EggConfig.DROP_SPIN_RATE * deltaTime
			local moved = egg.part.Position + egg.velocity * deltaTime
			egg.part.CFrame = CFrame.new(Bounds.pushOutside(moved, DOME_CENTER, EGG_DOME_RADIUS))
				* egg.part.CFrame.Rotation
				* CFrame.Angles(spin, spin * 0.6, 0)
			egg.velocity *= EggConfig.DROP_RETENTION_PER_SECOND ^ deltaTime
			if egg.velocity.Magnitude < DRIFT_REST_SPEED then
				egg.velocity = Vector3.zero
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
				giveEgg(player, character, looseEgg.rarity, looseEgg.size, looseEgg.nestId)
			end
			return
		end

		local eggCFrame = dependencies.getNestEggCFrame(targetId)
		if not eggCFrame or (eggCFrame.Position - root.Position).Magnitude > EggConfig.GRAB_REACH + REACH_TOLERANCE then
			return
		end
		local rarity, size = dependencies.takeNestEgg(targetId)
		if rarity and size then
			giveEgg(player, character, rarity, size, targetId)
		end
	end

	local function deliver(player: Player)
		local entry = carried[player]
		if not entry then
			return
		end
		local grade = dependencies.getNestGrade(entry.nestId)
		if not grade then
			warn(`[CarryService] {entry.nestId} has no grade; egg returned`)
			releaseCarried(player)
			dependencies.returnNestEgg(entry.nestId, entry.rarity, entry.size)
			return
		end
		if dependencies.deliverEgg(player, entry.rarity, entry.size, grade) then
			releaseCarried(player)
			dependencies.nestEggDelivered(entry.nestId)
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
			-- Back on the station platform with an egg: delivered.
			if carried[player] and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == false then
				deliver(player)
			end
		end

		local now = os.clock()
		for id, egg in loose do
			if now >= egg.expiresAt then
				loose[id] = nil
				egg.part:Destroy()
				dependencies.returnNestEgg(egg.nestId, egg.rarity, egg.size)
			end
		end
	end

	local function watchPlayer(player: Player)
		local function onCharacter(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					dropEgg(player)
				end)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		player.CharacterRemoving:Connect(function()
			dropEgg(player)
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
			local entry = releaseCarried(player)
			if entry then
				dependencies.returnNestEgg(entry.nestId, entry.rarity, entry.size)
			end
		end)
		RunService.PostSimulation:Connect(postSimulation)
	end

	return {
		name = "CarryService",
		start = start,
		dropEgg = dropEgg,
		getCarried = function(player: Player): Carried?
			local entry = carried[player]
			return if entry then { rarity = entry.rarity, size = entry.size, nestId = entry.nestId } else nil
		end,
		findCarrier = function(nestId: string): Player?
			for player, entry in carried do
				if entry.nestId == nestId then
					return player
				end
			end
			return nil
		end,
		findLooseEggs = function(nestId: string): { Vector3 }
			local positions = {}
			for _, egg in loose do
				if egg.nestId == nestId then
					table.insert(positions, egg.part.Position)
				end
			end
			return positions
		end,
		spawnLooseEgg = spawnLoose,
	}
end

return table.freeze(CarryService)
