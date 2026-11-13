--!strict
-- The pets in the bays, built on this client only near it (decision 123). The server stands an
-- invisible box for each pet (World/AlienModel, tag BayConfig.ALIEN_TAG) with what to build there;
-- here the pet is built in its box from the models the server shared (World/PetTemplate, the same
-- way the server measured the box), its effects made (AlienDress.adornLocally), and it is handed to
-- AlienMotionController to move. One standing small on the floor (BayConfig.ALIEN_PLAIN_ATTRIBUTE)
-- is only its model: no effects, no motion.
--
-- Which ones, and how (Domain/PetView, AlienLooks.VIEW): an island's pets whole while the camera is
-- near the island; plain (body and outfit standing still, as a shelf pet) on the two islands
-- nearest after it, so the neighbours do not stand empty. An island left with neither is hidden,
-- not taken apart, and comes back at once if the camera returns within a minute; a few islands at
-- most are held so, the longest hidden going first. A phone was sent every pet on the map, about a
-- hundred objects each with its effects (2026-11-13).
--
-- In what order (decision 102, Loading/AssetQueue): a pet is built only once the models it is
-- built from are in, and they are asked for an island at a time, one preload each: the player's
-- own island first, then other islands shown whole, then the plain ones (LoadConfig.PRIORITY). So
-- at the join the own island comes in whole, then its neighbours plain; a neighbour's meshes are
-- in before the player flies over, and making its pets whole there is only their effects. One
-- preload a pet, queued one after another, had an island's meshes in only seconds after the
-- player arrived (user, 2026-11-14).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienDress = require(ReplicatedStorage.Shared.World.AlienDress)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local AlienMotionController = require(script.Parent.AlienMotionController)
local AlienOutfit = require(ReplicatedStorage.Shared.Domain.AlienOutfit)
local AssetQueue = require(script.Parent.Parent.Loading.AssetQueue)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local LoadConfig = require(ReplicatedStorage.Shared.Config.LoadConfig)
local PetTemplate = require(ReplicatedStorage.Shared.World.PetTemplate)
local PetView = require(ReplicatedStorage.Shared.Domain.PetView)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

local VIEW = AlienLooks.VIEW
-- What a built pet is called in its box.
local LOOK_NAME = "Look"

local CENTRES: { Vector3 } = {}
for index, frame in StationConfig.ISLAND_FRAMES do
	CENTRES[index] = frame.Position
end

export type Dependencies = {
	motion: AlienMotionController.AlienMotionController,
}

export type AlienViewController = {
	name: string,
	start: () -> (),
}

-- A pet's box on this client, and the pet built in it.
type Entry = {
	stand: Model,
	island: number,
	look: Model?,
	-- How the built pet is shown (a shelf pet is only ever plain, whatever its island's level).
	level: PetView.Level?,
	-- A pet standing still follows its box when the layout moves it (a moving pet glides on its own).
	follow: RBXScriptConnection?,
	-- Its box names nothing this build can make: not tried again.
	broken: boolean,
}

local AlienViewController = {}

-- The models the server shared with the clients, by name.
local function sharedModel(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild(VIEW.FOLDER)
	return folder and folder:FindFirstChild(name)
end

-- Whether a pet's box stands in the local player's own bay (its tagged bay model's owner).
local function isOwnPet(stand: Instance): boolean
	local at = stand.Parent
	while at and at ~= workspace do
		if CollectionService:HasTag(at, BayConfig.TAG) then
			return at:GetAttribute(BayConfig.OWNER_ID_ATTRIBUTE) == Players.LocalPlayer.UserId
		end
		at = at.Parent
	end
	return false
end

function AlienViewController.new(dependencies: Dependencies): AlienViewController
	local motion = dependencies.motion
	local templates = PetTemplate.cache(sharedModel, false)
	local entries: { [Model]: Entry } = {}
	-- How each island's pets are shown (none: not shown), and the islands whose pets are hidden
	-- for a while (since when).
	local levels: { [number]: PetView.Level } = {}
	local heldSince: { [number]: number } = {}
	-- Boxes on shown islands whose pet is missing or not shown as its island is, the nearest first
	-- (renewed at every check).
	local queue: { Entry } = {}
	-- The shared models asked for (AssetQueue), and those whose assets are in, by name.
	local asked: { [string]: boolean } = {}
	local loaded: { [string]: boolean } = {}
	-- The meteor pets' lava skin goes with the first models asked for.
	local skinsAsked = false

	local function isPlain(entry: Entry): boolean
		return entry.stand:GetAttribute(BayConfig.ALIEN_PLAIN_ATTRIBUTE) == true
	end

	-- How `entry`'s pet should be shown now: its island's level, plain for a shelf pet.
	local function wanted(entry: Entry): PetView.Level?
		local level = levels[entry.island]
		if level and isPlain(entry) then
			return "Plain"
		end
		return level
	end

	local function unfollow(entry: Entry)
		local connection = entry.follow
		if connection then
			connection:Disconnect()
			entry.follow = nil
		end
	end

	local function takeApart(entry: Entry)
		local look = entry.look
		if look then
			motion.untrack(look)
			look:Destroy()
			entry.look = nil
			entry.level = nil
		end
		unfollow(entry)
	end

	-- `look` standing still follows `entry`'s box.
	local function follow(entry: Entry, look: Model)
		local stand = entry.stand
		entry.follow = stand:GetAttributeChangedSignal(BayConfig.ALIEN_PIVOT_ATTRIBUTE):Connect(function()
			local moved = stand:GetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE)
			if typeof(moved) == "CFrame" then
				look:PivotTo(moved)
			end
		end)
	end

	-- Makes `entry`'s plain pet whole where it stands: its effects, and its motion from now on.
	local function makeWhole(entry: Entry, look: Model)
		unfollow(entry)
		AlienDress.adornLocally(look)
		motion.track(look, entry.stand)
		entry.level = "Whole"
	end

	-- Builds `entry`'s pet as `level`, in place of the one there (a whole pet made plain is built
	-- afresh: its effects and motion are not taken off one by one). False while the server's models
	-- have not come yet (tried again at the next check).
	local function build(entry: Entry, level: PetView.Level): boolean
		local stand = entry.stand
		local alienId = stand:GetAttribute(BayConfig.ALIEN_ID_ATTRIBUTE)
		local alien = if type(alienId) == "string" then AlienConfig.ALIENS[alienId] else nil
		local scale = stand:GetAttribute(VIEW.SCALE_ATTRIBUTE)
		local pivot = stand:GetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE)
		local key = stand:GetAttribute(VIEW.OUTFIT_ATTRIBUTE)
		if not alien or type(scale) ~= "number" or typeof(pivot) ~= "CFrame" then
			entry.broken = true
			warn(`[AlienViewController] {stand:GetFullName()} names no pet this build can make; not shown`)
			return true
		end
		local outfit = AlienOutfit.fromKey(if type(key) == "string" then key else "")
		local template = PetTemplate.get(templates, alien, outfit)
		if not template then
			return false
		end
		local look = PetTemplate.build(templates, template, alien, scale, pivot)
		look.Name = LOOK_NAME
		takeApart(entry)
		look.Parent = stand
		entry.look = look
		entry.level = "Plain"
		follow(entry, look)
		if level == "Whole" then
			makeWhole(entry, look)
		end
		return true
	end

	-- Brings `entry`'s pet to how it should be shown. False while it cannot be built yet.
	local function bring(entry: Entry): boolean
		local level = wanted(entry)
		local look = entry.look
		if not level or entry.level == level then
			return true
		end
		if look and level == "Whole" then
			makeWhole(entry, look)
			return true
		end
		return build(entry, level)
	end

	-- Shows or hides the pets built on `island` (hidden: out of the world, kept as they are).
	local function showIsland(island: number, visible: boolean)
		for _, entry in entries do
			local look = entry.look
			if entry.island == island and look then
				look.Parent = if visible then entry.stand else nil
			end
		end
	end

	local function dropIsland(island: number)
		for _, entry in entries do
			if entry.island == island then
				takeApart(entry)
			end
		end
	end

	-- The names of the shared models `entry`'s pet is built from, nil while they have not come.
	local function sourcesOf(entry: Entry): { string }?
		local alienId = entry.stand:GetAttribute(BayConfig.ALIEN_ID_ATTRIBUTE)
		local alien = if type(alienId) == "string" then AlienConfig.ALIENS[alienId] else nil
		if not alien then
			entry.broken = true
			warn(`[AlienViewController] {entry.stand:GetFullName()} names no pet this build can make; not shown`)
			return nil
		end
		return PetTemplate.sources(templates, alien)
	end

	local function isLoaded(entry: Entry): boolean
		local names = sourcesOf(entry)
		if not names then
			return false
		end
		for _, name in names do
			if not loaded[name] then
				return false
			end
		end
		return true
	end

	local function needsWork(entry: Entry): boolean
		if entry.broken or entries[entry.stand] ~= entry then
			return false
		end
		local level = wanted(entry)
		if level == nil or entry.level == level then
			return false
		end
		-- A plain pet made whole is only its effects; anything built needs its models in.
		return (entry.look ~= nil and level == "Whole") or isLoaded(entry)
	end

	-- Asks for the models of the pets to be shown that have not been asked for yet: one preload
	-- for each priority (LoadConfig.PRIORITY), the own island's first.
	local function askForModels()
		local byPriority: { [number]: { string } } = {}
		for _, entry in entries do
			local level = levels[entry.island]
			if entry.broken or not level then
				continue
			end
			local names = sourcesOf(entry)
			if not names then
				continue
			end
			local priority = if level == "Plain"
				then LoadConfig.PRIORITY.PLAIN_PETS
				elseif isOwnPet(entry.stand) then LoadConfig.PRIORITY.OWN_PETS
				else LoadConfig.PRIORITY.PETS
			for _, name in names do
				if not asked[name] then
					asked[name] = true
					local list = byPriority[priority] or {}
					byPriority[priority] = list
					table.insert(list, name)
				end
			end
		end
		for priority, names in byPriority do
			local assets: { AssetQueue.Asset } = {}
			for _, name in names do
				local model = sharedModel(name)
				if model then
					table.insert(assets, model)
				end
			end
			local skins = ReplicatedStorage:FindFirstChild(AlienLooks.MODELS.SKINS_FOLDER)
			if not skinsAsked and skins then
				skinsAsked = true
				table.insert(assets, skins)
			end
			AssetQueue.later(`pet models ({#names})`, priority, assets, function()
				for _, name in names do
					loaded[name] = true
				end
			end)
		end
	end

	-- Where the camera was at the last check, and when.
	local lastEye = Vector3.zero
	local lastCheck = 0

	local function check()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local now = os.clock()
		local ahead = PetView.ahead(eye, lastEye, now - lastCheck, VIEW.LEAD_SECONDS, VIEW.LEAD_MAX_SPEED)
		lastEye, lastCheck = eye, now
		local fromCentres: { number } = {}
		for island, centre in CENTRES do
			fromCentres[island] = math.min((eye - centre).Magnitude, (ahead - centre).Magnitude)
		end
		local was = levels
		levels = PetView.levels(fromCentres, was, VIEW)
		for island in CENTRES do
			local isShown = levels[island] ~= nil
			if isShown ~= (was[island] ~= nil) then
				if isShown then
					heldSince[island] = nil
				else
					heldSince[island] = now
				end
				showIsland(island, isShown)
			end
		end
		for _, island in PetView.toDrop(heldSince, now, VIEW.HOLD_SECONDS, VIEW.HOLD_ISLANDS) do
			heldSince[island] = nil
			dropIsland(island)
		end
		askForModels()
		local waiting: { Entry } = {}
		local distances: { [Entry]: number } = {}
		for _, entry in entries do
			if needsWork(entry) then
				table.insert(waiting, entry)
				distances[entry] = (entry.stand:GetPivot().Position - eye).Magnitude
			end
		end
		table.sort(waiting, function(a, b)
			return distances[a] < distances[b]
		end)
		queue = waiting
	end

	-- Brings the nearest waiting pets to how they should be shown, a few a frame.
	local function buildSome()
		local built, madeWhole = 0, 0
		while built < VIEW.BUILDS_PER_FRAME and madeWhole < VIEW.WHOLE_PER_FRAME and #queue > 0 do
			local entry = table.remove(queue, 1) :: Entry
			if needsWork(entry) then
				local upgrade = entry.look ~= nil and wanted(entry) == "Whole"
				if bring(entry) then
					if upgrade then
						madeWhole += 1
					else
						built += 1
					end
				end
			end
		end
	end

	local function watch(instance: Instance)
		if not (instance:IsA("Model") and instance:GetAttribute(VIEW.LOOK_ATTRIBUTE) == true) then
			-- The greybox blob: the server's whole.
			return
		end
		if entries[instance] then
			return
		end
		local pivot = instance:GetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE)
		local at = if typeof(pivot) == "CFrame" then pivot.Position else instance:GetPivot().Position
		local entry: Entry = {
			stand = instance,
			island = PetView.nearest(at, CENTRES),
			look = nil,
			level = nil,
			follow = nil,
			broken = false,
		}
		entries[instance] = entry
		-- A new pet on a shown island (just hatched): at once, ahead of the rest.
		if levels[entry.island] then
			table.insert(queue, 1, entry)
		end
	end

	local function forget(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		local entry = entries[instance]
		if entry then
			entries[instance] = nil
			takeApart(entry)
		end
	end

	local function start()
		for _, instance in CollectionService:GetTagged(BayConfig.ALIEN_TAG) do
			watch(instance)
		end
		CollectionService:GetInstanceAddedSignal(BayConfig.ALIEN_TAG):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(BayConfig.ALIEN_TAG):Connect(forget)
		local sinceCheck = math.huge
		RunService.Heartbeat:Connect(function(dt: number)
			sinceCheck += dt
			if sinceCheck >= VIEW.CHECK_SECONDS then
				sinceCheck = 0
				check()
			end
			buildSome()
		end)
	end

	return {
		name = "AlienViewController",
		start = start,
	}
end

return table.freeze(AlienViewController)
