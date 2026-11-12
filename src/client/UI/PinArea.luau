--!strict
-- Where markers at the screen edge may stand (docs/design/screens/markers.md): inside the device's
-- safe area (notch, rounded corners) and under Roblox's top bar, and off the HUD — the left column,
-- the bottom stack and the flight buttons. A marker pinned onto the HUD steps back towards the
-- crosshair along its own direction (Domain/ScreenMarker.placeIn). In viewport pixels, the space
-- Camera:WorldToViewportPoint gives.
--
-- The safe area is read from a probe: an empty ScreenGui with ScreenInsets = DeviceSafeInsets,
-- made on first use. The HUD's blocks are found by name in PlayerGui.Hud; one that is missing or
-- hidden keeps nothing out.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScreenMarker = require(ReplicatedStorage.Shared.Domain.ScreenMarker)

-- Distance of edge markers from the safe area's sides, pixels.
local EDGE_MARGIN = 40
-- Room kept round each HUD block, pixels: an arrow stands this far off it.
local KEEP_OUT_PADDING = 18
-- A marker steps back off the HUD at most to this share of the way from the crosshair to the edge.
local MIN_REACH = 0.35
local PROBE_NAME = "PinAreaProbe"
local HUD_NAME = "Hud"
-- HudController's and FlightButtons' blocks (docs/design/screens/hud.md).
local HUD_BLOCKS = { "Stats", "BottomStack", "FlightButtons" }

local PinArea = {}

local function probe(playerGui: PlayerGui): Frame?
	local gui = playerGui:FindFirstChild(PROBE_NAME)
	if not gui then
		local screen = Instance.new("ScreenGui")
		screen.Name = PROBE_NAME
		screen.ResetOnSpawn = false
		screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		local frame = Instance.new("Frame")
		frame.Name = "Safe"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Parent = screen
		screen.Parent = playerGui
		gui = screen
	end
	local frame = (gui :: Instance):FindFirstChild("Safe")
	return if frame and frame:IsA("Frame") then frame else nil
end

-- A GuiObject's rectangle in viewport pixels, grown by `padding`. AbsolutePosition counts from
-- under the top bar inset; the viewport, from the screen's corner.
local function rectOf(object: GuiObject, inset: Vector2, padding: number): ScreenMarker.Rect
	local position = object.AbsolutePosition + inset
	local size = object.AbsoluteSize
	return {
		left = position.X - padding,
		top = position.Y - padding,
		right = position.X + size.X + padding,
		bottom = position.Y + size.Y + padding,
	}
end

local function hudBlocks(playerGui: PlayerGui, inset: Vector2): { ScreenMarker.Rect }
	local blocks: { ScreenMarker.Rect } = {}
	local hud = playerGui:FindFirstChild(HUD_NAME)
	if not hud or not hud:IsA("ScreenGui") or not hud.Enabled then
		return blocks
	end
	for _, name in HUD_BLOCKS do
		local block = hud:FindFirstChild(name)
		if block and block:IsA("GuiObject") and block.Visible and block.AbsoluteSize.Magnitude > 0 then
			table.insert(blocks, rectOf(block, inset, KEEP_OUT_PADDING))
		end
	end
	return blocks
end

-- The area for this frame.
function PinArea.of(camera: Camera): ScreenMarker.Area
	local viewport = camera.ViewportSize
	local inset = GuiService:GetGuiInset()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local safe: ScreenMarker.Rect = { left = 0, top = 0, right = viewport.X, bottom = viewport.Y }
	local keepOut: { ScreenMarker.Rect } = {}
	if playerGui then
		local frame = probe(playerGui)
		if frame and frame.AbsoluteSize.Magnitude > 0 then
			safe = rectOf(frame, inset, 0)
		end
		keepOut = hudBlocks(playerGui, inset)
	end
	return {
		centerX = viewport.X / 2,
		centerY = viewport.Y / 2,
		bounds = {
			left = safe.left + EDGE_MARGIN,
			-- Under Roblox's buttons.
			top = math.max(safe.top, inset.Y) + EDGE_MARGIN,
			right = safe.right - EDGE_MARGIN,
			bottom = safe.bottom - EDGE_MARGIN,
		},
		keepOut = keepOut,
		minReach = MIN_REACH,
	}
end

return table.freeze(PinArea)
