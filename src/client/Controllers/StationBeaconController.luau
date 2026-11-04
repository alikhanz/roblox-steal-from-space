--!strict
-- Keeps the way home in sight: while the player is out in space, a "Station" pin (UI/ScreenPin)
-- with the distance to the station border hangs over the dome, and waits at the screen edge
-- with an arrow when the station leaves the view. Recomputed every frame from the camera.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local ScreenPin = require(script.Parent.Parent.UI.ScreenPin)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The pin marks the top of the dome.
local BEACON_POINT = StationConfig.STATION.domeCenter + Vector3.yAxis * StationConfig.STATION.domeRadius

export type StationBeaconController = {
	name: string,
	start: () -> (),
}

local StationBeaconController = {}

function StationBeaconController.new(): StationBeaconController
	local pin = ScreenPin.new()

	local function update(locale: Text.Locale)
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not character or not root or not root:IsA("BasePart") then
			pin.hide()
			return
		end
		-- The distance counts to the station border, the line where a chase ends; inside it the
		-- station is right there and the pin is only in the way.
		local fromBorder = (root.Position - StationConfig.STATION.domeCenter).Magnitude - StationConfig.BORDER_RADIUS
		if character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) ~= true or fromBorder <= 0 then
			pin.hide()
			return
		end
		pin.place(camera, BEACON_POINT, ScreenPin.distanceText(locale, fromBorder))
	end

	local function start()
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[StationBeaconController] PlayerGui did not appear; no station beacon")
			return
		end
		Vide.mount(function()
			return pin.view({
				name = "StationBeacon",
				title = Text.get(locale, "station.beacon.title"),
				color = Theme.OXYGEN,
			})
		end, playerGui)
		RunService.RenderStepped:Connect(function()
			update(locale)
		end)
	end

	return {
		name = "StationBeaconController",
		start = start,
	}
end

return table.freeze(StationBeaconController)
