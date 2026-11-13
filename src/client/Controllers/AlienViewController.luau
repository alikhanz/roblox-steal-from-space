--!strict
-- The pets in the bays, built on this client only near it (decision 123). The server stands an
-- invisible box for each pet (World/AlienModel, tag BayConfig.ALIEN_TAG) with what to build there;
-- here the pet is built in its box from the models the server shared (World/PetTemplate, the same
-- way the server measured the box), its effects made (AlienDress.adornLocally), and it is handed to
-- AlienMotionController to move. One standing small on the floor (BayConfig.ALIEN_PLAIN_ATTRIBUTE)
-- is only its model: no effects, no motion.
--
-- Which ones (Domain/PetView, AlienLooks.VIEW): an island's pets while the camera is near the
-- island. When it flies off they are hidden, not taken apart, and come back at once if it returns
-- within a minute; a few islands at most are held so, the longest hidden going first. A phone was
-- sent every pet on the map, about a hundred objects each with its effects (2026-11-13).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienDress = require(ReplicatedStorage.Shared.World.AlienDress)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local AlienMotionController = require(script.Parent.AlienMotionController)
local AlienOutfit = require(ReplicatedStorage.Shared.Domain.AlienOutfit)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
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
	-- A shelf pet's model follows its box when the layout moves it (a moving pet glides on its own).
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

function AlienViewController.new(dependencies: Dependencies): AlienViewController
	local motion = dependencies.motion
	local templates = PetTemplate.cache(sharedModel, false)
	local entries: { [Model]: Entry } = {}
	-- Islands whose pets are shown, and those whose pets are hidden for a while (since when).
	local shown: { [number]: boolean } = {}
	local heldSince: { [number]: number } = {}
	-- Boxes on shown islands with no pet yet, the nearest first (renewed at every check).
	local queue: { Entry } = {}

	local function takeApart(entry: Entry)
		local look = entry.look
		if look then
			motion.untrack(look)
			look:Destroy()
			entry.look = nil
		end
		local follow = entry.follow
		if follow then
			follow:Disconnect()
			entry.follow = nil
		end
	end

	-- Builds the pet in `entry`'s box. False while the server's models have not come yet (tried
	-- again at the next check).
	local function build(entry: Entry): boolean
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
		local plain = stand:GetAttribute(BayConfig.ALIEN_PLAIN_ATTRIBUTE) == true
		if not plain then
			AlienDress.adornLocally(look)
		end
		look.Parent = stand
		entry.look = look
		if plain then
			entry.follow = stand:GetAttributeChangedSignal(BayConfig.ALIEN_PIVOT_ATTRIBUTE):Connect(function()
				local moved = stand:GetAttribute(BayConfig.ALIEN_PIVOT_ATTRIBUTE)
				if typeof(moved) == "CFrame" then
					look:PivotTo(moved)
				end
			end)
		else
			motion.track(look, stand)
		end
		return true
	end

	-- Shows or hides the pets built on `island` (hidden: out of the world, kept whole).
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

	local function needsBuilding(entry: Entry): boolean
		return entry.look == nil and not entry.broken and shown[entry.island] == true and entries[entry.stand] == entry
	end

	local function check()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local now = os.clock()
		for island, centre in CENTRES do
			local was = shown[island] == true
			local isShown = PetView.shows((eye - centre).Magnitude, was, VIEW.REACH, VIEW.MARGIN)
			if isShown ~= was then
				shown[island] = isShown
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
		local waiting: { Entry } = {}
		local distances: { [Entry]: number } = {}
		for _, entry in entries do
			if needsBuilding(entry) then
				table.insert(waiting, entry)
				distances[entry] = (entry.stand:GetPivot().Position - eye).Magnitude
			end
		end
		table.sort(waiting, function(a, b)
			return distances[a] < distances[b]
		end)
		queue = waiting
	end

	-- Builds the nearest waiting pets, a few a frame.
	local function buildSome()
		local built = 0
		while built < VIEW.BUILDS_PER_FRAME and #queue > 0 do
			local entry = table.remove(queue, 1) :: Entry
			if needsBuilding(entry) then
				if build(entry) then
					built += 1
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
			follow = nil,
			broken = false,
		}
		entries[instance] = entry
		-- A new pet on a shown island (just hatched): at once, ahead of the rest.
		if shown[entry.island] then
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
