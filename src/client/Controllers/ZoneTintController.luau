--!strict
-- The zone's tint on screen (docs/plans/ZONES.md, step 4): flying out, the picture takes on the
-- colour of the zone around the camera (ZoneLooks.TINTS) — cold in the Ice Rings, warm in the Red
-- Nebula. Across the gap between two zones one tint turns into the next (Domain/ZoneBlend); at the
-- station there is none. Only this client's picture: a ColorCorrectionEffect of its own.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local ZoneBlend = require(ReplicatedStorage.Shared.Domain.ZoneBlend)
local ZoneLooks = require(ReplicatedStorage.Shared.Config.ZoneLooks)

export type ZoneTintController = {
	name: string,
	start: () -> (),
}

local EFFECT_NAME = "ZoneTint"

type Grade = { color: Vector3, saturation: number, contrast: number, brightness: number }

local NONE: Grade = { color = Vector3.one, saturation = 0, contrast = 0, brightness = 0 }

local function gradeOf(tint: ZoneLooks.Tint): Grade
	return {
		color = Vector3.new(tint.color.R, tint.color.G, tint.color.B),
		saturation = tint.saturation,
		contrast = tint.contrast,
		brightness = tint.brightness,
	}
end

local function mix(a: Grade, b: Grade, t: number): Grade
	return {
		color = a.color:Lerp(b.color, t),
		saturation = a.saturation + (b.saturation - a.saturation) * t,
		contrast = a.contrast + (b.contrast - a.contrast) * t,
		brightness = a.brightness + (b.brightness - a.brightness) * t,
	}
end

-- The tint for a camera at `position`.
local function gradeAt(position: Vector3): Grade
	local offset = position - StationConfig.PLATFORM_CENTER
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local blend = ZoneBlend.at(distance)
	local zone = mix(gradeOf(ZoneLooks.TINTS[blend.inner]), gradeOf(ZoneLooks.TINTS[blend.outer]), blend.t)
	return mix(NONE, zone, ZoneBlend.presence(distance, StationConfig.BORDER_RADIUS))
end

local ZoneTintController = {}

function ZoneTintController.new(): ZoneTintController
	local function start()
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = EFFECT_NAME
		effect.Parent = Lighting
		local current: Grade? = nil

		RunService.RenderStepped:Connect(function(dt)
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local goal = gradeAt(camera.CFrame.Position)
			local now = if current then mix(current, goal, 1 - math.exp(-ZoneLooks.TINT_RESPONSE * dt)) else goal
			current = now
			effect.TintColor = Color3.new(now.color.X, now.color.Y, now.color.Z)
			effect.Saturation = now.saturation
			effect.Contrast = now.contrast
			effect.Brightness = now.brightness
		end)
	end

	return {
		name = "ZoneTintController",
		start = start,
	}
end

return ZoneTintController
