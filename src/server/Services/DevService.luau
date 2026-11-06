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
--   game.ServerStorage.DevCommands.GiveEgg:Invoke("Rare", "Medium", 3, "Meteor")
--   game.ServerStorage.DevCommands.HatchNow:Invoke()
--   game.ServerStorage.DevCommands.DumpProfile:Invoke()
--   game.ServerStorage.DevCommands.SimulateAway:Invoke(3600)
--   game.ServerStorage.DevCommands.GiveCoins:Invoke(5000)
--   game.ServerStorage.DevCommands.SpawnDummyThief:Invoke("Rare", 10)
--   game.ServerStorage.DevCommands.SetPlayTime:Invoke(3600)
--   game.ServerStorage.DevCommands.PvpStats:Invoke()
--   game.ServerStorage.DevCommands.ActivityStatus:Invoke()
--   game.ServerStorage.DevCommands.HitSerpent:Invoke(3)
--   game.ServerStorage.DevCommands.SetIncubatorSlots:Invoke(6)
--   game.ServerStorage.DevCommands.HoldSerpent:Invoke(true, 30)
--   game.ServerStorage.DevCommands.SimulatePurchase:Invoke("Training", 3600)
--   game.ServerStorage.DevCommands.SimulatePurchase:Invoke("ReadyNow", 3, 17)
--   game.ServerStorage.DevCommands.ReplayLastReceipt:Invoke()
--   game.ServerStorage.DevCommands.GivePass:Invoke("NightShift")

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ActivityConfig = require(ReplicatedStorage.Shared.Config.ActivityConfig)
local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CarryService = require(script.Parent.CarryService)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local OxygenConfig = require(ReplicatedStorage.Shared.Config.OxygenConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local PvpService = require(script.Parent.PvpService)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local FOLDER_NAME = "DevCommands"
-- The MCP's way in: a command as JSON into this value, its outcome back in the other one.
local REQUEST_NAME = "Request"
local RESULT_NAME = "Result"
-- Spawned eggs float this far in front of the player, studs.
local SPAWN_DISTANCE = 5
-- The dummy thief stands this far ahead: inside the strike's corridor.
local DUMMY_DISTANCE = 10

export type Dependencies = {
	spawnLooseEgg: (egg: CarryService.Egg, position: Vector3, launch: Vector3?) -> (),
	setSpeed: (player: Player, speed: BigNum.BigNum) -> boolean,
	addAlien: (player: Player, alienId: AlienConfig.AlienId) -> Bay.Location?,
	addEgg: (
		player: Player,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		grade: number,
		variant: AlienConfig.VariantId?,
		luck: number?
	) -> boolean,
	hastenHatching: (player: Player) -> boolean,
	settleOffline: (player: Player) -> (),
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- Rebuilds the bay (which also sends the client its coins).
	refresh: (player: Player) -> (),
	-- Registers a strike target that is not a player, and reads the ability counters.
	addCreature: (creature: PvpService.Creature) -> (),
	getPvpUsage: () -> { [string]: { used: number, hit: number } },
	-- Daily quests: finish all of today's; give a fresh set as if a new day began.
	completeQuests: (player: Player) -> boolean,
	newQuestDay: (player: Player) -> boolean,
	-- Login gift: makes the last gift this many days old.
	shiftLoginDays: (player: Player, days: number) -> boolean,
	-- Index: a given alien counts as found, like a hatched one.
	discoverAlien: (player: Player, alienId: string) -> (),
	-- Server events: one right now (somewhere in a zone, if given), or back to quiet.
	activateEvent: (id: EventConfig.EventId, zone: ZoneConfig.ZoneId?) -> (),
	queueEvent: (id: EventConfig.EventId, seconds: number) -> (),
	stopEvent: (id: EventConfig.EventId) -> (),
	-- A hit on the star serpent as if `player` landed it; false when it cannot take one.
	hitSerpent: (player: Player, direction: Vector3) -> boolean,
	-- Holds the star serpent still at a point (nil lets it go); false when it is not out.
	holdSerpent: (position: Vector3?, facing: Vector3?) -> boolean,
	-- How long a player has done nothing, seconds (ActivityService).
	idleSeconds: (player: Player) -> number,
	-- Robux purchases: the receipt handler (fake receipts go through it), the egg to make ready
	-- now, and noting a pass as owned.
	processReceipt: (receipt: { [string]: any }) -> Enum.ProductPurchaseDecision,
	chooseReadyNowEgg: (player: Player, uid: number) -> string?,
	notePass: (player: Player, pass: Purchases.PassId) -> boolean,
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

-- Where the player aims: the camera direction their input context carries, or where the
-- character faces.
local function aimOf(player: Player, root: BasePart): Vector3
	local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
	local aim = (if context then FlightInputs.readAim(context) else nil) or root.CFrame.LookVector
	return if aim.Magnitude > 1e-3 then aim.Unit else root.CFrame.LookVector
end

function DevService.new(dependencies: Dependencies): DevService
	local infiniteOxygen = DevConfig.STUDIO_INFINITE_OXYGEN
	-- The last fake receipt SimulatePurchase sent, for ReplayLastReceipt.
	local lastReceipt: { [string]: any }? = nil

	local commands: { [string]: (...any) -> any } = {
		-- Floats an egg in front of the first player; it returns to `nestId` (default: the first
		-- nest of the Debris Belt) later.
		SpawnEggNearPlayer = function(rarity: string?, size: string?, nestId: string?, variant: string?): string
			local _, root = firstPlayerRoot()
			if not root then
				return "no character"
			end
			local chosenRarity = (rarity or "Common") :: EggConfig.RarityId
			local chosenSize = (size or EggConfig.TYPICAL_SIZE) :: EggConfig.SizeId
			local chosenVariant = (variant or "Normal") :: AlienConfig.VariantId
			assert(EggConfig.RARITIES[chosenRarity], `Unknown rarity {chosenRarity}`)
			assert(EggConfig.SIZES[chosenSize], `Unknown size {chosenSize}`)
			assert(AlienConfig.VARIANTS[chosenVariant], `Unknown variant {chosenVariant}`)
			-- Back to the nest when it expires only if the nest's own egg is away (Domain/NestCycle).
			dependencies.spawnLooseEgg({
				rarity = chosenRarity,
				size = chosenSize,
				nestId = nestId or "DebrisBeltNest1",
				variant = chosenVariant,
			}, root.Position + root.CFrame.LookVector * SPAWN_DISTANCE)
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
				return CFrame.lookAt(root.Position + aimOf(player, root) * studsAhead, root.Position)
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
			local function knockOut(direction: Vector3): boolean
				dependencies.spawnLooseEgg({
					rarity = chosenRarity,
					size = EggConfig.TYPICAL_SIZE,
					nestId = "DebrisBeltNest1",
					variant = "Normal",
				}, egg.Position, direction * EggConfig.DROP_SPEED)
				model:Destroy()
				return true
			end
			dependencies.addCreature({
				model = model,
				root = body,
				radius = 0,
				isCarrying = function()
					return true
				end,
				onHit = knockOut,
				onHarpoon = knockOut,
			})
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
		-- Starts a server event right now, with no warning; somewhere in `zone` if given.
		StartEvent = function(id: string, zone: string?): string
			assert(EventConfig.EVENTS[id :: EventConfig.EventId], `unknown event {id}`)
			assert(zone == nil or ZoneConfig.ZONES[zone :: ZoneConfig.ZoneId], `unknown zone {zone}`)
			dependencies.activateEvent(id :: EventConfig.EventId, zone :: ZoneConfig.ZoneId?)
			return `{id} started` .. (if zone then ` in {zone}` else "")
		end,
		-- Puts a server event on the clock to start in `seconds` (default 30), with its warning.
		QueueEvent = function(id: string, seconds: number?): string
			assert(EventConfig.EVENTS[id :: EventConfig.EventId], `unknown event {id}`)
			dependencies.queueEvent(id :: EventConfig.EventId, seconds or 30)
			return `{id} in {seconds or 30} s`
		end,
		-- Ends a server event now.
		StopEvent = function(id: string): string
			assert(EventConfig.EVENTS[id :: EventConfig.EventId], `unknown event {id}`)
			dependencies.stopEvent(id :: EventConfig.EventId)
			return `{id} stopped`
		end,
		-- `count` hits (default 1) on the star serpent, as if the first player landed them: the
		-- one that makes SerpentConfig.HITS_TO_DROP knocks the star egg out, flying away from them.
		HitSerpent = function(count: number?): string
			local player, root = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local world = workspace:FindFirstChild("World") or workspace
			local serpentModel = world:FindFirstChild(SerpentConfig.MODEL_NAME)
			local head = serpentModel and serpentModel:FindFirstChild(SerpentConfig.HEAD_NAME)
			if not head or not head:IsA("BasePart") then
				return "the serpent is not out"
			end
			local away = if root then head.Position - root.Position else Vector3.yAxis
			local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis
			local landed = 0
			for _ = 1, count or 1 do
				if not dependencies.hitSerpent(player, direction) then
					break
				end
				landed += 1
			end
			return `{landed} hit(s) landed`
		end,
		-- Brings the star serpent `studs` (default 30) ahead of the first player's aim and holds
		-- it still there, to try the strike, harpoon and bomb on it; false lets it go again.
		HoldSerpent = function(on: boolean?, studs: number?): string
			if on == false then
				return if dependencies.holdSerpent(nil, nil) then "serpent let go" else "the serpent is not out"
			end
			local player, root = firstPlayerRoot()
			if not player or not root then
				return "no character"
			end
			local aim = aimOf(player, root)
			local position = root.Position + aim * (studs or 30)
			if not dependencies.holdSerpent(position, aim) then
				return "the serpent is not out"
			end
			return "serpent held ahead"
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
		-- How long each player has done nothing, and whether that makes them away.
		ActivityStatus = function(): string
			local lines = {}
			for _, player in Players:GetPlayers() do
				local idle = dependencies.idleSeconds(player)
				local away = idle >= ActivityConfig.IDLE_SECONDS
				table.insert(lines, `{player.Name}: idle {math.floor(idle)}s{if away then " (away)" else ""}`)
			end
			return if #lines > 0 then table.concat(lines, " | ") else "no players"
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
		-- Gives the first player an alien of `grade` (guardian post number), `tier` and `variant`.
		GiveAlien = function(grade: number?, tier: string?, variant: string?): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local gradeConfig = assert(AlienConfig.GRADES[grade or 1], `Unknown grade {grade}`)
			local aliens = assert(
				gradeConfig.variants[(variant or "Normal") :: AlienConfig.VariantId],
				`Unknown variant {variant}`
			)
			local alienId = assert(aliens[(tier or "Common") :: AlienConfig.TierId], `Unknown tier {tier}`)
			local location = dependencies.addAlien(player, alienId)
			if location then
				dependencies.discoverAlien(player, alienId)
			end
			return if location then `{alienId} -> {location}` else "profile not active yet"
		end,
		-- Puts an egg into the first player's incubator, as if delivered from guardian `grade`
		-- (a meteor egg with `variant` "Meteor"), with extra `luck` if given (like the star egg:
		-- SerpentConfig.STAR_EGG_LUCK).
		GiveEgg = function(rarity: string?, size: string?, grade: number?, variant: string?, luck: number?): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local chosenRarity = (rarity or "Common") :: EggConfig.RarityId
			local chosenSize = (size or EggConfig.TYPICAL_SIZE) :: EggConfig.SizeId
			assert(EggConfig.RARITIES[chosenRarity], `Unknown rarity {chosenRarity}`)
			assert(EggConfig.SIZES[chosenSize], `Unknown size {chosenSize}`)
			local chosenVariant = (variant or "Normal") :: AlienConfig.VariantId
			assert(AlienConfig.VARIANTS[chosenVariant], `Unknown variant {chosenVariant}`)
			local added = dependencies.addEgg(player, chosenRarity, chosenSize, grade or 1, chosenVariant, luck)
			return if added then "egg in the incubator (or its queue)" else "profile not active yet"
		end,
		-- Sets the first player's incubator slots (1 to BayConfig.MAX_INCUBATOR_SLOTS), as if bought;
		-- waiting eggs move into the new ones.
		SetIncubatorSlots = function(slots: number): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local count = math.clamp(math.floor(slots), 1, BayConfig.MAX_INCUBATOR_SLOTS)
			local written = dependencies.update(player, function(data)
				data.incubatorSlots = count
				Bay.fillSlots(data, workspace:GetServerTimeNow())
			end)
			if written then
				dependencies.refresh(player)
			end
			return if written then `{count} incubator slots` else "profile not active yet"
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
		-- A Robux purchase without Robux: a fake receipt for the first player through the real
		-- receipt handler (so it is granted once and saved before it counts). `kind` is
		-- MonetizationConfig.ProductKind; `detail` the tier (ReadyNow, IncubatorSlot) or the
		-- seconds (Training); `uid` the egg to make ready now.
		SimulatePurchase = function(kind: string, detail: number?, uid: number?): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			local catalog = MonetizationConfig.catalogFor(game.GameId)
			if not catalog then
				return `no catalog for game {game.GameId}: publish the place first`
			end
			local productKind = kind :: MonetizationConfig.ProductKind
			local productId = if productKind == "Training"
				then MonetizationConfig.productIdOf(catalog, productKind, nil, detail)
				elseif productKind == "CollectDouble" then MonetizationConfig.productIdOf(catalog, productKind)
				else MonetizationConfig.productIdOf(catalog, productKind, detail)
			if not productId then
				return `no product {kind} {detail}`
			end
			if uid then
				local refused = dependencies.chooseReadyNowEgg(player, uid)
				if refused then
					return `egg {uid}: {refused}`
				end
			end
			local receipt = {
				PlayerId = player.UserId,
				ProductId = productId,
				PurchaseId = `dev-{HttpService:GenerateGUID(false)}`,
				CurrencySpent = 0,
			}
			lastReceipt = receipt
			local decision = dependencies.processReceipt(receipt)
			return `{kind} {detail or ""}: {decision.Name}`
		end,
		-- Sends the last SimulatePurchase receipt again, as Roblox does when it is not sure the
		-- game got it: the purchase must not be granted a second time.
		ReplayLastReceipt = function(): string
			if not lastReceipt then
				return "no receipt yet: SimulatePurchase first"
			end
			local decision = dependencies.processReceipt(lastReceipt)
			return `{lastReceipt.PurchaseId}: {decision.Name}`
		end,
		-- Notes a pass as owned by the first player (DoubleTraining or NightShift).
		GivePass = function(pass: string): string
			local player = firstPlayerRoot()
			if not player then
				return "no player"
			end
			assert(pass == "DoubleTraining" or pass == "NightShift", `Unknown pass {pass}`)
			return if dependencies.notePass(player, pass :: Purchases.PassId)
				then `{pass} noted`
				else `{pass} already noted or no profile`
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
				.. ` | slots {data.incubatorSlots}, waiting {#data.waiting}`
				.. ` | passes [{table.concat(data.passes, ", ")}] | receipts {#data.purchaseIds}`
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

		-- The same commands for the Studio MCP, whose code may not invoke a BindableFunction but
		-- may write a value: JSON {"id": "...", "command": "GiveEgg", "args": [...]} into
		-- REQUEST_NAME runs the command here and puts {"id", "ok", "result"} into RESULT_NAME.
		local request = Instance.new("StringValue")
		request.Name = REQUEST_NAME
		request.Parent = folder
		local result = Instance.new("StringValue")
		result.Name = RESULT_NAME
		result.Parent = folder
		request.Changed:Connect(function(raw)
			if raw == "" then
				return
			end
			local decoded, message = pcall(HttpService.JSONDecode, HttpService, raw)
			local call = if decoded then message else nil
			local id = if type(call) == "table" then call.id else nil
			local command = if type(call) == "table" then commands[call.command] else nil
			local ok, output
			if not command then
				ok, output = false, `unknown request {raw}`
			else
				local args = if type(call.args) == "table" then call.args else {}
				ok, output = pcall(command, table.unpack(args))
			end
			result.Value = HttpService:JSONEncode({ id = id, ok = ok, result = tostring(output) })
		end)

		folder.Parent = ServerStorage
	end

	return {
		name = "DevService",
		start = start,
	}
end

return table.freeze(DevService)
