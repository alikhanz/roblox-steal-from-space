--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The prompt over a thing in the world (docs/design/screens/buttons.md): a neon pill like an
-- action button, a round badge on its left (the key to press, or a hand on a touch screen) and the
-- action's word on its right ("Hatch", "Take"). The whole pill is the button, with room to spare
-- round it, so a finger cannot miss; it presses and clicks like every button (UI/Press). A prompt
-- that is held draws a ring of progress round its badge as the hold goes on (an egg's grab). An egg
-- in the incubator shows its hatch odds under the pill (docs/design/screens/egg-odds.md): a dot in
-- each tier's colour with its chance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Press = require(script.Parent.Press)
local ProgressRing = require(script.Parent.ProgressRing)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local action = Vide.action
local create = Vide.create

local NEON = Theme.NEON
local HEIGHT = 48
-- A pill with a word is at least this wide, points; one with no word is a circle.
local MIN_WIDTH = 120
local BADGE_SIZE = 36
local PADDING = 6
local GAP = 8
local WORD_END = 16
-- Invisible room round the pill that still presses it, points.
local SLACK = 8
-- A held prompt's progress ring round the badge: its size against the badge, and how far its
-- colour goes towards white.
local RING_SHARE = 1.28
local RING_LIGHTEN = 0.35
-- Height of the prompt above the egg's center, studs.
local STUDS_ABOVE = 2.4
-- The billboard's room: the widest pill there may be (a price in the word), points.
local BILLBOARD_WIDTH = 300
-- The odds row under the pill: its height, a dot's size and the room between chances, points.
local ODDS_HEIGHT = 22
local ODDS_DOT = 10
local ODDS_GAP = 10
-- Room between the pill's slack and the odds row, points.
local ODDS_MARGIN = 4

-- One tier's chance in the odds row.
export type Chance = {
	color: Color3,
	text: string,
}

export type Props = {
	-- The thing to hover over (a part, or a point on one); nil hides the prompt.
	target: () -> (BasePart | Attachment)?,
	-- Hold progress, 0..1.
	progress: () -> number,
	-- The hold's fill; absent for a prompt that is a single press.
	showBar: (() -> boolean)?,
	-- Text on the badge: the key to press, or a touch symbol.
	badgeText: () -> string,
	-- The action's word; empty: only the badge.
	hint: () -> string,
	-- What the press does (NEON.ACTION.*); the egg prompt's oxygen blue by default.
	color: (() -> Color3)?,
	-- Touch screens press the pill itself; it is bound to the prompt's input once created.
	onBadge: (button: GuiButton) -> (),
	-- Beyond this distance the prompt is not drawn at all, studs; default: always.
	maxDistance: number?,
	-- Height above the target's center, studs; default: over an egg.
	studsAbove: number?,
	-- The hatch odds under the pill, lowest tier first; absent: no row.
	odds: { Chance }?,
}

-- The odds row: a glass strip of dots in the tiers' colours, each with its chance.
local function OddsRow(odds: { Chance }): Frame
	local children: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, ODDS_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		Layout.padding(0, ODDS_GAP),
	}
	for index, chance in odds do
		table.insert(
			children,
			create("Frame")({
				Name = `Chance{index}`,
				LayoutOrder = index,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, ODDS_HEIGHT),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("Frame")({
					Name = "Dot",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(ODDS_DOT, ODDS_DOT),
					BackgroundColor3 = chance.color,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),
				create("TextLabel")({
					Name = "Chance",
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = NEON.TEXT_SMALL,
					TextColor3 = NEON.TEXT,
					Text = chance.text,
					Layout.textStroke(),
				}),
			})
		)
	end
	return create("Frame")({
		Name = "Odds",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ODDS_HEIGHT),
		BackgroundColor3 = NEON.GLASS,
		BackgroundTransparency = 0.25,
		children,
	}) :: Frame
end

local function GrabPrompt(props: Props): BillboardGui
	local function color(): Color3
		return if props.color then props.color() else Theme.OXYGEN
	end
	local function hasWord(): boolean
		return props.hint() ~= ""
	end
	local function holding(): boolean
		return props.showBar == nil or props.showBar()
	end
	local press = Press.new({ shrinks = true })
	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(NEON.ACTION.Main, corner, true)
	local fill = glass[1] :: Frame
	local outline = glass[2] :: UIStroke
	local scale = Instance.new("UIScale")
	local least = Layout.minSize(HEIGHT, HEIGHT)
	-- Room after the word to the pill's round end; none for a badge alone.
	local contentPadding = Layout.padding(PADDING, PADDING)
	Vide.effect(function()
		local word = hasWord()
		least.MinSize = Vector2.new(if word then MIN_WIDTH else HEIGHT, HEIGHT)
		contentPadding.PaddingRight = UDim.new(0, if word then WORD_END else PADDING)
	end)
	Vide.effect(function()
		local current = color()
		fill.BackgroundColor3 = current:Lerp(Color3.new(1, 1, 1), press.light())
		outline.Color = Layout.lineColor(current)
		scale.Scale = press.scale()
	end)

	-- A billboard draws nothing past its own size, so the odds row is inside it. The billboard
	-- grows as much above the pill as below, so the pill stays at its centre, where it always is.
	local oddsRoom = if props.odds then ODDS_HEIGHT + ODDS_MARGIN else 0
	return create("BillboardGui")({
		Name = "GrabPrompt",
		-- Vide's types expect a source of a non-optional Instance; a nil Adornee is valid here.
		Adornee = props.target :: any,
		Enabled = function()
			return props.target() ~= nil
		end,
		AlwaysOnTop = true,
		-- Needed for the pill to receive touches on phones.
		Active = true,
		Size = UDim2.fromOffset(BILLBOARD_WIDTH, HEIGHT + SLACK * 2 + oddsRoom * 2),
		StudsOffset = Vector3.new(0, props.studsAbove or STUDS_ABOVE, 0),
		MaxDistance = props.maxDistance or math.huge,
		LightInfluence = 0,

		if props.odds then OddsRow(props.odds) else nil,

		-- The button: the pill and the slack round it.
		create("TextButton")({
			Name = "Press",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, HEIGHT + SLACK * 2),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			press.action,
			action(function(instance)
				props.onBadge(instance :: GuiButton)
			end),
			Layout.padding(SLACK, SLACK),

			create("Frame")({
				Name = "Pill",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, HEIGHT),
				BackgroundTransparency = 1,
				scale,
				create("UICorner")({ CornerRadius = corner }),
				least,
				glass,
				create("Frame")({
					Name = "Content",
					ZIndex = 2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					BackgroundTransparency = 1,
					contentPadding,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					-- The badge, with a held prompt's progress as a ring round it (as the grab button's).
					create("Frame")({
						Name = "BadgeHolder",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
						BackgroundTransparency = 1,
						ProgressRing({
							fraction = function()
								return if holding() then math.clamp(props.progress(), 0, 1) else 0
							end,
							color = function()
								return color():Lerp(Color3.new(1, 1, 1), RING_LIGHTEN)
							end,
							share = RING_SHARE,
							zIndex = 2,
						}),
						create("TextLabel")({
							Name = "Badge",
							ZIndex = 3,
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = NEON.GLASS,
							BackgroundTransparency = 0.1,
							FontFace = NEON.FONT,
							TextSize = BADGE_SIZE * 0.5,
							TextColor3 = NEON.TEXT,
							Text = props.badgeText,
							create("UICorner")({ CornerRadius = corner }),
						}),
					}),
					create("TextLabel")({
						Name = "Hint",
						LayoutOrder = 2,
						ZIndex = 2,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromScale(0, 1),
						BackgroundTransparency = 1,
						FontFace = NEON.FONT,
						TextSize = NEON.TEXT_SECTION,
						TextColor3 = NEON.TEXT,
						Text = props.hint,
						Visible = hasWord,
						Layout.textStroke(),
					}),
				}),
			}),
		}),
	}) :: BillboardGui
end

return GrabPrompt
