--!strict
-- Makes nest eggs easy to find and tell apart from afar in flight (user, 2026-11-10: "яйца плохо
-- видно во время полёта, их не отличить издали"; "красиво, чтобы детишки радовались"): over every
-- nest holding an egg of uncommon rarity or rarer stands a beacon in the rarity's colour —
--   * a column of light, a coloured glow round a bright core, fading upwards, taller the rarer
--     the egg; it is a few pixels wide on top of its width in studs, so far off it stays visible
--     instead of thinning to nothing (Beams did, and vanished in flight);
--   * an egg badge of a fixed size on screen just over the egg, in a soft glow, larger the rarer
--     the egg, seen through rocks; the rarest pulse gently.
-- A common egg gets none: no beacon reads as common. Looks in EggLooks.RARITIES[…].beacon and
-- EggLooks.BEACON.
--
-- Built from the nest's own attributes (HasEgg, Rarity, EggPosition), on this client only: two
-- BillboardGuis a nest on one Attachment, no particles, nothing over the network. The egg itself
-- may not be streamed in; the nest's attributes are.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local Icons = require(script.Parent.Parent.UI.Icons)

export type EggBeaconController = {
	name: string,
	start: () -> (),
}

type Beacon = {
	foot: Attachment,
	column: BillboardGui,
	glow: Frame,
	core: Frame,
	badge: BillboardGui,
	halo: ImageLabel,
	-- What is shown now; nil while the beacon is off.
	spec: EggLooks.BeaconLook?,
	connections: { RBXScriptConnection },
}

local EggBeaconController = {}

local function billboard(name: string, foot: Attachment, onTop: boolean): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.AlwaysOnTop = onTop
	gui.LightInfluence = 0
	gui.MaxDistance = EggLooks.BEACON.badgeDistance
	gui.Adornee = foot
	-- Parented to its attachment, so it lives and dies with the beacon.
	gui.Parent = foot
	return gui
end

-- A vertical bar fading out to the top, rounded.
local function bar(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = frame
	local fade = Instance.new("UIGradient")
	fade.Name = "Fade"
	-- Rotation 90: the gradient runs from the top (0) to the bottom (1).
	fade.Rotation = 90
	fade.Parent = frame
	frame.Parent = parent
	return frame
end

local function image(name: string, id: string, scale: number, parent: Instance): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(scale, scale)
	label.Image = id
	label.Parent = parent
	return label
end

local function fade(frame: Frame, foot: number)
	local gradient = frame:FindFirstChild("Fade") :: UIGradient
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.6, foot + (1 - foot) * 0.5),
		NumberSequenceKeypoint.new(1, foot),
	})
end

function EggBeaconController.new(): EggBeaconController
	local beacons: { [Instance]: Beacon } = {}

	local function show(beacon: Beacon, nest: Instance)
		local rarity = nest:GetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE)
		local position = nest:GetAttribute(EggConfig.NEST_EGG_POSITION_ATTRIBUTE)
		local look = if type(rarity) == "string" then (EggLooks.RARITIES :: any)[rarity] else nil
		local spec: EggLooks.BeaconLook? = look and look.beacon
		local shown = nest:GetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE) == true
			and typeof(position) == "Vector3"
			and spec ~= nil
		beacon.column.Enabled = shown
		beacon.badge.Enabled = shown
		beacon.spec = if shown then spec else nil
		if not shown or not spec then
			return
		end
		local looks = EggLooks.BEACON
		local color: Color3 = look.color
		beacon.foot.WorldPosition = (position :: Vector3) + Vector3.yAxis * looks.foot
		-- The column stands on its foot: its box is shifted up by half its height.
		beacon.column.Size = UDim2.new(spec.width, looks.glowMinPixels, spec.height, spec.pixels)
		beacon.column.SizeOffset = Vector2.new(0, 0.5)
		beacon.glow.Size = UDim2.fromScale(1, 1)
		beacon.glow.BackgroundColor3 = color
		fade(beacon.glow, looks.glowTransparency)
		beacon.core.Size = UDim2.new(looks.coreWidth, looks.coreMinPixels, 1, 0)
		beacon.core.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), looks.coreWhiten)
		fade(beacon.core, looks.coreTransparency)
		beacon.badge.Size = UDim2.fromOffset(spec.dot, spec.dot)
		beacon.halo.ImageColor3 = color
		local egg = beacon.badge:FindFirstChild("Egg") :: ImageLabel
		egg.ImageColor3 = color
	end

	local function add(nest: Instance)
		if beacons[nest] then
			return
		end
		local looks = EggLooks.BEACON
		local foot = Instance.new("Attachment")
		foot.Name = "EggBeacon"
		local column = billboard("Column", foot, false)
		local glow = bar("Glow", column)
		local core = bar("Core", column)
		-- The badge over the egg: a soft glow, a dark disc, the egg icon in the rarity's colour;
		-- seen through rocks.
		local badge = billboard("Badge", foot, true)
		badge.StudsOffsetWorldSpace = Vector3.yAxis * (looks.badgeAbove - looks.foot)
		local halo = image("Halo", Icons.GLOW, 1.9, badge)
		local disc = image("Disc", Icons.DISC, 1, badge)
		disc.ImageColor3 = looks.discColor
		image("Egg", Icons.ICONS.Egg, 0.74, badge)
		-- An Attachment in Terrain sits at a world position, with no part to hold it.
		foot.Parent = workspace.Terrain

		local beacon: Beacon = {
			foot = foot,
			column = column,
			glow = glow,
			core = core,
			badge = badge,
			halo = halo,
			spec = nil,
			connections = {},
		}
		beacons[nest] = beacon
		for _, attribute in
			{
				EggConfig.NEST_HAS_EGG_ATTRIBUTE,
				EggConfig.NEST_RARITY_ATTRIBUTE,
				EggConfig.NEST_EGG_POSITION_ATTRIBUTE,
			}
		do
			table.insert(
				beacon.connections,
				nest:GetAttributeChangedSignal(attribute):Connect(function()
					show(beacon, nest)
				end)
			)
		end
		show(beacon, nest)
	end

	local function remove(nest: Instance)
		local beacon = beacons[nest]
		if not beacon then
			return
		end
		beacons[nest] = nil
		for _, connection in beacon.connections do
			connection:Disconnect()
		end
		beacon.foot:Destroy()
	end

	-- The rarest badges' glow breathes.
	local sinceUpdate = math.huge
	local function update(dt: number)
		sinceUpdate += dt
		if sinceUpdate < EggLooks.BEACON.updateSeconds then
			return
		end
		sinceUpdate = 0
		local looks = EggLooks.BEACON
		local scale = 1.9 * (1 + looks.pulse * math.sin(os.clock() * looks.pulseSpeed))
		for _, beacon in beacons do
			local spec = beacon.spec
			if spec and spec.pulse then
				beacon.halo.Size = UDim2.fromScale(scale, scale)
			end
		end
	end

	local function start()
		CollectionService:GetInstanceAddedSignal(EggConfig.NEST_TAG):Connect(add)
		CollectionService:GetInstanceRemovedSignal(EggConfig.NEST_TAG):Connect(remove)
		for _, nest in CollectionService:GetTagged(EggConfig.NEST_TAG) do
			add(nest)
		end
		RunService.RenderStepped:Connect(update)
	end

	return {
		name = "EggBeaconController",
		start = start,
	}
end

return table.freeze(EggBeaconController)
