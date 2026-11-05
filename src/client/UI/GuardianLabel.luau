--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The sign over a guardian: its name, coloured by how the player stands against it (red to
-- white to green, GuardianLooks.standingColor). The number itself is not shown here: the colour
-- tells whether to try, and the HUD's goal shows how far the next guardian is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local TITLE_HEIGHT = 32
-- The Studio-only debug line (GuardianLabel's debugText).
local DEBUG_HEIGHT = 22
local DEBUG_TEXT_SIZE = 18
local WIDTH = 240
-- Height of the sign above the guardian's center, studs.
local STUDS_ABOVE = 5

export type Props = {
	adornee: BasePart,
	name: string,
	-- The name's colour: how the player stands against this guardian (GuardianLooks.standingColor).
	nameColor: () -> Color3,
	-- The sign is hidden beyond this distance, studs (ZoneLooks.GUARDIAN_SIGN_DISTANCE).
	maxDistance: number,
	-- Studio-only debug line under the name (DevConfig.STUDIO_GUARDIAN_SPEED); nil in live games.
	debugText: string?,
}

local function GuardianLabel(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = "GuardianLabel",
		Adornee = props.adornee,
		Size = UDim2.fromOffset(WIDTH, TITLE_HEIGHT + (if props.debugText then DEBUG_HEIGHT else 0)),
		StudsOffset = Vector3.new(0, STUDS_ABOVE, 0),
		MaxDistance = props.maxDistance,
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
			Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = props.nameColor,
			TextStrokeTransparency = 0.4,
			Text = props.name,
		}),

		if props.debugText
			then create("TextLabel")({
				Name = "Debug",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, DEBUG_HEIGHT),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = DEBUG_TEXT_SIZE,
				TextColor3 = Theme.SPEED,
				TextStrokeTransparency = 0.4,
				Text = props.debugText,
			})
			else nil,
	}) :: BillboardGui
end

return GuardianLabel
