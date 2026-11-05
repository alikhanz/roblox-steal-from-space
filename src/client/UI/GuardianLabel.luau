--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The sign over a guardian: its name, coloured by how the player stands against it (red to
-- white to green, GuardianLooks.standingColor). The number itself is not shown here: the colour
-- tells whether to try, and the HUD's goal shows how far the next guardian is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local SIZE = UDim2.fromOffset(220, 32)
-- Height of the sign above the guardian's center, studs.
local STUDS_ABOVE = 5

export type Props = {
	adornee: BasePart,
	name: string,
	-- The name's colour: how the player stands against this guardian (GuardianLooks.standingColor).
	nameColor: () -> Color3,
	-- The sign is hidden beyond this distance, studs (ZoneLooks.GUARDIAN_SIGN_DISTANCE).
	maxDistance: number,
}

local function GuardianLabel(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = "GuardianLabel",
		Adornee = props.adornee,
		Size = SIZE,
		StudsOffset = Vector3.new(0, STUDS_ABOVE, 0),
		MaxDistance = props.maxDistance,
		AlwaysOnTop = true,
		LightInfluence = 0,

		create("TextLabel")({
			-- Not "Name": that would shadow the Instance property for anyone reading the sign.
			Name = "Title",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = props.nameColor,
			TextStrokeTransparency = 0.4,
			Text = props.name,
		}),
	}) :: BillboardGui
end

return GuardianLabel
