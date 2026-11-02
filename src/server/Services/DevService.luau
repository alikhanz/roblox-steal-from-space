--!strict
-- Studio-only commands for playtests (by hand or through the Studio MCP): put an egg next to a
-- player, refill or disable oxygen, and so on. Exposed as BindableFunctions in
-- ServerStorage.DevCommands, which only server code can reach. Does nothing outside Studio.
--
-- Examples (server):
--   game.ServerStorage.DevCommands.SpawnEggNearPlayer:Invoke("Rare")
--   game.ServerStorage.DevCommands.SetInfiniteOxygen:Invoke(true)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)

local FOLDER_NAME = "DevCommands"
-- Spawned eggs float this far in front of the player, studs.
local SPAWN_DISTANCE = 5

export type Dependencies = {
	spawnLooseEgg: (rarity: EggConfig.RarityId, nestId: string, position: Vector3) -> (),
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
		SpawnEggNearPlayer = function(rarity: string?, nestId: string?): string
			local _, root = firstPlayerRoot()
			if not root then
				return "no character"
			end
			local chosen = (rarity or "Common") :: EggConfig.RarityId
			assert(EggConfig.RARITIES[chosen], `Unknown rarity {chosen}`)
			dependencies.spawnLooseEgg(
				chosen,
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
