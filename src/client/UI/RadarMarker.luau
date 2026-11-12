--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- One marker of a player or a loose egg on the screen (docs/design/screens/markers.md), reused
-- from frame to frame for whatever the controller puts in it:
-- - a player: "Name · 340 m" over a small ▼ (a shield for a newbie), light, no frame; at the
--   screen edge only a small faint arrow;
-- - a thief: the same on a pill outlined in the egg's rarity, an egg icon first; a hot one (rare
--   or rarer) bigger, its outline pulsing; at the edge an arrow with the egg, and a hot one's name;
-- - a loose egg: a round badge with the egg, its ring the time left before it flies home, the
--   distance under it; at the edge, the badge by an arrow.
-- Positions are viewport pixels (the ScreenGui ignores the top bar inset).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local ProgressRing = require(script.Parent.ProgressRing)
local Radar = require(ReplicatedStorage.Shared.Domain.Radar)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create
local source = Vide.source

local NEON = Theme.NEON
-- Points of the reference screen (the body scales with the screen; arrows by `scale`).
local TEXT_SIZE = NEON.TEXT_SMALL
local HOT_TEXT_SIZE = NEON.TEXT_BODY
local EGG_ICON_SIZE = 15
local HOT_EGG_ICON_SIZE = 18
local POINTER_SIZE = 10
local SHIELD_SIZE = 12
local BADGE_SIZE = 26
local BADGE_ICON_SIZE = 15
local PILL_PADDING_X = 7
local PILL_PADDING_Y = 2
local GAP = 4
local ARROW_SIZE = 22
local TICK_SIZE = 16
-- A plain player's edge tick is this see-through on top of its fade.
local TICK_TRANSPARENCY = 0.15
local GLASS_TRANSPARENCY = 0.35
local STROKE_THICKNESS = 2
local HOT_STROKE_THICKNESS = 3
-- A hot thief's outline breathes between these transparencies once a second.
local PULSE_LOW, PULSE_HIGH = 0, 0.6
local PULSE_HZ = 1
local ARROW_GLYPH = "▶"
local POINTER_GLYPH = "▼"
-- A long display name is cut to this many characters.
local NAME_CHARACTERS = 16

export type Kind = Radar.Kind | "Loose"

-- What a marker shows this frame.
export type State = {
	kind: Kind,
	-- The player's name; unused for a loose egg.
	title: string,
	distance: string,
	-- The egg's rarity colour, or the text colour for a plain player.
	color: Color3,
	transparency: number,
	isNewbie: boolean,
	-- A loose egg's time left, 0 to 1.
	timeLeft: number,
	-- The egg's icon (UI/EggIcon): a special egg has its own.
	eggIcon: Icons.Name,
	-- Where the body stands, and the arrow at the edge if the target is out of view.
	body: Vector2,
	arrow: Vector2?,
	angle: number,
	-- Arrows' size against the reference screen.
	scale: number,
}

export type Marker = {
	view: (order: number) -> Frame,
	show: (state: State) -> (),
	hide: () -> (),
}

local RadarMarker = {}

-- `name`, cut with an ellipsis past NAME_CHARACTERS characters.
function RadarMarker.shortName(name: string): string
	local length = utf8.len(name)
	if not length or length <= NAME_CHARACTERS then
		return name
	end
	local cut = utf8.offset(name, NAME_CHARACTERS) :: number
	return `{string.sub(name, 1, cut - 1)}…`
end

-- About how big a marker's body is at the screen edge, reference points: the arrow's label stands
-- this far inwards, clear of the arrow.
local EDGE_BODY: { [Kind]: Vector2 } = {
	Player = Vector2.zero,
	Thief = Vector2.new(30, 22),
	HotThief = Vector2.new(140, 26),
	Loose = Vector2.new(30, 42),
}
local EDGE_GAP = 4

-- Where a marker's body stands at the screen edge: inwards from its arrow at `arrow`, which
-- points at `angle` degrees.
function RadarMarker.edgeBody(kind: Kind, arrow: Vector2, angle: number, scale: number): Vector2
	local radians = math.rad(angle)
	local towards = Vector2.new(math.cos(radians), math.sin(radians))
	local size = EDGE_BODY[kind]
	local reach = ARROW_SIZE / 2 + EDGE_GAP + math.abs(towards.X) * size.X / 2 + math.abs(towards.Y) * size.Y / 2
	return arrow - towards * reach * scale
end

-- The body's size at the edge, pixels, for keeping labels apart.
function RadarMarker.edgeSize(kind: Kind, scale: number): Vector2
	return EDGE_BODY[kind] * scale
end

local function at(position: () -> Vector2): () -> UDim2
	return function()
		local point = position()
		return UDim2.fromOffset(point.X, point.Y)
	end
end

function RadarMarker.new(): Marker
	local visible = source(false)
	local kind = source("Player" :: Kind)
	local title = source("")
	local distance = source("")
	local color = source(NEON.TEXT)
	local transparency = source(0)
	local isNewbie = source(false)
	local timeLeft = source(1)
	local eggIcon = source("Egg" :: Icons.Name)
	local function eggImage(): string
		return Icons.ICONS[eggIcon()]
	end
	local body = source(Vector2.zero)
	local onEdge = source(false)
	local arrow = source(Vector2.zero)
	local angle = source(0)
	local scale = source(1)
	local pulse = source(0)

	local function isThief(): boolean
		local current = kind()
		return current == "Thief" or current == "HotThief"
	end
	local function isHot(): boolean
		return kind() == "HotThief"
	end
	-- The name and the distance: everywhere but on a loose egg, on a plain player's edge tick
	-- and on a lesser thief's edge arrow.
	local function showsText(): boolean
		local current = kind()
		return current ~= "Loose" and not (onEdge() and current ~= "HotThief")
	end
	local function textSize(): number
		return if isHot() then HOT_TEXT_SIZE else TEXT_SIZE
	end
	local function textColor(): Color3
		return if isThief() then NEON.TEXT else color()
	end

	local function show(state: State)
		visible(true)
		kind(state.kind)
		title(state.title)
		if state.distance ~= distance() then
			distance(state.distance)
		end
		color(state.color)
		transparency(state.transparency)
		isNewbie(state.isNewbie)
		timeLeft(state.timeLeft)
		eggIcon(state.eggIcon)
		body(state.body)
		local edge = state.arrow
		onEdge(edge ~= nil)
		if edge then
			arrow(edge)
			angle(state.angle)
		end
		scale(state.scale)
		if state.kind == "HotThief" then
			local wave = (1 + math.sin(os.clock() * PULSE_HZ * 2 * math.pi)) / 2
			pulse(PULSE_LOW + (PULSE_HIGH - PULSE_LOW) * wave)
		end
	end

	local function view(order: number): Frame
		-- Vide's create does not know UIStroke (CLAUDE.md, "Vide").
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Vide.effect(function()
			outline.Color = color()
			outline.Thickness = if isHot() then HOT_STROKE_THICKNESS else STROKE_THICKNESS
			outline.Transparency = if isHot() then pulse() else transparency()
			outline.Enabled = isThief()
		end)

		local tag = create("Frame")({
			Name = "Tag",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = NEON.GLASS,
			BackgroundTransparency = function()
				return if isThief() then GLASS_TRANSPARENCY else 1
			end,
			Visible = function()
				return kind() ~= "Loose" and (showsText() or isThief())
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			outline,
			Layout.padding(PILL_PADDING_X, PILL_PADDING_Y),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("ImageLabel")({
				Name = "Egg",
				LayoutOrder = 1,
				Size = function()
					local size = if isHot() then HOT_EGG_ICON_SIZE else EGG_ICON_SIZE
					return UDim2.fromOffset(size, size)
				end,
				BackgroundTransparency = 1,
				Image = eggImage,
				ImageColor3 = color,
				Visible = isThief,
			}),
			create("TextLabel")({
				Name = "Name",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = textSize,
				TextColor3 = textColor,
				TextTransparency = transparency,
				Text = title,
				Visible = showsText,
				Layout.textStroke(),
			}),
			create("TextLabel")({
				Name = "Distance",
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = textSize,
				TextColor3 = NEON.MUTED,
				TextTransparency = transparency,
				Text = function()
					return `· {distance()}`
				end,
				Visible = showsText,
				Layout.textStroke(),
			}),
		})

		local badge = create("Frame")({
			Name = "Badge",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
			BackgroundColor3 = NEON.GLASS,
			BackgroundTransparency = GLASS_TRANSPARENCY,
			Visible = function()
				return kind() == "Loose"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			ProgressRing({ fraction = timeLeft, color = color, share = 1, zIndex = 1 }),
			-- Covers the ring's middle, so only its rim shows.
			create("Frame")({
				Name = "Middle",
				ZIndex = 2,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.8),
				BackgroundColor3 = NEON.GLASS,
				BackgroundTransparency = 0.1,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
			create("ImageLabel")({
				Name = "Egg",
				ZIndex = 3,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(BADGE_ICON_SIZE, BADGE_ICON_SIZE),
				BackgroundTransparency = 1,
				Image = eggImage,
				ImageColor3 = color,
			}),
		})

		return create("Frame")({
			Name = `Marker{order}`,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = visible,

			create("Frame")({
				Name = "Body",
				AnchorPoint = function()
					if onEdge() then
						return Vector2.new(0.5, 0.5)
					end
					-- Over the player's head; the badge right on the egg.
					return if kind() == "Loose" then Vector2.new(0.5, 0.3) else Vector2.new(0.5, 1)
				end,
				Position = at(body),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Layout.screenScale(),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				tag,
				badge,
				create("TextLabel")({
					Name = "BadgeDistance",
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = TEXT_SIZE,
					TextColor3 = NEON.TEXT,
					Text = distance,
					Visible = function()
						return kind() == "Loose"
					end,
					Layout.textStroke(),
				}),
				create("TextLabel")({
					Name = "Pointer",
					LayoutOrder = 3,
					Size = UDim2.fromOffset(POINTER_SIZE, POINTER_SIZE),
					BackgroundTransparency = 1,
					FontFace = NEON.FONT,
					TextSize = POINTER_SIZE,
					TextColor3 = color,
					TextTransparency = transparency,
					Text = POINTER_GLYPH,
					Visible = function()
						return not onEdge() and kind() ~= "Loose" and not (kind() == "Player" and isNewbie())
					end,
				}),
				create("ImageLabel")({
					Name = "Shield",
					LayoutOrder = 3,
					Size = UDim2.fromOffset(SHIELD_SIZE, SHIELD_SIZE),
					BackgroundTransparency = 1,
					Image = Icons.ICONS.Shield,
					ImageColor3 = NEON.MUTED,
					ImageTransparency = transparency,
					Visible = function()
						return not onEdge() and kind() == "Player" and isNewbie()
					end,
				}),
			}),

			create("TextLabel")({
				Name = "Arrow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = function()
					local size = (if kind() == "Player" then TICK_SIZE else ARROW_SIZE) * scale()
					return UDim2.fromOffset(size, size)
				end,
				Position = at(arrow),
				Rotation = angle,
				Visible = onEdge,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = function()
					return (if kind() == "Player" then TICK_SIZE else ARROW_SIZE) * scale()
				end,
				TextColor3 = color,
				TextTransparency = function()
					return if kind() == "Player" then math.min(1, transparency() + TICK_TRANSPARENCY) else 0
				end,
				TextStrokeTransparency = 0.5,
				Text = ARROW_GLYPH,
			}),
		}) :: Frame
	end

	return {
		view = view,
		show = show,
		hide = function()
			visible(false)
		end,
	}
end

return table.freeze(RadarMarker)
