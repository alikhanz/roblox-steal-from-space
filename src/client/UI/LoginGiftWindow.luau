--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The login gift window (docs/design/screens/login-gift.md): the streak's days in one row in a
-- neon window, each with what it gives. Days already taken fade with a check mark, today's tile
-- glows gold and breathes, the days ahead show their gifts; the egg day is wider, in the egg's
-- rarity colour, with the egg. The footer holds the one claim button, or, once taken, the
-- warning that a missed day starts the streak over. Texts come in resolved. `burst` throws
-- sparks out of a tile for the claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ActionButton = require(script.Parent.ActionButton)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local LEAD_HEIGHT = 20
local BODY_GAP = 10
local TILE_GAP = 6
-- The egg day's width against an ordinary day's.
local WIDE_SHARE = 1.6
local TILE_PADDING = 4
local TILE_LINE_GAP = 6
local TILE_TRANSPARENCY = 0.965
local TODAY_TRANSPARENCY = 0.86
local EGG_DAY_TRANSPARENCY = 0.88
-- How far the egg's colour of its day's outline goes towards the glass.
local EGG_LINE_DARKEN = 0.3
local SYMBOL_SIZE = 36
local EGG_SIZE = 46
local EGG_GLOW_SHARE = 1.8
local EGG_GLOW_TRANSPARENCY = 0.5
local VALUE_ICON_SIZE = 14
-- A taken day fades all over; a day ahead dims its gift.
local TAKEN_TRANSPARENCY = 0.55
local AHEAD_GIFT_TRANSPARENCY = 0.45
local TODAY_COLOR = NEON.ACTION.Coins
local CHECK_COLOR = Color3.fromHex("#5BDB6E")
local CHECK_MARK = "✓"
-- The sparks of a claim.
local SPARK_COUNT = 14
local SPARK_SIZE = 12
local SPARK_DISTANCE = 140
local SPARK_SECONDS = 0.8
-- The tile of the claim swells and snaps back.
local POP_SCALE = 1.35
local POP_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)

export type TileState = "Taken" | "Today" | "Ahead"

export type Tile = {
	-- "Day 3"
	title: string,
	coins: string,
	speed: string,
	-- The egg the day adds, and its rarity colour; nil for a day without one.
	egg: string?,
	eggColor: Color3?,
	state: TileState,
}

export type Props = {
	visible: () -> boolean,
	coins: () -> string,
	tiles: () -> { Tile },
	title: string,
	-- The line over the days: keep the streak going, it started over, or when the next gift is.
	hint: () -> string,
	claim: string,
	-- Under the days once today's gift is taken.
	miss: string,
	canClaim: () -> boolean,
	-- Today's tile breathes: a scale around 1.
	pulse: () -> number,
	onClaim: () -> (),
	onClose: () -> (),
}

local LoginGiftWindow = {}

type LabelOptions = {
	size: number?,
	color: (Color3 | () -> Color3)?,
	transparency: (() -> number)?,
	visible: (() -> boolean)?,
}

local function label(name: string, text: string | () -> string, order: number, options: LabelOptions?): TextLabel
	local opts: LabelOptions = options or {}
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = NEON.FONT,
		TextSize = opts.size or NEON.TEXT_BODY,
		TextColor3 = opts.color or NEON.MUTED,
		TextTransparency = opts.transparency or 0,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = opts.visible or true,
		Text = text,
		Layout.textStroke(),
	}) :: TextLabel
end

-- "+6K" with its resource's icon, centred.
local function Value(
	name: string,
	order: number,
	icon: Icons.Name,
	color: Color3,
	value: () -> string,
	dim: () -> number
): Frame
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("ImageLabel")({
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(VALUE_ICON_SIZE, VALUE_ICON_SIZE),
			BackgroundTransparency = 1,
			Image = Icons.ICONS[icon],
			ImageColor3 = color,
			ImageTransparency = dim,
		}),
		create("TextLabel")({
			Name = "Value",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_BODY,
			TextColor3 = color,
			TextTransparency = dim,
			Text = function()
				return `+{value()}`
			end,
			Layout.textStroke(),
		}),
	}) :: Frame
end

-- The day's picture: a check mark once taken, the egg on the egg day, a gift otherwise.
local function Symbol(entry: () -> Tile?, state: () -> TileState, dim: () -> number): Frame
	local function egg(): Tile?
		local current = entry()
		return if current and current.egg and state() ~= "Taken" then current else nil
	end
	local function eggColor(): Color3
		local current = entry()
		return if current and current.eggColor then current.eggColor else NEON.EGG
	end
	return create("Frame")({
		Name = "Symbol",
		LayoutOrder = 2,
		Size = function()
			local size = if egg() then EGG_SIZE else SYMBOL_SIZE
			return UDim2.fromOffset(size, size)
		end,
		BackgroundTransparency = 1,
		create("TextLabel")({
			Name = "Check",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = SYMBOL_SIZE - 4,
			TextColor3 = CHECK_COLOR,
			TextTransparency = dim,
			Text = CHECK_MARK,
			Visible = function()
				return state() == "Taken"
			end,
			Layout.textStroke(),
		}),
		create("ImageLabel")({
			Name = "Gift",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.ICONS.Gift,
			ImageColor3 = Layout.iconColor(TODAY_COLOR),
			ImageTransparency = function()
				return if state() == "Ahead" then AHEAD_GIFT_TRANSPARENCY else 0
			end,
			Visible = function()
				return state() ~= "Taken" and egg() == nil
			end,
		}),
		create("ImageLabel")({
			Name = "EggGlow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(EGG_GLOW_SHARE, EGG_GLOW_SHARE),
			BackgroundTransparency = 1,
			Image = Icons.GLOW,
			ImageColor3 = eggColor,
			ImageTransparency = EGG_GLOW_TRANSPARENCY,
			Visible = function()
				return egg() ~= nil
			end,
		}),
		create("ImageLabel")({
			Name = "Egg",
			ZIndex = 1,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.ICONS.Egg,
			ImageColor3 = eggColor,
			Visible = function()
				return egg() ~= nil
			end,
		}),
	}) :: Frame
end

local function DayTile(props: Props, index: number): Frame
	local function entry(): Tile?
		return props.tiles()[index]
	end
	local function state(): TileState
		local current = entry()
		return if current then current.state else "Ahead"
	end
	local function eggColor(): Color3?
		local current = entry()
		return if current then current.eggColor else nil
	end
	local function dim(): number
		return if state() == "Taken" then TAKEN_TRANSPARENCY else 0
	end
	-- The egg day is wider; the others share what is left equally.
	local function width(): UDim2
		local tiles = props.tiles()
		local units = 0
		for _, tile in tiles do
			units += if tile.egg then WIDE_SHARE else 1
		end
		local current = entry()
		local share = if current and current.egg then WIDE_SHARE else 1
		local part = share / math.max(units, 1)
		return UDim2.new(part, -TILE_GAP * math.max(#tiles - 1, 0) * part, 1, 0)
	end
	local scale = Instance.new("UIScale")
	Vide.effect(function()
		scale.Scale = if state() == "Today" then props.pulse() else 1
	end)
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Vide.effect(function()
		local current = state()
		local egg = eggColor()
		if current == "Today" then
			outline.Color = Layout.lineColor(TODAY_COLOR)
			outline.Thickness = NEON.LINE_THICKNESS
			outline.Transparency = 0
		elseif egg then
			outline.Color = egg:Lerp(NEON.GLASS, EGG_LINE_DARKEN)
			outline.Thickness = NEON.LINE_THICKNESS
			outline.Transparency = dim()
		else
			outline.Color = NEON.LINE
			outline.Thickness = 1
			outline.Transparency = 1 - (1 - NEON.LINE_TRANSPARENCY) * (1 - dim())
		end
	end)
	return create("Frame")({
		Name = `Day{index}`,
		LayoutOrder = index,
		Size = width,
		BackgroundColor3 = function()
			local egg = eggColor()
			return if state() == "Today" then TODAY_COLOR elseif egg then egg else Color3.new(1, 1, 1)
		end,
		BackgroundTransparency = function()
			return if state() == "Today"
				then TODAY_TRANSPARENCY
				elseif eggColor() and state() ~= "Taken" then EGG_DAY_TRANSPARENCY
				else TILE_TRANSPARENCY
		end,
		Visible = function()
			return entry() ~= nil
		end,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		outline,
		scale,
		Layout.padding(TILE_PADDING, TILE_PADDING),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, TILE_LINE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label(
			"Title",
			function()
				local current = entry()
				return if current then current.title else ""
			end,
			1,
			{
				color = function()
					return if state() == "Today" then NEON.TEXT else NEON.MUTED
				end,
				transparency = dim,
			}
		),
		Symbol(entry, state, dim),
		label(
			"EggName",
			function()
				local current = entry()
				return if current and current.egg then current.egg else ""
			end,
			3,
			{
				size = NEON.TEXT_SMALL,
				color = function()
					local egg = eggColor()
					return if egg then egg:Lerp(Color3.new(1, 1, 1), 0.5) else NEON.TEXT
				end,
				transparency = dim,
				visible = function()
					local current = entry()
					return current ~= nil and current.egg ~= nil
				end,
			}
		),
		Value("Coins", 4, "Coin", NEON.COINS, function()
			local current = entry()
			return if current then current.coins else ""
		end, dim),
		Value("Speed", 5, "Bolt", NEON.SPEED, function()
			local current = entry()
			return if current then current.speed else ""
		end, dim),
	}) :: Frame
end

function LoginGiftWindow.create(props: Props, dayCount: number): Frame
	local tiles = {}
	for index = 1, dayCount do
		table.insert(tiles, DayTile(props, index))
	end

	return NeonWindow({
		name = "LoginGift",
		visible = props.visible,
		title = props.title,
		coins = props.coins,
		onClose = props.onClose,
		body = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, BODY_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel")({
				Name = "Lead",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, LEAD_HEIGHT),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_HINT,
				TextColor3 = NEON.MUTED,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = props.hint,
				Layout.textStroke(),
			}),
			create("Frame")({
				Name = "Days",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 1, -(LEAD_HEIGHT + BODY_GAP)),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, TILE_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				tiles,
			}),
		},
		footer = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ActionButton({
				name = "Claim",
				text = props.claim,
				color = TODAY_COLOR,
				size = "Large",
				layoutOrder = 1,
				visible = props.canClaim,
				onClick = props.onClaim,
			}),
			create("TextLabel")({
				Name = "Miss",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.MUTED,
				Text = props.miss,
				Visible = function()
					return not props.canClaim()
				end,
				Layout.textStroke(),
			}),
		},
	})
end

-- Celebrates a claim on the tile of `day` inside `window`: the tile pops and sparks fly out of
-- it in the tile's colour, drawn in `layer` (a ScreenGui) above everything.
function LoginGiftWindow.burst(window: Instance, layer: ScreenGui, day: number, color: Color3)
	local target = window:FindFirstChild(`Day{day}`, true)
	if not target or not target:IsA("GuiObject") then
		return
	end
	local scale = target:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, POP_TWEEN, { Scale = POP_SCALE }):Play()
	end
	local center = target.AbsolutePosition + target.AbsoluteSize / 2
	local random = Random.new()
	for index = 1, SPARK_COUNT do
		-- A little diamond: a turned square (a glyph would depend on the font having it).
		local spark = Instance.new("Frame")
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.fromOffset(center.X, center.Y)
		spark.Size = UDim2.fromOffset(SPARK_SIZE, SPARK_SIZE)
		spark.Rotation = 45
		spark.BackgroundColor3 = color
		spark.BorderSizePixel = 0
		spark.ZIndex = 20
		spark.Parent = layer
		local angle = (index / SPARK_COUNT + random:NextNumber(-0.03, 0.03)) * math.pi * 2
		local distance = SPARK_DISTANCE * random:NextNumber(0.6, 1)
		local goal = center + Vector2.new(math.cos(angle), math.sin(angle)) * distance
		local flight = TweenInfo.new(SPARK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(spark, flight, {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			BackgroundTransparency = 1,
			Rotation = 45 + random:NextNumber(-90, 90),
		})
		tween:Play()
		tween.Completed:Once(function()
			spark:Destroy()
		end)
	end
end

return table.freeze(LoginGiftWindow)
