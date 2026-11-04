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
--   game.ServerStorage.DevCommands.HatchNow:Invoke()
--   game.ServerStorage.DevCommands.DumpProfile:Invoke()
--   game.ServerStorage.DevCommands.SimulateAway:Invoke(3600)
--   game.ServerStorage.DevCommands.GiveCoins:Invoke(5000)
--   game.ServerStorage.DevCommands.SpawnDummyThief:Invoke("Rare", 10)
--   game.ServerStorage.DevCommands.SetPlayTime:Invoke(3600)
--   game.ServerStorage.DevCommands.PvpStats:Invoke()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)

local FOLDER_NAME = "DevCommands"
-- Spawned eggs float this far in front of the player, studs.
local SPAWN_DISTANCE = 5
-- The dummy thief stands this far ahead: inside the strike's corridor.
local DUMMY_DISTANCE = 10

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
	hastenHatching: (player: Player) -> boolean,
	settleOffline: (player: Player) -> (),
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- Rebuilds the bay (which also sends the client its coins).
	refresh: (player: Player) -> (),
	-- Registers a strike target that is not a player, and reads the ability counters.
	addDummy: (model: Model, root: BasePart, onHit: (direction: Vector3) -> boolean) -> (),
	getPvpUsage: () -> { [string]: { used: number, hit: number } },
	-- Daily quests: finish all of today's; give a fresh set as if a new day began.
	completeQuests: (player: Player) -> boolean,
	newQuestDay: (player: Player) -> boolean,
	-- Login gift: makes the last gift this many days old.
	shiftLoginDays: (player: Player, days: number) -> boolean,
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
		-- Floats an egg in front of the first player; it returns to `nestId` (default: the first
		-- nest of the Debris Belt) later.
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
				nestId or "DebrisBeltNest1",
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
		-- A strike target that keeps flying ahead of the first player, where they aim: a dummy
		-- thief holding an egg. A hit knocks the egg loose and removes the dummy. Only works out
		-- in space (there is no drag there, so a target that stood still would be left behind).
		SpawnDummyThief = function(rarity: string?, distance: number?): string
			local player, root = firstPlayerRoot()
			if not player or not root then
				return "no character"
			end
			local studsAhead = distance or DUMMY_DISTANCE
			local function ahead(): CFrame
				local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
				local aim = (if context then FlightInputs.readAim(context) else nil) or root.CFrame.LookVector
				return CFrame.lookAt(root.Position + aim.Unit * studsAhead, root.Position)
			end
			local chosenRarity = (rarity or "Common") :: EggConfig.RarityId
			assert(EggConfig.RARITIES[chosenRarity], `Unknown rarity {chosenRarity}`)
			local model = Instance.new("Model")
			model.Name = "DummyThief"
			local body = Instance.new("Part")
			body.Name = "HumanoidRootPart"
			body.Size = Vector3.new(2, 4, 1)
			body.Color = Color3.fromRGB(230, 90, 160)
			body.Material = Enum.Material.Neon
			body.Anchored = true
			body.CanCollide = false
			body.CFrame = ahead()
			body.Parent = model
			local egg = EggModel.build(chosenRarity, EggConfig.TYPICAL_SIZE)
			egg.Anchored = true
			egg.CFrame = body.CFrame * CFrame.new(0, -0.2, -1.2)
			egg.Parent = model
			model.PrimaryPart = body
			CollectionService:AddTag(model, PvpConfig.DUMMY_TAG)
			model.Parent = workspace
			local follow: RBXScriptConnection
			follow = RunService.Heartbeat:Connect(function()
				if not model.Parent or not root.Parent then
					follow:Disconnect()
					return
				end
				body.CFrame = ahead()
				egg.CFrame = body.CFrame * CFrame.new(0, -0.2, -1.2)
			end)
			dependencies.addDummy(model, body, function(direction)
				dependencies.spawnLooseEgg(
					chosenRarity,
					EggConfig.TYPICAL_SIZE,
					"DebrisBeltNest1",
					egg.Position,
					direction * EggConfig.DROP_SPEED
				)
				model:Destroy()
				return true
			end)
			return "dummy thief ahead"
		end,
		-- Sets every player's total play time (to leave or re-enter the newbie protection).
		SetPlayTime = function(seconds: number): string
			assert(type(seconds) == "number" and seconds >= 0, "SetPlayTime expects seconds, zero or more")
			local names = {}
			for _, player in Players:GetPlayers() do
				local written = dependencies.update(player, function(data)
					data.playSeconds = seconds
				end)
				if written then
					table.insert(names, player.Name)
				end
			end
			return if #names > 0
				then `play time set to {seconds}s for {table.concat(names, ", ")}`
				else "no active profiles"
		end,
		-- Finishes every quest of the first player (to try claiming).
		CompleteQuests = function(): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			return if dependencies.completeQuests(player) then "quests finished" else "profile not active yet"
		end,
		-- Gives the first player a fresh set of quests and a fresh swap, as if a new day began.
		NewQuestDay = function(): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			return if dependencies.newQuestDay(player) then "new quests given" else "profile not active yet"
		end,
		-- As if a day passed since the first player's last gift: the next streak day is waiting.
		NextLoginDay = function(): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			return if dependencies.shiftLoginDays(player, 1) then "next day's gift ready" else "profile not active"
		end,
		-- As if the first player missed a day: the streak starts over.
		MissLoginDay = function(): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			return if dependencies.shiftLoginDays(player, 2) then "a day missed" else "profile not active yet"
		end,
		-- How many times each ability was used in this server and how many landed.
		PvpStats = function(): string
			local lines = {}
			for kind, entry in dependencies.getPvpUsage() do
				table.insert(lines, `{kind}: used {entry.used}, hit {entry.hit}`)
			end
			return if #lines > 0 then table.concat(lines, " | ") else "no abilities used yet"
		end,
		-- Adds coins to the first player's profile (to try purchases without earning them).
		GiveCoins = function(amount: number): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			assert(type(amount) == "number" and amount > 0, "GiveCoins expects a positive number")
			local written = dependencies.update(player, function(data)
				-- Earned like any coins, so the coin board can be tried in Studio.
				Wallet.earn(data, BigNum.fromNumber(amount))
			end)
			if not written then
				return "profile not active yet"
			end
			dependencies.refresh(player)
			return `added {BigNum.format(BigNum.fromNumber(amount))} coins`
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
		-- Every egg in the first player's incubator hatches on the next tick.
		HatchNow = function(): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			return if dependencies.hastenHatching(player) then "hatching" else "profile not active yet"
		end,
		-- Pretends the first player was away for `seconds` and pays the offline income, so the
		-- welcome-back screen can be seen without leaving.
		SimulateAway = function(seconds: number?): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local away = seconds or 60 * 60
			assert(type(away) == "number" and away > 0, "SimulateAway expects a positive number of seconds")
			local written = dependencies.update(player, function(data)
				data.lastSeenAt = workspace:GetServerTimeNow() - away
			end)
			if not written then
				return "profile not active yet"
			end
			dependencies.settleOffline(player)
			return `settled {away}s away`
		end,
		-- A readable summary of the first player's profile.
		DumpProfile = function(): string
			local player = firstPlayerRoot()
			local data = player and dependencies.getData(player)
			if not data then
				return "profile not active yet"
			end
			local pods = {}
			for _, pod in data.pods do
				table.insert(pods, if pod.alien then pod.alien.id else "-")
			end
			local function ids(list: { PlayerData.AlienRecord }): string
				local names = {}
				for _, alien in list do
					table.insert(names, alien.id)
				end
				return table.concat(names, ", ")
			end
			local podList = table.concat(pods, ", ")
			return `coins {BigNum.format(data.coins)} | trained {BigNum.format(data.trained)}`
				.. ` | trainer {data.trainerLevel} | jetpack {data.jetpackLevel}`
				.. ` | played {math.floor(data.playSeconds)}s | pods [{podList}]`
				.. ` | inventory [{ids(data.inventory)}] | floor [{ids(data.floor)}] | eggs {#data.incubator}`
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
