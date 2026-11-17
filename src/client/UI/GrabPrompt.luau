--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The prompt over a thing in the world (docs/design/screens/buttons.md): a neon pill like an
-- action button, a round badge on its left (the key to press, or a hand on a touch screen) and the
-- action's word on its right ("Hatch", "Take"). The whole pill is the button, with room to spare
-- round it, so a finger cannot miss; it presses and clicks like every button (UI/Press). A prompt
-- that is held draws a ring of progress round its badge as the hold goes on (an egg's grab). An egg
-- in the incubator shows its hatch odds under the pill (docs/design/screens/egg-odds.md): the word
-- "Odds", a dot in each tier's colour with its chance, and "›"; the strip is a button of its own
-- that opens the full list (decision 127).

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
-- The billboard's room: the widest pill there may be (a price in the word), or the odds row under
-- it (the word, three chances and "›"), points.
local BILLBOARD_WIDTH = 320
-- The odds row under the pill: its height, a dot's size, the room between chances and between a
-- dot and its chance, points. As wide as the pill (wider only if its chances need it), outlined in
-- the prompt's colour, so it reads as the pill's own strip (the user, 2026-11-12: a short frame
-- looked stubby).
local ODDS_HEIGHT = 26
local ODDS_DOT = 12
local ODDS_GAP = 14
local ODDS_DOT_GAP = 5
-- Room between the pill's slack and the odds row, points.
local ODDS_MARGIN = 4
-- The mark after the chances: the strip opens something.
local ODDS_MORE = "›"

-- One tier's chance in the odds row.
export type Chance = {
	color: Color3,
	text: string,
}

-- The odds row under an incubator egg's pill: the word in front ("Odds"), the tiers' chances
-- (lowest first) and what pressing the strip does (opens the odds window).
export type Odds = {
	word: string,
	chances: { Chance },
	onPress: () -> (),
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
	-- The hatch odds under the pill; absent: no row.
	odds: Odds?,
}

-- A word on the odds row ("Odds", "›").
local function OddsWord(name: string, order: number, text: string): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		FontFace = NEON.FONT,
		TextSize = NEON.TEXT_BODY,
		TextColor3 = NEON.TEXT,
		Text = text,
		Layout.textStroke(),
	}) :: TextLabel
end

-- The odds row: a glass strip with the word, a dot in each tier's colour with its chance and "›",
-- at least `width()` wide and outlined in `color()`. It is a button: it lights under the finger
-- like every button and opens the full list.
local function OddsRow(odds: Odds, width: () -> number, color: () -> Color3): TextButton
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Thickness = NEON.LINE_THICKNESS
	Vide.effect(function()
		outline.Color = Layout.lineColor(color())
	end)
	local press = Press.new({})
	-- Its contents' width, measured: the strip is as wide as the pill or as they need, whichever is
	-- more (AutomaticSize did not grow a button with a list in it).
	local contentWidth = Vide.source(0)
	local list = create("UIListLayout")({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, ODDS_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}) :: UIListLayout
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		contentWidth(list.AbsoluteContentSize.X)
	end)
	local children: { any } = {
		outline,
		list,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	}
	table.insert(children, OddsWord("Word", 0, odds.word))
	table.insert(children, OddsWord("More", #odds.chances + 1, ODDS_MORE))
	for index, chance in odds.chances do
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
					Padding = UDim.new(0, ODDS_DOT_GAP),
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
					TextSize = NEON.TEXT_BODY,
					TextColor3 = NEON.TEXT,
					Text = chance.text,
					Layout.textStroke(),
				}),
			})
		)
	end
	return create("TextButton")({
		Name = "Odds",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		-- Grows past the pill's width when its words and chances need more room.
		Size = function()
			return UDim2.fromOffset(math.max(width(), contentWidth() + ODDS_GAP * 2), ODDS_HEIGHT)
		end,
		BackgroundColor3 = function()
			return NEON.GLASS:Lerp(Color3.new(1, 1, 1), press.light())
		end,
		BackgroundTransparency = 0.2,
		Text = "",
		AutoButtonColor = false,
		Activated = function()
			odds.onPress()
		end,
		press.action,
		children,
	}) :: TextButton
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
	-- The pill's width at rest (a press shrinks it for a moment; the strip under it stays put).
	local pillWidth = Vide.source(0)
	local function measure(pill: Frame)
		pill:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			pillWidth(pill.AbsoluteSize.X / math.max(scale.Scale, 1e-3))
		end)
	end
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

		if props.odds then OddsRow(props.odds, pillWidth, color) else nil,

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
				action(function(instance)
					measure(instance :: Frame)
				end),
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
