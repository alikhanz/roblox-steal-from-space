--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The prompt over a grabbable egg: a key badge ("E", "X") or, on touch screens, a badge to press
-- and hold, plus a bar that fills while the grab is held.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local create = Vide.create

local BADGE_SIZE = 56
local BAR_SIZE = Vector2.new(96, 10)
local GAP = 6
-- Height of the prompt above the egg's center, studs.
local STUDS_ABOVE = 2.4

export type Props = {
	-- The egg to hover over; nil hides the prompt.
	target: () -> BasePart?,
	-- Grab progress, 0..1.
	progress: () -> number,
	-- The hold bar; absent for a prompt that is a single press.
	showBar: (() -> boolean)?,
	-- Text on the badge: the key to hold, or a touch symbol.
	badgeText: () -> string,
	hint: () -> string,
	-- Touch screens press the badge itself; it is bound to the grab input action once created.
	onBadge: (badge: GuiButton) -> (),
}

-- Vide's instance types do not list UIStroke, so it is made directly.
local function stroke(color: Color3, thickness: number): UIStroke
	local instance = Instance.new("UIStroke")
	instance.Color = color
	instance.Thickness = thickness
	return instance
end

local function GrabPrompt(props: Props): BillboardGui
	return create("BillboardGui")({
		Name = "GrabPrompt",
		-- Vide's types expect a source of a non-optional Instance; a nil Adornee is valid here.
		Adornee = props.target :: any,
		Enabled = function()
			return props.target() ~= nil
		end,
		AlwaysOnTop = true,
		-- Needed for the badge to receive touches on phones.
		Active = true,
		Size = UDim2.fromOffset(160, BADGE_SIZE + BAR_SIZE.Y + 30 + GAP * 2),
		StudsOffset = Vector3.new(0, STUDS_ABOVE, 0),
		LightInfluence = 0,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextButton")({
			Name = "Badge",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
			BackgroundColor3 = Theme.PANEL,
			BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
			AutoButtonColor = false,
			FontFace = Theme.FONT,
			TextSize = BADGE_SIZE * 0.5,
			TextColor3 = Theme.TEXT,
			Text = props.badgeText,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			stroke(Theme.OXYGEN, 2),
			action(function(instance)
				props.onBadge(instance :: GuiButton)
			end),
		}),

		create("Frame")({
			Name = "Bar",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
			BackgroundColor3 = Theme.PANEL,
			BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
			Visible = props.showBar or true,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			create("Frame")({
				Name = "Fill",
				BorderSizePixel = 0,
				BackgroundColor3 = Theme.OXYGEN,
				Size = function()
					return UDim2.fromScale(props.progress(), 1)
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),

		create("TextLabel")({
			Name = "Hint",
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.FONT,
			TextSize = Theme.TEXT_SIZE,
			TextColor3 = Theme.TEXT,
			TextStrokeTransparency = 0.4,
			Text = props.hint,
		}),
	}) :: BillboardGui
end

return GrabPrompt
