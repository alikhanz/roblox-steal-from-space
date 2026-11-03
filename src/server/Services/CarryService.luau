--!strict
-- Owns eggs once they leave a nest: confirms grabs requested by the simulation, holds the egg
-- in the thief's arms, counts deliveries at the station, drops the egg when its carrier is
-- caught or dies, and returns floating eggs to their nests after a while.
-- Runs after each simulation step (PostSimulation): it creates and destroys instances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)

-- The server accepts a grab a little beyond the reach, for latency between client and server.
local REACH_TOLERANCE = 3
local LOOSE_FOLDER_NAME = "LooseEggs"
-- Carried egg position in front of the chest, relative to the UpperTorso.
local CARRY_OFFSET = CFrame.new(0, -0.2, -1.4)

export type Dependencies = {
	takeNestEgg: (nestId: string) -> (EggConfig.RarityId?, EggConfig.SizeId?),
	returnNestEgg: (nestId: string, rarity: EggConfig.RarityId, size: EggConfig.SizeId) -> (),
	getNestEggCFrame: (nestId: string) -> CFrame?,
}

export type Carried = {
	rarity: EggConfig.RarityId,
	size: EggConfig.SizeId,
	nestId: string,
}

export type CarryService = {
	name: string,
	start: () -> (),
	-- Knocks the carried egg loose (when a guardian catches the carrier). Returns true if dropped.
	dropEgg: (player: Player) -> boolean,
	-- What the player carries, or nil when not carrying.
	getCarried: (player: Player) -> Carried?,
	-- Who carries the egg of `nestId` right now, or nil.
	findCarrier: (nestId: string) -> Player?,
	-- Puts a floating egg at `position` that returns to `nestId` when it expires.
	spawnLooseEgg: (rarity: EggConfig.RarityId, size: EggConfig.SizeId, nestId: string, position: Vector3) -> (),
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
}

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

	local function spawnLoose(rarity: EggConfig.RarityId, size: EggConfig.SizeId, nestId: string, position: Vector3)
		local folder = looseFolder
		if not folder then
			dependencies.returnNestEgg(nestId, rarity, size)
			return
		end
		looseCounter += 1
		local part = EggModel.build(rarity, size)
		part.Name = `LooseEgg{looseCounter}`
		part.Anchored = true
		part.CFrame = CFrame.new(position)
		part.Parent = folder
		CollectionService:AddTag(part, EggConfig.LOOSE_EGG_TAG)
		loose[part.Name] = {
			rarity = rarity,
			size = size,
			nestId = nestId,
			part = part,
			expiresAt = os.clock() + EggConfig.LOOSE_SECONDS,
		}
	end

	local function dropAt(player: Player, position: Vector3): boolean
		local entry = releaseCarried(player)
		if not entry then
			return false
		end
		spawnLoose(entry.rarity, entry.size, entry.nestId, position)
		return true
	end

	local function dropEgg(player: Player): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			local entry = releaseCarried(player)
			if entry then
				dependencies.returnNestEgg(entry.nestId, entry.rarity, entry.size)
			end
			return entry ~= nil
		end
		return dropAt(player, root.Position)
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
		if releaseCarried(player) then
			local delivered = player:GetAttribute(EggConfig.DELIVERED_ATTRIBUTE)
			player:SetAttribute(
				EggConfig.DELIVERED_ATTRIBUTE,
				(if type(delivered) == "number" then delivered else 0) + 1
			)
		end
	end

	local function postSimulation()
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
		spawnLooseEgg = spawnLoose,
	}
end

return table.freeze(CarryService)
