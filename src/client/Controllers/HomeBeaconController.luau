--!strict
-- Keeps the way home in sight (decision 069): while the player is anywhere but on their own
-- island — in space, at the central station, on someone else's island — a "Your island" pin
-- (UI/ScreenPin) with the distance to its dome hangs over that dome, and waits at the screen edge
-- with an arrow when the island leaves the view. The island is the Player's `Island` attribute
-- (BayService). While the tutorial itself points home, its own pin says the same and this one
-- steps aside.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ScreenPin = require(script.Parent.Parent.UI.ScreenPin)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Zones = require(ReplicatedStorage.Shared.Domain.Zones)

local PLAYER_GUI_WAIT_TIMEOUT = 30

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
		-- The pin marks the top of the dome; the distance counts to the dome, where home begins.
		local top = island.domeCenter + Vector3.yAxis * island.domeRadius
		local distance = math.max(0, (root.Position - island.domeCenter).Magnitude - island.domeRadius)
		pin.place(camera, top, ScreenPin.distanceText(locale, distance))
	end

	local function start()
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
				color = Theme.OXYGEN,
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
