--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A two-line sign hanging over something in the world: a title and a value under it.
-- Used for bays, aliens and incubator eggs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local SIZE = UDim2.fromOffset(220, 60)
-- Signs fade out beyond this distance so the station is not covered in text, studs.
local DEFAULT_MAX_DISTANCE = 80
local VALUE_TEXT_SIZE = 16

export type Props = {
	adornee: BasePart,
	title: string,
	-- Static, or a source for values that change (countdowns).
	value: string | () -> string,
	valueColor: Color3?,
	-- Height of the sign above the adornee's center, studs.
	studsAbove: number,
	maxDistance: number?,
}

local function WorldLabel(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = "WorldLabel",
		Adornee = props.adornee,
		Size = SIZE,
		StudsOffset = Vector3.new(0, props.studsAbove, 0),
		MaxDistance = props.maxDistance or DEFAULT_MAX_DISTANCE,
		AlwaysOnTop = true,
		LightInfluence = 0,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			Name = "Title",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextStrokeTransparency = 0.4,
			Text = props.title,
		}),

		create("TextLabel")({
			Name = "Value",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = VALUE_TEXT_SIZE,
			TextColor3 = props.valueColor or Theme.TEXT,
			TextStrokeTransparency = 0.4,
			Text = props.value,
		}),
	}) :: BillboardGui
end

return WorldLabel
