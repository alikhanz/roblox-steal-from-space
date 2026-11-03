--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The sign over a guardian: its name and the recommended speed to steal from it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local SIZE = UDim2.fromOffset(220, 60)
-- Height of the sign above the guardian's center, studs.
local STUDS_ABOVE = 5
-- Signs fade out beyond this distance so the field is not covered in text, studs.
local MAX_DISTANCE = 350
local VALUE_TEXT_SIZE = 24

export type Props = {
	adornee: BasePart,
	name: string,
	-- Formatted recommended speed, e.g. "1.5K".
	recommended: string,
}

local function GuardianLabel(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = "GuardianLabel",
		Adornee = props.adornee,
		Size = SIZE,
		StudsOffset = Vector3.new(0, STUDS_ABOVE, 0),
		MaxDistance = MAX_DISTANCE,
		AlwaysOnTop = true,
		LightInfluence = 0,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			-- Not "Name": that would shadow the Instance property for anyone reading the sign.
			Name = "Title",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextStrokeTransparency = 0.4,
			Text = props.name,
		}),

		create("TextLabel")({
			Name = "Recommended",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = VALUE_TEXT_SIZE,
			TextColor3 = Theme.SPEED,
			TextStrokeTransparency = 0.4,
			Text = `⚡ {props.recommended}`,
		}),
	}) :: BillboardGui
end

return GuardianLabel
