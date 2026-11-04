--!strict
-- Keeps the way home in sight: while the player is out in space, a "Station" sign with the
-- distance hangs over the dome, and when the station leaves the view it waits at the screen
-- edge with an arrow pointing to it. Recomputed every frame from the camera.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local ScreenMarker = require(ReplicatedStorage.Shared.Domain.ScreenMarker)
local StationBeacon = require(script.Parent.Parent.UI.StationBeacon)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The sign marks the top of the dome.
local BEACON_POINT = StationConfig.STATION.domeCenter + Vector3.yAxis * StationConfig.STATION.domeRadius
-- Distance of the arrow from the screen edge, pixels.
local EDGE_MARGIN = 40
-- The sign stands this far inwards from the arrow, pixels.
local SIGN_FROM_ARROW = 56
-- While the dome is in view the sign floats this far above its top, pixels.
local SIGN_ABOVE_DOME = 30
-- Right next to the dome the sign is only in the way, studs from its surface.
local HIDE_WITHIN = 30
-- The distance shown is rounded to this many studs, so it does not flicker.
local DISTANCE_STEP = 10

export type StationBeaconController = {
	name: string,
	start: () -> (),
}

local StationBeaconController = {}

function StationBeaconController.new(): StationBeaconController
	local visible = source(false)
	local distance = source("")
	local signPosition = source(Vector2.zero)
	local arrowVisible = source(false)
	local arrowPosition = source(Vector2.zero)
	local arrowAngle = source(0)

	local function update(locale: Text.Locale)
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not character or not root or not root:IsA("BasePart") then
			visible(false)
			return
		end
		local station = StationConfig.STATION
		local fromDome = (root.Position - station.domeCenter).Magnitude - station.domeRadius
		if character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) ~= true or fromDome < HIDE_WITHIN then
			visible(false)
			return
		end
		visible(true)

		local shown = math.floor(fromDome / DISTANCE_STEP + 0.5) * DISTANCE_STEP
		local text = Text.get(locale, "station.distance.hint", { distance = shown })
		if text ~= distance() then
			distance(text)
		end

		local point = camera:WorldToViewportPoint(BEACON_POINT)
		local viewport = camera.ViewportSize
		local placement = ScreenMarker.place(point.X, point.Y, point.Z, {
			width = viewport.X,
			height = viewport.Y,
			margin = EDGE_MARGIN,
		})
		local position = Vector2.new(placement.x, placement.y)
		arrowVisible(not placement.onScreen)
		if placement.onScreen then
			signPosition(position - Vector2.new(0, SIGN_ABOVE_DOME))
		else
			local radians = math.rad(placement.angle)
			local towards = Vector2.new(math.cos(radians), math.sin(radians))
			arrowPosition(position)
			arrowAngle(placement.angle)
			signPosition(position - towards * SIGN_FROM_ARROW)
		end
	end

	local function start()
		local locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[StationBeaconController] PlayerGui did not appear; no station beacon")
			return
		end
		Vide.mount(function()
			return StationBeacon({
				title = Text.get(locale, "station.beacon.title"),
				distance = distance,
				visible = visible,
				signPosition = signPosition,
				arrowVisible = arrowVisible,
				arrowPosition = arrowPosition,
				arrowAngle = arrowAngle,
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
