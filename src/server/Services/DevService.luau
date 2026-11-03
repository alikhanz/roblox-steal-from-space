--!strict
-- Studio-only commands for playtests (by hand or through the Studio MCP): put an egg next to a
-- player, refill or disable oxygen, and so on. Exposed as BindableFunctions in
-- ServerStorage.DevCommands, which only server code can reach. Does nothing outside Studio.
--
-- Examples (server):
--   game.ServerStorage.DevCommands.SpawnEggNearPlayer:Invoke("Rare", "Large")
--   game.ServerStorage.DevCommands.SetInfiniteOxygen:Invoke(true)
--   game.ServerStorage.DevCommands.SetSpeed:Invoke(2500)
--   game.ServerStorage.DevCommands.GiveAlien:Invoke(2, "Rare")
--   game.ServerStorage.DevCommands.GiveEgg:Invoke("Uncommon", "Large", 1)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)

local FOLDER_NAME = "DevCommands"
-- Spawned eggs float this far in front of the player, studs.
local SPAWN_DISTANCE = 5

export type Dependencies = {
	spawnLooseEgg: (
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		nestId: string,
		position: Vector3,
		launch: Vector3?
	) -> (),
	setSpeed: (player: Player, speed: BigNum.BigNum) -> boolean,
	addAlien: (player: Player, alienId: AlienConfig.AlienId) -> Bay.Location?,
	addEgg: (player: Player, rarity: EggConfig.RarityId, size: EggConfig.SizeId, grade: number) -> boolean,
}

export type DevService = {
	name: string,
	start: () -> (),
}

local DevService = {}

local function firstPlayerRoot(): (Player?, BasePart?)
	local player = Players:GetPlayers()[1]
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return player, root
	end
	return player, nil
end

function DevService.new(dependencies: Dependencies): DevService
	local infiniteOxygen = DevConfig.STUDIO_INFINITE_OXYGEN

	local commands: { [string]: (...any) -> any } = {
		-- Floats an egg in front of the first player; it returns to `nestId` (default Nest1) later.
		SpawnEggNearPlayer = function(rarity: string?, size: string?, nestId: string?): string
			local _, root = firstPlayerRoot()
			if not root then
				return "no character"
			end
			local chosenRarity = (rarity or "Common") :: EggConfig.RarityId
			local chosenSize = (size or EggConfig.TYPICAL_SIZE) :: EggConfig.SizeId
			assert(EggConfig.RARITIES[chosenRarity], `Unknown rarity {chosenRarity}`)
			assert(EggConfig.SIZES[chosenSize], `Unknown size {chosenSize}`)
			dependencies.spawnLooseEgg(
				chosenRarity,
				chosenSize,
				nestId or "Nest1",
				root.Position + root.CFrame.LookVector * SPAWN_DISTANCE
			)
			return "spawned"
		end,
		RefillOxygen = function(): string
			local player = firstPlayerRoot()
			if player and player.Character then
				player.Character:SetAttribute(OxygenConfig.ATTRIBUTE, OxygenConfig.CAPACITY)
			end
			return "refilled"
		end,
		-- Sets the first player's speed stat (a plain number is enough for playtests).
		SetSpeed = function(value: number): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			assert(type(value) == "number" and value > 0, "SetSpeed expects a positive number")
			local speed = BigNum.fromNumber(value)
			if not dependencies.setSpeed(player, speed) then
				return "profile not active yet"
			end
			return `speed set to {BigNum.format(speed)}`
		end,
		-- Gives the first player an alien of `grade` (guardian post number) and `tier`.
		GiveAlien = function(grade: number?, tier: string?): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local gradeConfig = assert(AlienConfig.GRADES[grade or 1], `Unknown grade {grade}`)
			local alienId = assert(gradeConfig.aliens[(tier or "Common") :: AlienConfig.TierId], `Unknown tier {tier}`)
			local location = dependencies.addAlien(player, alienId)
			return if location then `{alienId} -> {location}` else "profile not active yet"
		end,
		-- Puts an egg into the first player's incubator, as if delivered from guardian `grade`.
		GiveEgg = function(rarity: string?, size: string?, grade: number?): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local chosenRarity = (rarity or "Common") :: EggConfig.RarityId
			local chosenSize = (size or EggConfig.TYPICAL_SIZE) :: EggConfig.SizeId
			assert(EggConfig.RARITIES[chosenRarity], `Unknown rarity {chosenRarity}`)
			assert(EggConfig.SIZES[chosenSize], `Unknown size {chosenSize}`)
			local added = dependencies.addEgg(player, chosenRarity, chosenSize, grade or 1)
			return if added then "egg in the incubator" else "profile not active yet"
		end,
		-- Oxygen stops draining for every player in this playtest (true) or drains again (false).
		SetInfiniteOxygen = function(enabled: boolean): string
			for _, player in Players:GetPlayers() do
				player:SetAttribute(DevConfig.INFINITE_OXYGEN_ATTRIBUTE, enabled == true)
			end
			infiniteOxygen = enabled == true
			return if infiniteOxygen then "infinite oxygen on" else "infinite oxygen off"
		end,
	}

	local function start()
		if not RunService:IsStudio() then
			return
		end
		Players.PlayerAdded:Connect(function(player)
			player:SetAttribute(DevConfig.INFINITE_OXYGEN_ATTRIBUTE, infiniteOxygen)
		end)
		for _, player in Players:GetPlayers() do
			player:SetAttribute(DevConfig.INFINITE_OXYGEN_ATTRIBUTE, infiniteOxygen)
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for name, command in commands do
			local bindable = Instance.new("BindableFunction")
			bindable.Name = name
			bindable.OnInvoke = command
			bindable.Parent = folder
		end
		folder.Parent = ServerStorage
	end

	return {
		name = "DevService",
		start = start,
	}
end

return table.freeze(DevService)
