--!strict
-- Keeps the way home in sight (decision 069): while the player is anywhere but on their own
-- island — in space, at the central station, on someone else's island — a "Your island" pin
-- (UI/ScreenPin) with the distance to its dome hangs over the middle of the island's floor (it
-- hung on the dome's top, 250 studs up: docs/design/screens/markers.md), and waits at the screen
-- edge with an arrow when the island leaves the view. The island is the Player's `Island`
-- attribute (BayService). While the tutorial itself points home, its own pin says the same and
-- this one steps aside.
--
-- The player's own island also wears the home colour, on this client only (the others see theirs
-- so), so it stands out of the eight at a glance and from across the map: a thicker rim and a
-- smooth tinted dome (StationLooks.HOME_ISLAND).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RadarConfig = require(ReplicatedStorage.Shared.Config.RadarConfig)
local ScreenPin = require(script.Parent.Parent.UI.ScreenPin)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Zones = require(ReplicatedStorage.Shared.Domain.Zones)

local PLAYER_GUI_WAIT_TIMEOUT = 30
local ISLAND_WAIT_TIMEOUT = 30
-- WorldService builds each island in workspace.World as `Island<index>`, with these glowing parts.
local WORLD_FOLDER_NAME = "World"
local RIM_NAME = "Rim"
local DOME_NAME = "Dome"

export type Dependencies = {
	-- True while the tutorial's own pin leads to the player's island.
	tutorialPointsHome: () -> boolean,
}

export type HomeBeaconController = {
	name: string,
	start: () -> (),
}

local HomeBeaconController = {}

function HomeBeaconController.new(dependencies: Dependencies): HomeBeaconController
	local pin = ScreenPin.new()

	local function update(locale: Text.Locale)
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local index = Players.LocalPlayer:GetAttribute(StandConfig.ISLAND_ATTRIBUTE)
		local island = if type(index) == "number" then StationConfig.ISLANDS[index] else nil
		if
			not camera
			or not island
			or not root
			or not root:IsA("BasePart")
			or Zones.isInStation(root.Position, island)
			or dependencies.tutorialPointsHome()
		then
			pin.hide()
			return
		end
		-- The pin stands over the floor, where to land; the distance counts to the dome, where
		-- home begins.
		local point = island.platformCenter + Vector3.yAxis * RadarConfig.HOME_PIN_HEIGHT
		local distance = math.max(0, (root.Position - island.domeCenter).Magnitude - island.domeRadius)
		pin.place(camera, point, ScreenPin.distanceText(locale, distance))
	end

	-- The home island's rim and dome in the home look; each part keeps its own look to give back
	-- if the island changes. Parts stream in and out: each one that arrives is painted.
	type Look = {
		color: Color3,
		material: Enum.Material,
		transparency: number,
		size: Vector3,
		cframe: CFrame,
	}
	local painted: { [BasePart]: Look } = {}
	local islandConnections: { RBXScriptConnection } = {}
	local paintedIndex: number? = nil

	local function unpaint()
		for _, connection in islandConnections do
			connection:Disconnect()
		end
		table.clear(islandConnections)
		for part, look in painted do
			part.Color = look.color
			part.Material = look.material
			part.Transparency = look.transparency
			part.Size = look.size
			part.CFrame = look.cframe
		end
		table.clear(painted)
	end

	local function paint(index: number)
		local world = workspace:WaitForChild(WORLD_FOLDER_NAME, ISLAND_WAIT_TIMEOUT)
		local folder = world and world:WaitForChild(`Island{index}`, ISLAND_WAIT_TIMEOUT)
		if not folder then
			warn(`[HomeBeaconController] Island {index} did not appear; it keeps its usual colour`)
			return
		end
		if paintedIndex ~= index then
			-- The island changed while this one was waiting.
			return
		end
		local looks = StationLooks.HOME_ISLAND
		local function apply(child: Instance)
			if not child:IsA("BasePart") or painted[child] then
				return
			end
			local isRim, isDome = child.Name == RIM_NAME, child.Name == DOME_NAME
			if not isRim and not isDome then
				return
			end
			painted[child] = {
				color = child.Color,
				material = child.Material,
				transparency = child.Transparency,
				size = child.Size,
				cframe = child.CFrame,
			}
			child.Color = Theme.NEON.HOME
			if isRim then
				-- Its top stays where it was, under the floor's edge; it grows down and out.
				child.Size += looks.rimGrowth
				child.CFrame -= Vector3.yAxis * looks.rimGrowth.X / 2
			else
				child.Material = looks.domeMaterial
				child.Transparency = looks.domeTransparency
			end
		end
		for _, child in folder:GetChildren() do
			apply(child)
		end
		table.insert(islandConnections, folder.ChildAdded:Connect(apply))
		table.insert(
			islandConnections,
			folder.ChildRemoved:Connect(function(child)
				painted[child :: BasePart] = nil
			end)
		)
	end

	local function watchIsland()
		local index = Players.LocalPlayer:GetAttribute(StandConfig.ISLAND_ATTRIBUTE)
		local island = if type(index) == "number" and StationConfig.ISLANDS[index] then index else nil
		if island == paintedIndex then
			return
		end
		unpaint()
		paintedIndex = island
		if island then
			task.spawn(paint, island)
		end
	end

	local function start()
		Players.LocalPlayer:GetAttributeChangedSignal(StandConfig.ISLAND_ATTRIBUTE):Connect(watchIsland)
		watchIsland()
		local locale = Text.localeOf(Players.LocalPlayer)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[HomeBeaconController] PlayerGui did not appear; no home beacon")
			return
		end
		Vide.mount(function()
			return pin.view({
				name = "HomeBeacon",
				title = Text.get(locale, "island.beacon.title"),
				color = Theme.NEON.HOME,
				icon = "Home",
			})
		end, playerGui)
		RunService.RenderStepped:Connect(function()
			update(locale)
		end)
	end

	return {
		name = "HomeBeaconController",
		start = start,
	}
end

return table.freeze(HomeBeaconController)
