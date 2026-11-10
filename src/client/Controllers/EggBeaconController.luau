--!strict
-- Shows what eggs are around you (user, 2026-11-10: eggs were hard to tell apart in flight):
-- through every nest nearby holding an egg of uncommon rarity or rarer runs a column of light in
-- the rarity's colour, a coloured glow round a bright core, brightest at the egg and fading out
-- above and below it (seen from over the nest and from under it), longer the rarer the egg.
-- Only within EggLooks.BEACON.range: the eggs around you, not the whole map (a map-wide
-- radar is an idea for later, docs/IDEAS.md). A common egg gets none: no column reads as common.
-- Looks in EggLooks.RARITIES[…].beacon and EggLooks.BEACON.
--
-- Built from the nest's own attributes (HasEgg, Rarity, EggPosition), on this client only: one
-- BillboardGui a nest on one Attachment, no particles, nothing over the network. The egg itself
-- may not be streamed in; the nest's attributes are.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)

export type EggBeaconController = {
	name: string,
	start: () -> (),
}

type Beacon = {
	foot: Attachment,
	column: BillboardGui,
	glow: Frame,
	core: Frame,
	connections: { RBXScriptConnection },
}

local EggBeaconController = {}

-- A vertical bar, brightest in the middle and fading out to both ends, rounded.
local function bar(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
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

-- `middle`: the transparency at the egg; both ends fade out.
local function fade(frame: Frame, middle: number)
	local gradient = frame:FindFirstChild("Fade") :: UIGradient
	local half = middle + (1 - middle) * 0.5
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, half),
		NumberSequenceKeypoint.new(0.5, middle),
		NumberSequenceKeypoint.new(0.8, half),
		NumberSequenceKeypoint.new(1, 1),
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
		if not shown or not spec then
			return
		end
		local looks = EggLooks.BEACON
		local color: Color3 = look.color
		-- Centred on the egg, running as far below it as above.
		beacon.foot.WorldPosition = position :: Vector3
		beacon.column.Size = UDim2.new(spec.width, looks.glowMinPixels, spec.height * 2, 0)
		beacon.glow.Size = UDim2.fromScale(1, 1)
		beacon.glow.BackgroundColor3 = color
		fade(beacon.glow, looks.glowTransparency)
		beacon.core.Size = UDim2.new(looks.coreWidth, looks.coreMinPixels, 1, 0)
		beacon.core.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), looks.coreWhiten)
		fade(beacon.core, looks.coreTransparency)
	end

	local function add(nest: Instance)
		if beacons[nest] then
			return
		end
		local foot = Instance.new("Attachment")
		foot.Name = "EggBeacon"
		local column = Instance.new("BillboardGui")
		column.Name = "Column"
		column.LightInfluence = 0
		column.MaxDistance = EggLooks.BEACON.range
		column.Adornee = foot
		column.Parent = foot
		local glow = bar("Glow", column)
		local core = bar("Core", column)
		-- An Attachment in Terrain sits at a world position, with no part to hold it.
		foot.Parent = workspace.Terrain

		local beacon: Beacon = { foot = foot, column = column, glow = glow, core = core, connections = {} }
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

	local function start()
		CollectionService:GetInstanceAddedSignal(EggConfig.NEST_TAG):Connect(add)
		CollectionService:GetInstanceRemovedSignal(EggConfig.NEST_TAG):Connect(remove)
		for _, nest in CollectionService:GetTagged(EggConfig.NEST_TAG) do
			add(nest)
		end
	end

	return {
		name = "EggBeaconController",
		start = start,
	}
end

return table.freeze(EggBeaconController)
