--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The sign over a guardian, and over the star serpent (docs/design/screens/guardian-labels.md):
-- its name, and under it a pill of glass with an icon and a word for how it stands against the
-- player's own ⚡ (Speed.challenge, GuardianLooks.CHALLENGES). The number itself is not shown:
-- the HUD's goal shows how far the next guardian is. The sign is bigger the nearer it is
-- (`scale`, GuardianPose.labelScale), so near and far guardians tell apart at a glance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local NEON = Theme.NEON

-- The sign at full size (scale 1, near), pixels; farther it shrinks with a UIScale.
local NAME_TEXT_SIZE = 28
local WORD_TEXT_SIZE = 20
local ICON_SIZE = 20
local PILL_PADDING_X = 10
local PILL_PADDING_Y = 2
local GAP = 2
-- Glass a little denser than the HUD's: the pill stands over a busy scene (as WorldChip's).
local GLASS_TRANSPARENCY = 0.35
-- Room for the longest name and the pill at full size, pixels; the sign stands on its bottom.
local WIDTH = 320
local HEIGHT = 72
-- The Studio-only debug line (GuardianLabel's debugText).
local DEBUG_HEIGHT = 22
local DEBUG_TEXT_SIZE = 18

export type Props = {
	adornee: BasePart,
	name: string,
	-- How it stands against the player now; no pill while it is unknown (nil).
	challenge: () -> Speed.Challenge?,
	-- The word for each challenge, in the player's language.
	words: { [Speed.Challenge]: string },
	-- The sign's size as a share of full (GuardianPose.labelScale); the owner moves it only by
	-- visible steps (GuardianLooks.LABEL.SCALE_STEP).
	scale: () -> number,
	-- Height of the sign's bottom above the adornee's centre, studs.
	studsAbove: number,
	-- The sign is hidden beyond this distance, studs (ZoneLooks.GUARDIAN_SIGN_DISTANCE).
	maxDistance: number,
	-- Studio-only debug line under the pill (DevConfig.STUDIO_GUARDIAN_SPEED); nil in live games.
	debugText: string?,
}

local function GuardianLabel(props: Props): BillboardGui
	local function look(): GuardianLooks.ChallengeLook?
		local challenge = props.challenge()
		return if challenge then GuardianLooks.CHALLENGES[challenge] else nil
	end
	local function color(): Color3
		local current = look()
		return if current then current.color else NEON.TEXT
	end

	-- UIScale is not among the classes Vide's `create` knows (CLAUDE.md, Vide).
	local uiScale = Instance.new("UIScale")
	Vide.effect(function()
		uiScale.Scale = props.scale()
	end)

	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Thickness = NEON.LINE_THICKNESS
	Vide.effect(function()
		outline.Color = color()
	end)

	local height = HEIGHT + (if props.debugText then DEBUG_HEIGHT else 0)
	return create("BillboardGui")({
		Name = "GuardianLabel",
		Adornee = props.adornee,
		Size = UDim2.fromOffset(WIDTH, height),
		-- The sign's bottom middle sits `studsAbove` over the adornee: it shrinks towards it.
		StudsOffset = Vector3.new(0, props.studsAbove, 0),
		SizeOffset = Vector2.new(0, 0.5),
		MaxDistance = props.maxDistance,
		AlwaysOnTop = true,
		LightInfluence = 0,

		create("Frame")({
			Name = "Sign",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			uiScale,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			create("TextLabel")({
				-- Not "Name": that would shadow the Instance property for anyone reading the sign.
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, NAME_TEXT_SIZE + 4),
				BackgroundTransparency = 1,
				FontFace = Theme.FONT,
				TextSize = NAME_TEXT_SIZE,
				TextColor3 = NEON.TEXT,
				Text = props.name,
				Layout.textStroke(),
			}),

			create("Frame")({
				Name = "Pill",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				Visible = function(): boolean
					return look() ~= nil
				end,
				BackgroundColor3 = NEON.GLASS,
				BackgroundTransparency = GLASS_TRANSPARENCY,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				outline,
				Layout.padding(PILL_PADDING_X, PILL_PADDING_Y),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("ImageLabel")({
					Name = "Icon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					BackgroundTransparency = 1,
					Image = function(): string
						local current = look()
						return if current then Icons.ICONS[current.icon :: Icons.Name] or "" else ""
					end,
					ImageColor3 = function(): Color3
						return Layout.iconColor(color())
					end,
				}),
				create("TextLabel")({
					Name = "Word",
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, WORD_TEXT_SIZE + 4),
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = WORD_TEXT_SIZE,
					TextColor3 = color,
					Text = function(): string
						local challenge = props.challenge()
						return if challenge then props.words[challenge] else ""
					end,
					Layout.textStroke(),
				}),
			}),

			if props.debugText
				then create("TextLabel")({
					Name = "Debug",
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, DEBUG_HEIGHT),
					BackgroundTransparency = 1,
					FontFace = Theme.FONT,
					TextSize = DEBUG_TEXT_SIZE,
					TextColor3 = Theme.SPEED,
					TextStrokeTransparency = 0.4,
					Text = props.debugText,
				})
				else nil,
		}),
	}) :: BillboardGui
end

return GuardianLabel
